import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/money_text.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
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
        AsyncLoading() when !bookings.hasValue => const LoadingView(),
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
        message: 'Units you book will appear here while you complete the '
            'requirements.',
        action: FilledButton.tonal(
          onPressed: () => context.goNamed(Routes.browse),
          child: const Text('Browse available units'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(bookingListProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
        itemCount: bookings.length,
        separatorBuilder: (_, _) => Gap.h12,
        itemBuilder: (context, index) =>
            _BookingCard(booking: bookings[index]),
      ),
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unit ${booking.unitNumber ?? '—'}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          booking.bookingReference,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label: booking.status.label,
                    tone: booking.status.tone,
                  ),
                ],
              ),
              Gap.h12,
              Row(
                children: [
                  Expanded(
                    child: Text(
                      booking.propertyName ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  MoneyText(booking.monthlyRent, bare: true),
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
