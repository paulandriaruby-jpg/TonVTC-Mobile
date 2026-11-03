import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../push/push_service.dart';
import 'earnings_screen.dart';
import 'profile_screen.dart';
import 'ride_detail_screen.dart';
import 'rides_screen.dart';

// Trois onglets : Courses (propositions, à venir, historique), Gains, Profil. Une notification ouvre la bonne vue.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  final _rides = GlobalKey<RidesScreenState>();
  late final PushService _push;

  @override
  void initState() {
    super.initState();
    _push = context.read<PushService>();
    _push.registerToken();
    _push.opened.addListener(_onNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onNotification());
  }

  @override
  void dispose() {
    _push.opened.removeListener(_onNotification);
    super.dispose();
  }

  void _onNotification() {
    final data = _push.opened.value;
    if (data == null || !mounted) return;
    _push.opened.value = null;
    setState(() => _tab = 0);
    if (data['type'] == 'new_ride') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _rides.currentState?.showProposals());
    } else if (int.tryParse(data['booking_id'] ?? '') case final id?) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Un seul onglet construit à la fois : chacun se recharge quand on y revient (gains à jour après une course).
      body: switch (_tab) {
        1 => const EarningsScreen(),
        2 => const ProfileScreen(),
        _ => RidesScreen(key: _rides),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Gains'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
