import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/amount_text.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/record_group.dart';
import '../../../components/state_views.dart';
import '../../../components/summary_banner.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
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
        onRefresh: () async {
          await ref.read(bookingListProvider.notifier).refresh();
        },
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

    // Live bookings first and named as such. An expired booking is kept for the
    // record, but it is not what someone opening this screen came to see.
    final live = bookings.where((item) => !item.status.isTerminal).toList();
    final past = bookings.where((item) => item.status.isTerminal).toList();

    return AppRefreshIndicator(
      onRefresh: () => ref.read(bookingListProvider.notifier).refresh(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            children: [
              _BookingOverview(
                total: bookings.length,
                open: openCount,
                needsAction: actionCount,
              ),
              if (live.isNotEmpty) ...[
                Gap.h24,
                RecordGroup(
                  heading: 'In progress',
                  children: [
                    for (final booking in live) _BookingRow(booking: booking),
                  ],
                ),
              ],
              if (past.isNotEmpty) ...[
                Gap.h24,
                RecordGroup(
                  heading: 'Closed',
                  children: [
                    for (final booking in past) _BookingRow(booking: booking),
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

/// One booking, as a line of the list.
///
/// The countdown is the one thing here that changes on its own, so it takes the
/// caption slot where the eye already goes for status — an expiring hold is the
/// reason this screen gets opened.
class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final counting =
        booking.status.isCountingDown && booking.timeRemaining != null;

    return RecordRow(
      icon: Icons.storefront_outlined,
      iconColor: context.statusColors.resolve(booking.status.tone),
      title: 'Unit ${booking.unitNumber ?? '—'}',
      subtitle: [
        booking.bookingReference,
        if (booking.propertyName != null) booking.propertyName!,
      ].join(' · '),
      amount: AmountText(booking.monthlyRent, align: TextAlign.end),
      caption: counting
          ? 'Expires in ${AppDate.humanDuration(booking.timeRemaining!)}'
          : booking.status.label,
      captionColor: counting && booking.isExpiringSoon
          ? scheme.error
          : counting
          ? context.statusColors.warning
          : scheme.onSurfaceVariant,
      onTap: () => context.pushNamed(
        Routes.bookingStatus,
        pathParameters: {'bookingId': booking.id},
      ),
    );
  }
}
