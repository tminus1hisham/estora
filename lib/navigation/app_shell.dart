import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'adaptive_app_frame.dart';

/// The five-tab bottom navigation.
///
/// Section 45 lists eight destinations — Home, My Lease, Invoices, Payments,
/// Documents, Property, Notifications, Profile — which is more than a bottom
/// bar can carry legibly. All eight are still reachable; the four that are not
/// tabs live as sub-routes:
///
/// * Notifications — the bell in the home app bar
/// * Property — from the home tenancy card, and the Browse tab
/// * Payments and Documents — from Profile, and from the invoices app bar
/// * My Lease — from Profile, and the home quick actions
///
/// Browse and Bookings are tabs instead, because section 77's Main group
/// (Properties, Available Units, Unit Details, Booking) is the whole
/// pre-tenancy journey and needs a top-level entry point at both ends: a place
/// to find a unit, and a place to watch the hold on it count down. A lease is
/// read once and kept; a booking is checked.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.search_outlined),
      selectedIcon: Icon(Icons.search_rounded),
      label: 'Browse',
    ),
    NavigationDestination(
      icon: Icon(Icons.event_available_outlined),
      selectedIcon: Icon(Icons.event_available_rounded),
      label: 'Bookings',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long_rounded),
      label: 'Invoices',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the tab you are already on pops back to its root, which is what
      // a tab bar is expected to do.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveAppFrame(
      body: navigationShell,
      destinations: _destinations,
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: _onDestinationSelected,
      workspaceLabel: 'Your space',
    );
  }
}
