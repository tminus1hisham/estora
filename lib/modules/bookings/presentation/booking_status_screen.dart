import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/amount_text.dart';
import '../../../components/app_stepper.dart';
import '../../../components/countdown_timer.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/booking.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../navigation/routes.dart';
import '../application/booking_controller.dart';

/// Section 77's Booking Status screen.
///
/// Shows where the booking sits in the section 81 state machine, how long the
/// hold has left (section 23), and what is still outstanding.
class BookingStatusScreen extends ConsumerWidget {
  const BookingStatusScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingDetailProvider(bookingId));

    return Scaffold(
      appBar: AppBar(title: Text(booking.value?.bookingReference ?? 'Booking')),
      body: switch (booking) {
        AsyncLoading() when !booking.hasValue => const LoadingView(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(bookingDetailProvider(bookingId)),
        ),
        _ => _Body(booking: booking.requireValue),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(bookingDetailProvider(booking.id)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            children: [
              _NextActionBanner(booking: booking),
              Gap.h12,
              _HeaderCard(booking: booking),
              Gap.h12,
              _ProgressCard(booking: booking),
              Gap.h12,
              _TermsCard(booking: booking),
              if (booking.requirements.isNotEmpty) ...[
                Gap.h12,
                _RequirementsCard(booking: booking),
              ],
              if (!booking.status.isTerminal) ...[
                Gap.h24,
                OutlinedButton.icon(
                  onPressed: () => _confirmCancel(context, ref),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancel this booking'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: const Text(
          'The unit will be released and made available to others. Any booking '
          'fee already paid is handled according to the refund policy — it is '
          'not lost from your record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(bookingActionsProvider)
        .cancelBooking(booking.id);

    if (!context.mounted) return;
    if (result.isErr) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.failureOrNull!.message)));
    }
  }
}

class _NextActionBanner extends StatelessWidget {
  const _NextActionBanner({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, eyebrow, title, message) = switch (booking.status) {
      BookingStatus.pendingPayment || BookingStatus.paymentPending => (
        Icons.payments_outlined,
        'NEXT STEP',
        'Pay the booking fee',
        'Payment activates the hold and starts your completion window.',
      ),
      BookingStatus.active when !booking.allMandatoryRequirementsSatisfied => (
        Icons.fact_check_outlined,
        'ACTION REQUIRED',
        'Complete your requirements',
        '${booking.satisfiedRequirementCount} of ${booking.mandatoryRequirementCount} mandatory items are complete.',
      ),
      BookingStatus.active => (
        Icons.hourglass_top_rounded,
        'IN REVIEW',
        'Your booking is on track',
        'Your completed requirements are being prepared for the lease.',
      ),
      BookingStatus.convertedToLease => (
        Icons.description_outlined,
        'COMPLETE',
        'Your lease is ready',
        'Continue to your lease to review the final agreement.',
      ),
      _ => (
        Icons.event_note_outlined,
        'BOOKING UPDATE',
        booking.status.label,
        'This booking is kept in your history for your records.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: AppRadius.large,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: AppRadius.medium,
            ),
            child: Icon(icon, color: scheme.onPrimary),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: AppTypography.extraBold,
                    letterSpacing: 0.8,
                  ),
                ),
                Gap.h4,
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: AppTypography.bold,
                  ),
                ),
                Gap.h4,
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Status, unit, and the section 23 countdown.
class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final expiresAt = booking.expiresAt;

    return SectionCard(
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Gap.md,
          runSpacing: Gap.sm,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unit ${booking.unitNumber ?? '—'}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                Text(
                  booking.propertyName ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            StatusChip(label: booking.status.label, tone: booking.status.tone),
          ],
        ),
        Gap.h12,
        DetailRow(label: 'Reference', value: booking.bookingReference),
        DetailRow(label: 'Booked', value: AppDate.dateTime(booking.createdAt)),

        if (booking.status.isCountingDown && expiresAt != null) ...[
          Gap.h12,
          CountdownTimer(
            expiresAt: expiresAt,
            // Zero here does not expire the booking. A background worker on the
            // server does that (section 23); this refetches so the screen shows
            // the server's verdict rather than guessing at it.
            onExpired: () => ref.invalidate(bookingDetailProvider(booking.id)),
            builder: (context, remaining) {
              final expired = remaining == Duration.zero;
              final urgent = remaining < const Duration(hours: 6);
              final color = context.statusColors.resolve(
                expired
                    ? StatusTone.neutral
                    : urgent
                    ? StatusTone.danger
                    : StatusTone.progress,
              );

              return Container(
                padding: const EdgeInsets.all(Gap.md),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.small,
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: color, size: 20),
                    Gap.w12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expired
                                ? 'This hold has lapsed'
                                : 'Hold expires in',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            expired
                                ? 'Checking with the server…'
                                : AppDate.countdown(remaining),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: AppTypography.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: color,
                            ),
                          ),
                          if (!expired)
                            Text(
                              'Until ${AppDate.dateTime(expiresAt)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Section 81's booking state machine, as a stepper.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final steps = <AppStep>[
      AppStep(
        label: 'Booking created',
        done: true,
        detail: AppDate.short(booking.createdAt),
      ),
      AppStep(
        label: 'Booking fee paid',
        done: !booking.status.awaitsBookingFee,
        detail: booking.status.awaitsBookingFee ? 'Outstanding' : null,
      ),
      AppStep(
        label: 'Requirements submitted',
        done: booking.allMandatoryRequirementsSatisfied,
        detail:
            '${booking.satisfiedRequirementCount} of '
            '${booking.mandatoryRequirementCount} done',
      ),
      AppStep(
        label: 'Lease generated',
        done: booking.leaseId != null,
        detail: booking.leaseId == null ? 'Once requirements are met' : null,
      ),
    ];

    return SectionCard(
      title: 'Progress',
      children: [
        AppStepper.vertical(steps: steps),
        if (booking.leaseId != null) ...[
          Gap.h12,
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.pushNamed(
                Routes.leaseDetail,
                pathParameters: {'leaseId': booking.leaseId!},
              ),
              icon: const Icon(Icons.description_outlined),
              label: const Text('View your lease'),
            ),
          ),
        ],
        if (booking.status.awaitsBookingFee &&
            booking.bookingFeeInvoiceId != null) ...[
          Gap.h12,
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.pushNamed(
                Routes.payment,
                pathParameters: {'invoiceId': booking.bookingFeeInvoiceId!},
              ),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Pay the booking fee'),
            ),
          ),
        ],
        if (booking.status == BookingStatus.active &&
            booking.depositInvoiceId != null) ...[
          Gap.h12,
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => context.pushNamed(
                Routes.payment,
                pathParameters: {'invoiceId': booking.depositInvoiceId!},
              ),
              icon: const Icon(Icons.savings_outlined),
              label: const Text('Pay the deposit'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Section 21's captured terms.
class _TermsCard extends StatelessWidget {
  const _TermsCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Your agreed terms',
      children: [
        DetailRow(
          label: 'Monthly rent',
          valueWidget: AmountText(booking.monthlyRent, align: TextAlign.end),
        ),
        DetailRow(
          label: 'Security deposit',
          valueWidget: AmountText(booking.depositAmount, align: TextAlign.end),
        ),
        DetailRow(
          label: 'Booking fee',
          valueWidget: AmountText(booking.bookingFee, align: TextAlign.end),
        ),
        Gap.h8,
        Text(
          // Section 21. These are the figures captured when the booking was
          // made; nothing here is recalculated from the unit's current price.
          'These figures were fixed when you booked and will not change if the '
          'listed price does.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Section 18's requirements, with upload.
class _RequirementsCard extends ConsumerStatefulWidget {
  const _RequirementsCard({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_RequirementsCard> createState() => _RequirementsCardState();
}

class _RequirementsCardState extends ConsumerState<_RequirementsCard> {
  String? _uploadingId;

  Future<void> _submit(BookingRequirement requirement) async {
    setState(() => _uploadingId = requirement.id);

    // A real build would open the platform file picker here. The mock records
    // the metadata, which is all the requirement check needs, so the flow can
    // be walked end to end without a picker dependency.
    final fileName =
        '${requirement.documentType?.api.toLowerCase() ?? 'document'}.pdf';
    final bytes = Uint8List.fromList(
      List<int>.filled(180 * 1024, 0, growable: false),
    );

    final result = await ref
        .read(bookingActionsProvider)
        .submitRequirement(
          bookingId: widget.booking.id,
          requirementId: requirement.id,
          fileName: fileName,
          bytes: bytes,
          mimeType: 'application/pdf',
        );

    if (!mounted) return;
    setState(() => _uploadingId = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isOk
              ? '${requirement.name} submitted'
              : result.failureOrNull!.message,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final booking = widget.booking;

    return SectionCard(
      title: 'Requirements',
      trailing: Text(
        '${booking.satisfiedRequirementCount}/${booking.requirements.length}',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      children: [
        for (final requirement in booking.requirements)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      requirement.isSatisfied
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: requirement.isSatisfied
                          ? context.statusColors.positive
                          : scheme.outline,
                    ),
                    Gap.w12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            requirement.isMandatory
                                ? requirement.name
                                : '${requirement.name} (optional)',
                            style: const TextStyle(
                              fontWeight: AppTypography.semibold,
                            ),
                          ),
                          if (requirement.description != null)
                            Text(
                              requirement.description!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          if (requirement.isSatisfied &&
                              requirement.satisfiedAt != null)
                            Text(
                              'Submitted ${AppDate.short(requirement.satisfiedAt!)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: context.statusColors.positive,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!requirement.isSatisfied &&
                    requirement.requirementType ==
                        RequirementType.document) ...[
                  Gap.h8,
                  Align(
                    alignment: Alignment.centerRight,
                    child: _uploadingId == requirement.id
                        ? const Padding(
                            padding: EdgeInsets.all(Gap.sm),
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : TextButton.icon(
                            onPressed: () => _submit(requirement),
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('Upload'),
                          ),
                  ),
                ],
                // Payment requirements are met by paying the deposit invoice,
                // not by uploading anything.
                if (!requirement.isSatisfied &&
                    requirement.requirementType == RequirementType.payment &&
                    booking.depositInvoiceId != null) ...[
                  Gap.h8,
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => context.pushNamed(
                        Routes.payment,
                        pathParameters: {
                          'invoiceId': booking.depositInvoiceId!,
                        },
                      ),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Pay'),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
