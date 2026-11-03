import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/driver_api.dart';
import '../models/models.dart';
import '../push/push_service.dart';
import '../widgets/common.dart';
import '../widgets/recruitment_card.dart';
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
  // Dossier de recrutement : tant qu'il n'est pas validé, Courses et Gains expliquent pourquoi ils sont fermés.
  DriverProfile? _profile;

  @override
  void initState() {
    super.initState();
    _push = context.read<PushService>();
    _push.registerToken();
    _loadProfile();
    _push.opened.addListener(_onNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onNotification());
  }

  @override
  void dispose() {
    _push.opened.removeListener(_onNotification);
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await context.read<DriverApi>().profile();
      if (mounted) setState(() => _profile = profile);
    } catch (error) {
      if (mounted) handleError(context, error);
    }
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
    final profile = _profile;
    final pending = profile != null && !profile.validated;
    Widget closed(String title) => RecruitmentPending(profile: profile!, title: title, onRefresh: _loadProfile, onOpenProfile: () => setState(() => _tab = 2));
    return Scaffold(
      // Un seul onglet construit à la fois : chacun se recharge quand on y revient (gains à jour après une course).
      body: switch (_tab) {
        1 => pending ? closed('Gains') : const EarningsScreen(),
        2 => const ProfileScreen(),
        _ => pending ? closed('Courses') : RidesScreen(key: _rides),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) {
          setState(() => _tab = index);
          // L'équipe a pu valider le dossier depuis la dernière fois.
          if (pending) _loadProfile();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Gains'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
