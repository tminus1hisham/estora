import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'adaptive_app_frame.dart';

/// The five-tab bottom navigation.
///
/// Section 45 lists eight destinations — Home, My Lease, Invoices, Payments,
/// Documents, Property, Notifications, Profile — which is more than a bottom
/// bar can carry legibly. All eight are still reachable; the ones that are not
/// tabs live elsewhere:
///
/// * Notifications — the bell in the home app bar
/// * Property — from the home tenancy card
/// * Payments — the Transactions pane of the Invoices tab
/// * Documents — from Profile, and the home quick actions
/// * Browse — 'Browse more properties' in Profile, and the home hero
/// * Support — a home quick action, and a Profile row
///
/// The fifth slot holds Utilities rather than Browse. Browsing is a journey a
/// tenant makes once, before there is a tenancy; water and electricity are
/// read every month for as long as the tenancy lasts, which is what a tab is
/// for. Bookings are a profile row for the same reason: a booking is a hold
/// that becomes the lease, and the lease is what the tenant lives with.
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
      icon: Icon(Icons.bolt_outlined),
      selectedIcon: Icon(Icons.bolt_rounded),
      label: 'Utilities',
    ),
    NavigationDestination(
      icon: Icon(Icons.description_outlined),
      selectedIcon: Icon(Icons.description_rounded),
      label: 'Lease',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long_rounded),
      label: 'Billing',
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
