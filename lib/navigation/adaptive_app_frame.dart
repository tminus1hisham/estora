import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                                'Estora',
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
          bottomNavigationBar: _ChromeTabBar(
            destinations: destinations,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
          ),
        );
      },
    );
  }
}

/// The phone tab bar, set the way iOS sets one: an edge-to-edge band of
/// chrome under the page, closed off at the top by a hairline, with the
/// selected tab picked out by its tint and a soft capsule rather than by a
/// heavier glyph and a solid pill.
///
/// It replaces a floating, shadowed pill. The pill made the navigation the
/// most elevated object on every screen, which is backwards: the bar is the
/// frame, and the page is the picture.
///
/// There is no blur behind it, on purpose. The page does not run under the
/// bar — letting it (`extendBody`) would leave the last row of every tab's
/// list, and every screen pushed within a tab, parked under the chrome, since
/// those lists pad for themselves and not for a bar they cannot see. With only
/// the flat page colour behind it, a blur would cost a backdrop read every
/// frame and show nothing. So the bar takes the chrome veil the frosted panes
/// use over their blur — milk on cream, navy smoke on navy — which is what an
/// iOS bar looks like at rest with nothing beneath it.
///
/// Still a [NavigationBar], restyled rather than replaced, so its semantics
/// (a tab bar of tabs, the selected one marked) and its clamped label scaling
/// come with it — and so it follows whichever theme the shell hands it: the
/// tenant's azure, or the owner stage's brass.
class _ChromeTabBar extends StatelessWidget {
  const _ChromeTabBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final still = MediaQuery.disableAnimationsOf(context);

    final veil = dark
        ? AppPalette.navy900.withValues(alpha: 0.62)
        : AppPalette.stone0.withValues(alpha: 0.72);
    final hairline = dark
        ? Colors.white.withValues(alpha: 0.10)
        : AppPalette.navy900.withValues(alpha: 0.12);
    final inactive = scheme.onSurfaceVariant;

    final barTheme = theme.navigationBarTheme.copyWith(
      height: 64,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      // A faint wash rather than a container fill: enough to say which tab
      // is open at a glance, quiet enough that the glyph and its label stay
      // the thing that is lit. In light mode a breath of the tint; in dark
      // mode a neutral smoke, because a 16% wash of azure or brass over navy
      // comes out as mud rather than as colour.
      indicatorColor: dark
          ? Colors.white.withValues(alpha: 0.08)
          : scheme.primary.withValues(alpha: 0.11),
      indicatorShape: const StadiumBorder(),
      // No press wash either; the indicator moving is the answer.
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return theme.textTheme.labelSmall?.copyWith(
          color: selected ? scheme.primary : inactive,
          fontWeight: selected ? AppTypography.semibold : AppTypography.medium,
          letterSpacing: 0.1,
        );
      }),
      // One size for both states. A glyph that swells when chosen is
      // Material's emphasis; iOS changes the colour and the fill and leaves
      // the geometry alone, so the row never shifts.
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? scheme.primary : inactive,
          size: 24,
        );
      }),
    );

    return Theme(
      data: theme.copyWith(
        navigationBarTheme: barTheme,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: veil,
          border: Border(
            // Half a point: one device pixel on a phone, the weight iOS draws
            // the edge of its chrome at.
            top: BorderSide(color: hairline, width: 0.5),
          ),
        ),
        child: DecoratedBox(
          // The same room light the panes catch along their upper edge, kept
          // to the top few points so the bar reads as a surface, not a slab.
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: dark ? 0.04 : 0.28),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [0, 0.35],
            ),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            animationDuration: still
                ? Duration.zero
                : const Duration(milliseconds: 320),
            onDestinationSelected: (index) {
              // A tick only when the tab actually changes. Tapping the open
              // tab pops it to its root, which is a scroll, not a switch.
              if (index != selectedIndex) HapticFeedback.selectionClick();
              onDestinationSelected(index);
            },
            destinations: destinations,
          ),
        ),
      ),
    );
  }
}
