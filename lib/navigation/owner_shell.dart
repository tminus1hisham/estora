import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/ambient_glow.dart';
import '../core/theme/app_theme.dart';

/// The owner tier's five-tab shell.
///
/// Structurally the same as [AppShell] — an indexed stack under a bottom bar —
/// and deliberately so: an owner who has used the tenant app should not have to
/// learn a second way to move around.
///
/// What differs is the ground. The whole subtree is wrapped in
/// [AppTheme.ownerStage], which is the reason this file is short. Every shared
/// component reads its colours from the scheme, so `RecordGroup`, `RecordRow`,
/// `AppSurfaceCard`, `StatusChip`, the skeletons and the state views all arrive
/// on navy correct, with no `onDark` flag threaded through any of them. Getting
/// this wrong — a bespoke dark variant per component — was the alternative, and
/// it would have meant maintaining two of everything forever.
class OwnerShell extends StatelessWidget {
  const OwnerShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// Positional, and coupled to the branch order in `app_router.dart`. There is
  /// no key linking the two — adding a destination means adding a branch at the
  /// same index.
  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.donut_small_outlined),
      selectedIcon: Icon(Icons.donut_small_rounded),
      label: 'Portfolio',
    ),
    NavigationDestination(
      icon: Icon(Icons.apartment_outlined),
      selectedIcon: Icon(Icons.apartment_rounded),
      label: 'Properties',
    ),
    NavigationDestination(
      icon: Icon(Icons.handshake_outlined),
      selectedIcon: Icon(Icons.handshake_rounded),
      label: 'Tenancies',
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

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.ownerStage;
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
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onDestinationSelected,
            destinations: _destinations,
          ),
        ),
      ),
    );
  }
}
