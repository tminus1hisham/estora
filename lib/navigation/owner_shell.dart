import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/ambient_glow.dart';
import '../core/theme/app_theme.dart';

/// The owner tier's four-tab shell.
///
/// Structurally the same as [AppShell] — an indexed stack under a bottom bar —
/// and deliberately so: an owner who has used the tenant app should not have to
/// learn a second way to move around.
///
/// Follows the app's appearance choice, using [AppTheme.ownerStage] for the
/// manager's navy and brass palette when the resolved theme is dark.
class ManagerShell extends StatelessWidget {
  const ManagerShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// Visible destinations map to router branches through [_branchIndices].
  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.donut_small_outlined),
      selectedIcon: Icon(Icons.donut_small_rounded),
      label: 'Manager',
    ),
    NavigationDestination(
      icon: Icon(Icons.apartment_outlined),
      selectedIcon: Icon(Icons.apartment_rounded),
      label: 'Properties',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_outlined),
      selectedIcon: Icon(Icons.account_balance_rounded),
      label: 'Money',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Account',
    ),
  ];

  // Keep the hidden Tenancies branch available for existing detail links.
  static const _branchIndices = [0, 1, 3, 4];

  void _onDestinationSelected(int index) {
    final branch = _branchIndices[index];
    navigationShell.goBranch(
      branch,
      initialLocation: branch == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inheritedTheme = Theme.of(context);
    final theme = inheritedTheme.brightness == Brightness.dark
        ? AppTheme.ownerStage
        : inheritedTheme;
    final scheme = theme.colorScheme;

    return Theme(
      data: theme,
      child: Scaffold(
        body: Stack(
          children: [
            // The stage's one light source. It sits behind everything, which is
            // what makes a GlassSurface on an owner screen honest — there is
            // genuinely something passing behind the pane.
            Positioned(
              top: -140,
              right: -120,
              child: AmbientGlow(
                color: AppPalette.brass500.withValues(alpha: 0.16),
                size: 420,
              ),
            ),
            Positioned(
              bottom: -180,
              left: -140,
              child: AmbientGlow(
                color: AppPalette.azure700.withValues(alpha: 0.18),
                size: 460,
              ),
            ),
            navigationShell,
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _branchIndices.contains(navigationShell.currentIndex)
                ? _branchIndices.indexOf(navigationShell.currentIndex)
                : 1,
            onDestinationSelected: _onDestinationSelected,
            destinations: _destinations,
          ),
        ),
      ),
    );
  }
}

/// Compatibility name for existing route consumers.
typedef OwnerShell = ManagerShell;
