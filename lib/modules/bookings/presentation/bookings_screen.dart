import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/amount_text.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/countdown_timer.dart';
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
import 'widgets/pay_booking_fee.dart';

/// The Bookings tab: the tenant's bookings, past and present.
///
/// This is the tab a pre-tenancy account lives on. A booking is a hold with a
/// clock on it, and the whole point of the screen is to see where each one
/// stands — how long is left, what still needs doing — without opening it.
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
/// reason this screen gets opened. It ticks rather than being read once: a tab
/// stays mounted while the tenant is elsewhere in the app, and a caption
/// computed on first build would still say "2 hours" long after the hold
/// lapsed.
class _BookingRow extends ConsumerWidget {
  const _BookingRow({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiresAt = booking.expiresAt;
    if (!booking.status.isCountingDown || expiresAt == null) {
      return _row(context, caption: booking.status.label);
    }

    return CountdownTimer(
      expiresAt: expiresAt,
      // The caption is only ever minutes-granular, so a second-by-second
      // rebuild of every row would be work nobody could see.
      tick: const Duration(minutes: 1),
      // Zero here does not expire the booking. A background worker on the
      // server does that (section 23); this refetches so the list shows the
      // server's verdict rather than guessing at it.
      onExpired: () => ref.read(bookingListProvider.notifier).refresh(),
      builder: (context, remaining) {
        final scheme = Theme.of(context).colorScheme;
        final urgent = remaining < const Duration(hours: 6);
        return _row(
          context,
          caption: remaining == Duration.zero
              ? 'Hold ended'
              : 'Expires in ${AppDate.humanDuration(remaining)}',
          captionColor: urgent ? scheme.error : context.statusColors.warning,
        );
      },
    );
  }

  Widget _row(
    BuildContext context, {
    required String caption,
    Color? captionColor,
  }) {
    return Consumer(
      builder: (context, ref, _) => RecordRow(
        icon: Icons.storefront_outlined,
        iconColor: context.statusColors.resolve(booking.status.tone),
        title: 'Unit ${booking.unitNumber ?? '—'}',
        subtitle: [
          booking.bookingReference,
          if (booking.propertyName != null) booking.propertyName!,
        ].join(' · '),
        amount: AmountText(booking.monthlyRent, align: TextAlign.end),
        caption: caption,
        captionColor:
            captionColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
        // A booking waiting on its fee is the one row on this list that
        // wants something done, and the fee is the one figure it wants —
        // so the action sits on the row, with the figure, rather than a tap
        // and a scroll away.
        footnote: booking.canPayFee
            ? _PayFeeAction(booking: booking, ref: ref)
            : null,
        onTap: () => context.pushNamed(
          Routes.bookingStatus,
          pathParameters: {'bookingId': booking.id},
        ),
      ),
    );
  }
}

/// "Pay now" on a booking row, with the fee it asks for.
class _PayFeeAction extends StatelessWidget {
  const _PayFeeAction({required this.booking, required this.ref});

  final Booking booking;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Booking fee ${booking.bookingFee.format()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Gap.w12,
        FilledButton.icon(
          onPressed: () => payBookingFee(context, ref, booking),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
          ),
          icon: const Icon(Icons.phone_android_rounded, size: 18),
          label: const Text('Pay now'),
        ),
      ],
    );
  }
}
