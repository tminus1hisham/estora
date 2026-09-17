import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/dashboard_summary.dart';
import '../../../../navigation/routes.dart';

/// The four places a tenant goes next.
///
/// Deliberately not a card. The screen runs heavy — a photographic header and
/// a dark balance card — and a row of open tiles between that and the cards
/// below is what stops the page reading as one unbroken stack of panels.
///
/// Section 45 puts eight destinations in the app and the bottom bar carries
/// five; these are the shortcuts to the three that are otherwise a tab and a
/// tap away, plus the one the tenant is most likely to want.
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
              label: 'Payments',
              route: Routes.paymentHistory,
            ),
            _Action(
              icon: Icons.folder_copy_rounded,
              label: 'Documents',
              route: Routes.documents,
            ),
            _Action(
              icon: Icons.description_rounded,
              label: 'My lease',
              route: Routes.leases,
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
              tab: true,
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, action) in actions.indexed)
          Expanded(
            child: _ActionTile(
              action: action,
              index: index,
              reduceMotion: reduceMotion,
            ),
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
    this.tab = false,
  });

  final IconData icon;
  final String label;
  final String route;

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

    final Widget tile = InkWell(
      onTap: () => action.tab
          ? context.goNamed(action.route)
          : context.pushNamed(action.route),
      borderRadius: AppRadius.medium,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
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
              child: Icon(action.icon, size: 22, color: scheme.primary),
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
