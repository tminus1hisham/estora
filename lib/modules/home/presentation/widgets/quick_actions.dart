import '../../../../components/glass_well.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/glass_material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/dashboard_summary.dart';
import '../../../../navigation/routes.dart';

/// The home shortcuts, as one frosted platter of four.
///
/// Four separate cards read as four more things to look at; one pane holding
/// four glyphs reads as a single control, which is what iOS does with the same
/// problem in Control Center. Each glyph sits in its own squircle well, washed
/// in a quiet hue of its own so the row can be read by colour before it is
/// read by label — muted on purpose, so the balance card above stays the only
/// loud thing on the screen.
class QuickActions extends StatelessWidget {
  const QuickActions({required this.summary, super.key});

  final DashboardSummary summary;

  /// The narrowest a shortcut can be at the platform's default text size
  /// before its label starts to crowd its neighbours.
  static const double _minTileWidth = 74;

  @override
  Widget build(BuildContext context) {
    final actions = summary.hasTenancy
        ? const [
            _Action(
              icon: Icons.receipt_long_rounded,
              label: 'Invoices',
              hue: _Hue.azure,
              route: Routes.invoices,
              tab: true,
            ),
            _Action(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Transactions',
              hue: _Hue.green,
              route: Routes.invoices,
              query: {Routes.invoicesTabQuery: Routes.invoicesTransactionsTab},
              tab: true,
            ),
            _Action(
              icon: Icons.folder_copy_rounded,
              label: 'Documents',
              hue: _Hue.brass,
              route: Routes.documents,
            ),
            // Support rather than the lease: the lease already has a tab a
            // tap away, and a tenant on the home screen looking for a
            // shortcut is usually looking for something that has gone wrong.
            _Action(
              icon: Icons.support_agent_rounded,
              label: 'Support',
              hue: _Hue.violet,
              route: Routes.support,
            ),
          ]
        : const [
            _Action(
              icon: Icons.support_agent_rounded,
              label: 'Support',
              hue: _Hue.violet,
              route: Routes.support,
            ),
            _Action(
              icon: Icons.event_available_rounded,
              label: 'Bookings',
              hue: _Hue.azure,
              route: Routes.bookings,
            ),
            _Action(
              icon: Icons.folder_copy_rounded,
              label: 'Documents',
              hue: _Hue.brass,
              route: Routes.documents,
            ),
            _Action(
              icon: Icons.person_rounded,
              label: 'Profile',
              hue: _Hue.green,
              route: Routes.profile,
              tab: true,
            ),
          ];

    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Gap.xs, bottom: Gap.sm),
          child: Text(
            'SHORTCUTS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ),
        FrostedPane(
          radius: GlassRadius.platter,
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.sm,
            vertical: Gap.md,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Four across while four fit; two by two once the text has grown
              // enough that four would clip their labels. Never three — a row
              // of three and an orphan reads as a mistake.
              final perRow =
                  constraints.maxWidth / 4 >=
                      _minTileWidth * textScale.clamp(1.0, 2.0)
                  ? 4
                  : 2;
              final tiles = [
                for (final (index, action) in actions.indexed)
                  _ActionTile(
                    action: action,
                    index: index,
                    reduceMotion: reduceMotion,
                  ),
              ];

              return Column(
                children: [
                  for (var start = 0; start < tiles.length; start += perRow)
                    Padding(
                      padding: EdgeInsets.only(top: start == 0 ? 0 : Gap.lg),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final tile in tiles.skip(start).take(perRow))
                            Expanded(child: tile),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The hue a shortcut's well is washed in: the glyph colour in each theme.
enum _Hue {
  azure(AppPalette.azure600, AppPalette.azure300),
  green(AppPalette.green700, AppPalette.green300),
  brass(AppPalette.brass700, AppPalette.brass200),
  violet(AppPalette.violet700, AppPalette.violet300);

  const _Hue(this.light, this.dark);

  final Color light;
  final Color dark;
}

@immutable
class _Action {
  const _Action({
    required this.icon,
    required this.label,
    required this.hue,
    required this.route,
    this.query = const {},
    this.tab = false,
  });

  final IconData icon;
  final String label;
  final _Hue hue;
  final String route;

  /// Query parameters the route takes, such as the pane a tab opens on.
  final Map<String, String> query;

  /// Set for the shell's own tabs, which are switched to rather than pushed.
  /// Everything else — Support, Documents, Bookings — is pushed over the
  /// shell, so the tab the tenant was on is still there behind it.
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

    final Widget tile = GlassTap(
      semanticLabel: action.label,
      onTap: () => action.tab
          ? context.goNamed(action.route, queryParameters: action.query)
          : context.pushNamed(action.route, queryParameters: action.query),
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppLayout.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassWell(
                  icon: action.icon,
                  color: theme.brightness == Brightness.dark
                      ? action.hue.dark
                      : action.hue.light,
                  size: 52,
                ),
                Gap.h8,
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: AppTypography.semibold,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (reduceMotion) return tile;

    // One behind the other after the balance card lands. A short rise rather
    // than a pop: the platter is already there, only its contents arrive.
    return tile
        .animate(delay: Duration(milliseconds: 380 + 60 * index))
        .fadeIn(duration: AppMotion.standard, curve: AppMotion.enter)
        .moveY(
          begin: 8,
          end: 0,
          duration: AppMotion.slow,
          curve: AppMotion.enter,
        );
  }
}
