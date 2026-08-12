import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/countdown_timer.dart';
import '../../../components/money_text.dart';
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
      appBar: AppBar(
        title: Text(booking.value?.bookingReference ?? 'Booking'),
      ),
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
      onRefresh: () async =>
          ref.invalidate(bookingDetailProvider(booking.id)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
        children: [
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failureOrNull!.message)),
      );
    }
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
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unit ${booking.unitNumber ?? '—'}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
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
            ),
            StatusChip(
              label: booking.status.label,
              tone: booking.status.tone,
            ),
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
                  borderRadius: BorderRadius.circular(12),
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
                              fontWeight: FontWeight.w700,
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
    final steps = <(String, bool, String?)>[
      (
        'Booking created',
        true,
        AppDate.short(booking.createdAt),
      ),
      (
        'Booking fee paid',
        !booking.status.awaitsBookingFee,
        booking.status.awaitsBookingFee ? 'Outstanding' : null,
      ),
      (
        'Requirements submitted',
        booking.allMandatoryRequirementsSatisfied,
        '${booking.satisfiedRequirementCount} of '
            '${booking.mandatoryRequirementCount} done',
      ),
      (
        'Lease generated',
        booking.leaseId != null,
        booking.leaseId == null ? 'Once requirements are met' : null,
      ),
    ];

    return SectionCard(
      title: 'Progress',
      children: [
        for (var i = 0; i < steps.length; i++)
          _Step(
            label: steps[i].$1,
            done: steps[i].$2,
            detail: steps[i].$3,
            isLast: i == steps.length - 1,
          ),
        if (booking.leaseId != null) ...[
          Gap.h12,
          FilledButton.icon(
            onPressed: () => context.pushNamed(
              Routes.leaseDetail,
              pathParameters: {'leaseId': booking.leaseId!},
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('View your lease'),
          ),
        ],
        if (booking.status.awaitsBookingFee &&
            booking.bookingFeeInvoiceId != null) ...[
          Gap.h12,
          FilledButton.icon(
            onPressed: () => context.pushNamed(
              Routes.payment,
              pathParameters: {'invoiceId': booking.bookingFeeInvoiceId!},
            ),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Pay the booking fee'),
          ),
        ],
        if (booking.status == BookingStatus.active &&
            booking.depositInvoiceId != null) ...[
          Gap.h12,
          FilledButton.tonalIcon(
            onPressed: () => context.pushNamed(
              Routes.payment,
              pathParameters: {'invoiceId': booking.depositInvoiceId!},
            ),
            icon: const Icon(Icons.savings_outlined),
            label: const Text('Pay the deposit'),
          ),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.done,
    required this.isLast,
    this.detail,
  });

  final String label;
  final bool done;
  final String? detail;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = done ? scheme.primary : scheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                height: 22,
                width: 22,
                decoration: BoxDecoration(
                  color: done ? scheme.primary : Colors.transparent,
                  border: Border.all(color: color, width: 2),
                  shape: BoxShape.circle,
                ),
                child: done
                    ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
                    : null,
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: color)),
            ],
          ),
          Gap.w12,
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: done ? FontWeight.w600 : FontWeight.w500,
                      color: done ? null : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
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
          valueWidget: MoneyText(booking.monthlyRent),
        ),
        DetailRow(
          label: 'Security deposit',
          valueWidget: MoneyText(booking.depositAmount),
        ),
        DetailRow(
          label: 'Booking fee',
          valueWidget: MoneyText(booking.bookingFee),
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
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      children: [
        for (final requirement in booking.requirements)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
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
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
                              ?.copyWith(color: context.statusColors.positive),
                        ),
                    ],
                  ),
                ),
                if (!requirement.isSatisfied &&
                    requirement.requirementType == RequirementType.document)
                  _uploadingId == requirement.id
                      ? const Padding(
                          padding: EdgeInsets.all(Gap.sm),
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : TextButton(
                          onPressed: () => _submit(requirement),
                          child: const Text('Upload'),
                        ),
                // Payment requirements are met by paying the deposit invoice,
                // not by uploading anything.
                if (!requirement.isSatisfied &&
                    requirement.requirementType == RequirementType.payment &&
                    booking.depositInvoiceId != null)
                  TextButton(
                    onPressed: () => context.pushNamed(
                      Routes.payment,
                      pathParameters: {'invoiceId': booking.depositInvoiceId!},
                    ),
                    child: const Text('Pay'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
