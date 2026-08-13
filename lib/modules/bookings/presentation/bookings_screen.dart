import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/amount_text.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../components/summary_banner.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/booking.dart';
import '../../../navigation/routes.dart';
import '../application/booking_controller.dart';

/// The tenant's bookings, past and present.
///
/// Expired and cancelled bookings stay on the list. Section 23 is explicit that
/// an expired booking is not deleted, and a tenant who paid a booking fee has a
/// legitimate interest in still being able to see the booking it was paid
/// against.
class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: switch (bookings) {
        AsyncLoading() when !bookings.hasValue => const AppSkeletonList(
          header: true,
        ),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.read(bookingListProvider.notifier).refresh(),
        ),
        _ => _BookingList(bookings: bookings.requireValue),
      },
    );
  }
}

class _BookingList extends ConsumerWidget {
  const _BookingList({required this.bookings});

  final List<Booking> bookings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bookings.isEmpty) {
      return EmptyState(
        icon: Icons.event_note_outlined,
        title: 'No bookings yet',
        message:
            'Units you book will appear here while you complete the '
            'requirements.',
        action: FilledButton.tonal(
          onPressed: () => context.goNamed(Routes.browse),
          child: const Text('Browse available units'),
        ),
      );
    }

    final openCount = bookings.where((item) => !item.status.isTerminal).length;
    final actionCount = bookings
        .where((item) => item.status.awaitsBookingFee)
        .length;

    return RefreshIndicator(
      onRefresh: () => ref.read(bookingListProvider.notifier).refresh(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            itemCount: bookings.length + 1,
            separatorBuilder: (_, _) => Gap.h12,
            itemBuilder: (context, index) => index == 0
                ? _BookingOverview(
                    total: bookings.length,
                    open: openCount,
                    needsAction: actionCount,
                  )
                : _BookingCard(booking: bookings[index - 1]),
          ),
        ),
      ),
    );
  }
}

class _BookingOverview extends StatelessWidget {
  const _BookingOverview({
    required this.total,
    required this.open,
    required this.needsAction,
  });

  final int total;
  final int open;
  final int needsAction;

  @override
  Widget build(BuildContext context) {
    return SummaryBanner(
      icon: Icons.event_available_outlined,
      headline: 'Booking activity',
      caption: needsAction > 0
          ? '$needsAction ${needsAction == 1 ? 'booking needs' : 'bookings need'} your attention.'
          : 'Everything is up to date.',
      counts: [
        SummaryCount(label: 'Total', value: total),
        SummaryCount(label: 'In progress', value: open),
        SummaryCount(
          label: 'Needs action',
          value: needsAction,
          tone: Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: () => context.pushNamed(
          Routes.bookingStatus,
          pathParameters: {'bookingId': booking.id},
        ),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Gap.md,
                runSpacing: Gap.sm,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.6),
                          borderRadius: AppRadius.small,
                        ),
                        child: Icon(
                          Icons.storefront_outlined,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      Gap.w12,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unit ${booking.unitNumber ?? '—'}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: AppTypography.bold),
                          ),
                          Text(
                            booking.bookingReference,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                  StatusChip(
                    label: booking.status.label,
                    tone: booking.status.tone,
                  ),
                ],
              ),
              Gap.h12,
              Divider(color: scheme.outlineVariant),
              Gap.h12,
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: Gap.md,
                runSpacing: Gap.sm,
                children: [
                  Text(
                    booking.propertyName ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Monthly rent',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      AmountText(booking.monthlyRent, align: TextAlign.end),
                    ],
                  ),
                ],
              ),
              if (booking.status.isCountingDown &&
                  booking.timeRemaining != null) ...[
                Gap.h8,
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: booking.isExpiringSoon
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                    Gap.w4,
                    Text(
                      'Expires in '
                      '${AppDate.humanDuration(booking.timeRemaining!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: booking.isExpiringSoon
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                        fontWeight: AppTypography.semibold,
                      ),
                    ),
                  ],
                ),
              ],
              Gap.h8,
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
