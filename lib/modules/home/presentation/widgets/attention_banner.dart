import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/app_pressable.dart';
import '../../../../components/app_surface_card.dart';
import '../../../../components/countdown_timer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/dashboard_summary.dart';
import '../../../../navigation/routes.dart';
import '../../application/dashboard_controller.dart';
import 'home_atoms.dart';

/// Something that needs doing, said plainly and in its own colour.
///
/// These sit directly under the balance card, above everything informational.
/// An unsigned lease or an overdue balance is not a section of a dashboard —
/// it is the reason the screen exists that day.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = context.statusColors.resolve(tone);

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        // A wash rather than a flat tint, so the banner sits in the same
        // lighting as the card above it.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.06),
          ],
        ),
        // Matches AppSurfaceCard's radius: these stack directly against the
        // cards below and a second radius in the same column shows.
        borderRadius: AppRadius.large,
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ToneIconTile(icon: icon, color: color),
              Gap.w12,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xs),
                  child: Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: AppTypography.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Gap.h12,
          Text(message, style: theme.textTheme.bodyMedium),
          Gap.h16,
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              minimumSize: const Size.fromHeight(AppLayout.controlHeight),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

/// Section 23's countdown, surfaced here so a hold cannot lapse unnoticed.
class BookingCountdownCard extends ConsumerWidget {
  const BookingCountdownCard({required this.summary, super.key});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final expiresAt = summary.activeBookingExpiresAt;
    final tone = context.statusColors.resolve(StatusTone.progress);

    return AppPressable(
      child: AppSurfaceCard(
        onTap: () => context.pushNamed(
          Routes.bookingStatus,
          pathParameters: {'bookingId': summary.activeBookingId!},
        ),
        child: Row(
          children: [
            ToneIconTile(icon: Icons.timer_outlined, color: tone),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booking ${summary.activeBookingReference ?? ''}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                  if (expiresAt != null)
                    CountdownTimer(
                      expiresAt: expiresAt,
                      // Reaching zero here does not expire anything — the
                      // server decides that (section 23). This just refetches
                      // so the screen shows whatever it decided.
                      onExpired: () => ref
                          .read(dashboardControllerProvider.notifier)
                          .refresh(),
                      builder: (context, remaining) => Text(
                        remaining == Duration.zero
                            ? 'This hold has lapsed'
                            : 'Expires in ${AppDate.humanDuration(remaining)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Text(
                      'Complete your booking to hold this unit',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
