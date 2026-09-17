import 'package:flutter/material.dart';

import '../components/app_brand_mark.dart';
import '../core/theme/app_theme.dart';

/// Shared navigation chrome for tenant and manager workspaces.
class AdaptiveAppFrame extends StatelessWidget {
  const AdaptiveAppFrame({
    required this.body,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.workspaceLabel,
    super.key,
  });

  final Widget body;
  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final String workspaceLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 1100 &&
            constraints.maxHeight >= 600 &&
            MediaQuery.textScalerOf(context).scale(14) < 22;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                Container(
                  width: 240,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    border: Border(
                      right: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 32, 24, 32),
                          child: Row(
                            children: [
                              const AppBrandMark(size: 40),
                              Gap.w12,
                              Text(
                                'Mall',
                                style: theme.textTheme.headlineSmall,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 0, 24, 20),
                          child: Text(
                            workspaceLabel.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ),
                        Expanded(
                          child: NavigationRail(
                            extended: true,
                            minExtendedWidth: 239,
                            backgroundColor: Colors.transparent,
                            selectedIndex: selectedIndex,
                            onDestinationSelected: onDestinationSelected,
                            indicatorColor: scheme.primaryContainer,
                            selectedLabelTextStyle: theme.textTheme.labelLarge
                                ?.copyWith(color: scheme.primary),
                            unselectedLabelTextStyle: theme.textTheme.labelLarge
                                ?.copyWith(color: scheme.onSurfaceVariant),
                            destinations: [
                              for (final destination in destinations)
                                NavigationRailDestination(
                                  icon: destination.icon,
                                  selectedIcon: destination.selectedIcon,
                                  label: Text(destination.label),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadius.extraLarge,
                boxShadow: AppElevation.lifted(
                  scheme.shadow,
                  level: 2,
                  brightness: theme.brightness,
                ),
              ),
              child: ClipRRect(
                borderRadius: AppRadius.extraLarge,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.extraLarge,
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: NavigationBar(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    destinations: destinations,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
