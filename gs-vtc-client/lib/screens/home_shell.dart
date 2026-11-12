import 'package:flutter/material.dart';

import 'account_screen.dart';
import 'booking_screen.dart';
import 'rides_screen.dart';

// Trois onglets : Réserver, Mes courses, Compte. Chaque onglet se recharge quand on y revient.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_tab) {
        1 => RidesScreen(onBook: () => setState(() => _tab = 0)),
        2 => const AccountScreen(),
        _ => BookingScreen(onShowRides: () => setState(() => _tab = 1)),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_road), label: 'Réserver'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Mes courses'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Compte'),
        ],
      ),
    );
  }
}
