import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/countdown_timer.dart';
import '../../../../components/glass_material.dart';
import '../../../../components/glass_well.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/dashboard_summary.dart';
import '../../../../navigation/routes.dart';
import '../../application/dashboard_controller.dart';
import 'home_atoms.dart';

/// Something that needs doing, said plainly and lit by its own colour.
///
/// These sit directly under the balance card, above everything informational.
/// An unsigned lease or a lease about to end is not a section of a dashboard —
/// it is the reason the screen exists that day.
///
/// It used to say so with a coloured slab: a tinted fill, a tinted border and
/// a title in the status colour, which on a page of glass read as a warning
/// label stuck to the window. Now it is the same pane as everything around it,
/// washed faintly from the corner where its glyph sits. The meaning comes from
/// the glyph and the light; the words stay in the page's own ink, so a banner
/// is urgent without being loud.
class AttentionBanner extends StatelessWidget {
  const AttentionBanner({
    required this.icon,
    required this.tone,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final IconData icon;
  final StatusTone tone;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  /// The glyph well's size, and so how far the text column is indented.
  static const double _well = 44;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = context.statusColors.resolve(tone);
    final stacked = homePrefersStacked(context);

    // Lit only when the banner asks the tenant to do something now — sign,
    // settle. A warning is a heads-up with somewhere to read more, and two
    // lit capsules stacked on one screen is the shouting the glass is meant
    // to have retired.
    final action = GlassCapsuleButton(
      label: actionLabel,
      onPressed: onAction,
      prominent: tone != StatusTone.warning,
      expand: stacked,
    );

    return FrostedPane(
      tone: color,
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassWell(icon: icon, color: color, size: _well),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nudged down so a one-line title sits on the well's
                    // optical centre rather than its top edge.
                    Gap.h4,
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: AppTypography.semibold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Gap.h4,
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap.h16,
          // Under the words it acts on, not under the glyph: the indent is
          // what ties the capsule to this message. Once the text has grown
          // enough to stack the screen, the capsule takes the full width
          // instead, because an indented capsule at that size truncates.
          if (stacked)
            action
          else
            Padding(
              padding: const EdgeInsetsDirectional.only(start: _well + Gap.md),
              child: action,
            ),
        ],
      ),
    );
  }
}

/// Section 23's countdown, surfaced here so a hold cannot lapse unnoticed.
///
/// One row of glass that opens the booking: its glyph, whose booking it is,
/// how long the hold has left, and the chevron that says there is more.
class BookingCountdownCard extends ConsumerWidget {
  const BookingCountdownCard({required this.summary, super.key});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final expiresAt = summary.activeBookingExpiresAt;
    final tone = context.statusColors.resolve(StatusTone.progress);
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    // Merged so a screen reader hears the booking and the time left as one
    // button, the way it reads the row.
    return MergeSemantics(
      child: GlassTap(
        scale: 0.98,
        onTap: () => context.pushNamed(
          Routes.bookingStatus,
          pathParameters: {'bookingId': summary.activeBookingId!},
        ),
        child: FrostedPane(
          tone: tone,
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.md, Gap.md),
          child: Row(
            children: [
              GlassWell(icon: Icons.timer_rounded, color: tone, size: 40),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking ${summary.activeBookingReference ?? ''}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: AppTypography.semibold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (expiresAt != null)
                      CountdownTimer(
                        expiresAt: expiresAt,
                        // Reaching zero here does not expire anything — the
                        // server decides that (section 23). This just
                        // refetches so the screen shows whatever it decided.
                        onExpired: () => ref
                            .read(dashboardControllerProvider.notifier)
                            .refresh(),
                        builder: (context, remaining) => Text(
                          remaining == Duration.zero
                              ? 'This hold has lapsed'
                              : 'Expires in ${AppDate.humanDuration(remaining)}',
                          // Tabular, so the seconds ticking over do not make
                          // the line shuffle sideways.
                          style: caption?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      )
                    else
                      Text(
                        'Complete your booking to hold this unit',
                        style: caption,
                      ),
                  ],
                ),
              ),
              Gap.w8,
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
