import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/even_grid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/dashboard_summary.dart';
import '../../../../navigation/routes.dart';

/// Responsive shortcuts with staggered entrances and generous touch targets.
class QuickActions extends StatelessWidget {
  const QuickActions({required this.summary, super.key});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final actions = summary.hasTenancy
        ? const [
            _Action(
              icon: Icons.receipt_long_rounded,
              label: 'Invoices',
              route: Routes.invoices,
              tab: true,
            ),
            _Action(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Transactions',
              route: Routes.invoices,
              query: {Routes.invoicesTabQuery: Routes.invoicesTransactionsTab},
              tab: true,
            ),
            _Action(
              icon: Icons.folder_copy_rounded,
              label: 'Documents',
              route: Routes.documents,
            ),
            _Action(
              icon: Icons.description_rounded,
              label: 'My lease',
              route: Routes.lease,
              tab: true,
            ),
          ]
        : const [
            _Action(
              icon: Icons.search_rounded,
              label: 'Browse',
              route: Routes.browse,
              tab: true,
            ),
            _Action(
              icon: Icons.event_available_rounded,
              label: 'Bookings',
              route: Routes.bookings,
            ),
            _Action(
              icon: Icons.folder_copy_rounded,
              label: 'Documents',
              route: Routes.documents,
            ),
            _Action(
              icon: Icons.person_rounded,
              label: 'Profile',
              route: Routes.profile,
              tab: true,
            ),
          ];

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A few useful shortcuts',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Gap.h12,
        // Two up on a phone, four on anything wider, and two again once the
        // platform's text has grown enough that four would start clipping the
        // labels. Every tile in a row is the same size either way.
        EvenGrid(
          minTileWidth: 148,
          children: [
            for (final (index, action) in actions.indexed)
              _ActionTile(
                action: action,
                index: index,
                reduceMotion: reduceMotion,
              ),
          ],
        ),
      ],
    );
  }
}

@immutable
class _Action {
  const _Action({
    required this.icon,
    required this.label,
    required this.route,
    this.query = const {},
    this.tab = false,
  });

  final IconData icon;
  final String label;
  final String route;

  /// Query parameters the route takes, such as the pane a tab opens on.
  final Map<String, String> query;

  /// Set for the shell's own tabs, which are switched to rather than pushed.
  final bool tab;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.action,
    required this.index,
    required this.reduceMotion,
  });

  final _Action action;
  final int index;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final Widget tile = Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => action.tab
            ? context.goNamed(action.route, queryParameters: action.query)
            : context.pushNamed(action.route, queryParameters: action.query),
        borderRadius: AppRadius.medium,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Gap.md,
            horizontal: Gap.sm,
          ),
          child: Column(
            // The grid gives every tile in a row the height of the tallest, so
            // a one-line label centres against a neighbour that wrapped.
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.surfaceContainerLowest,
                      scheme.primaryContainer.withValues(alpha: 0.45),
                    ],
                  ),
                  borderRadius: AppRadius.medium,
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  boxShadow: AppElevation.lifted(
                    scheme.shadow,
                    brightness: theme.brightness,
                  ),
                ),
                child: Icon(action.icon, size: 20, color: scheme.primary),
              ),
              Gap.h8,
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: AppTypography.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (reduceMotion) return tile;

    // These arrive after the balance card, one behind the other, with a touch
    // of overshoot so the row lands rather than fades.
    return tile
        .animate(delay: Duration(milliseconds: 380 + 55 * index))
        .fadeIn(duration: AppMotion.standard, curve: AppMotion.enter)
        .scaleXY(
          begin: 0.82,
          end: 1,
          duration: AppMotion.slow,
          curve: Curves.easeOutBack,
        );
  }
}
