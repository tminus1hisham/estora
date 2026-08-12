import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// The header that opens a list screen: an icon, a headline reading of where
/// the tenant stands, and a row of counts.
///
/// Invoices, payments, bookings, leases and booking status each had their own
/// copy of this, identical down to the container radius. They are one thing,
/// so they are one widget.
class SummaryBanner extends StatelessWidget {
  const SummaryBanner({
    required this.icon,
    required this.headline,
    this.caption,
    this.counts = const <SummaryCount>[],
    this.tone,
    super.key,
  });

  final IconData icon;

  /// The single sentence that answers "how am I doing?" — "You are all paid
  /// up", "2 overdue invoices". Written by the caller, which is the only
  /// place that knows the domain.
  final String headline;

  final String? caption;
  final List<SummaryCount> counts;

  /// Colours the banner when the headline is not neutral news. Defaults to the
  /// primary container.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final accent = tone ?? scheme.primary;
    final onAccent = tone == null ? scheme.onPrimaryContainer : scheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: AppRadius.large,
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: AppRadius.medium,
                  boxShadow: AppElevation.lifted(
                    accent,
                    brightness: Theme.of(context).brightness,
                  ),
                ),
                child: Icon(icon, color: scheme.onPrimary, size: 22),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: textTheme.titleMedium?.copyWith(
                        color: onAccent,
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                    if (caption != null)
                      Text(
                        caption!,
                        style: textTheme.bodySmall?.copyWith(
                          color: onAccent.withValues(alpha: 0.78),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (counts.isNotEmpty) ...[
            Gap.h16,
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final count in counts) _CountPill(count: count),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One figure in a [SummaryBanner]'s count row.
class SummaryCount {
  const SummaryCount({required this.label, required this.value, this.tone});

  final String label;
  final int value;

  /// Draws attention to a count that needs it — overdue, expiring.
  final Color? tone;
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final SummaryCount count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tone = count.value > 0 ? count.tone : null;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.82),
        borderRadius: AppRadius.small,
        border: Border.all(
          color: tone?.withValues(alpha: 0.4) ?? Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${count.value}',
            style: textTheme.labelLarge?.copyWith(
              color: tone ?? scheme.onSurface,
              fontWeight: AppTypography.extraBold,
            ),
          ),
          Gap.w8,
          Text(
            count.label,
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
