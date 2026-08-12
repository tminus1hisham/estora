import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_bottom_action_bar.dart';
import '../../../components/app_stepper.dart';
import '../../../components/async_button.dart';
import '../../../components/money_text.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/booking.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../navigation/routes.dart';
import '../application/booking_controller.dart';

/// Section 77's Booking screen.
///
/// Everything financial on this screen comes from a server-issued quote. There
/// is no arithmetic here: no summing of fee and tax into a total, no
/// multiplying rent by deposit months. Section 65 puts that on the server, and
/// section 84 rule 7 makes it a rule rather than a preference — so the screen
/// renders the server's numbers and submits only the unit id.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({required this.unitId, super.key});

  final String unitId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  bool _acceptedTerms = false;

  Future<void> _confirm() async {
    final result = await ref
        .read(bookingActionsProvider)
        .createBooking(widget.unitId);

    if (!mounted) return;

    switch (result) {
      case Ok(:final value):
        // Replace rather than push: coming "back" to a booking confirmation
        // screen for a booking that now exists makes no sense.
        context.pushReplacementNamed(
          Routes.bookingStatus,
          pathParameters: {'bookingId': value.id},
        );
      case Err(:final failure):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // A conflict means the unit went while this screen was open
        // (section 48). Send them back to the list rather than leaving them on
        // a quote that can no longer be acted on.
        if (failure is ConflictFailure) {
          Navigator.of(context).pop();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = ref.watch(bookingQuoteProvider(widget.unitId));

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm your booking')),
      body: switch (quote) {
        AsyncLoading() => const LoadingView(message: 'Preparing your quote…'),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(bookingQuoteProvider(widget.unitId)),
        ),
        AsyncData(:final value) => _QuoteBody(
          quote: value,
          acceptedTerms: _acceptedTerms,
          onAcceptedChanged: (v) => setState(() => _acceptedTerms = v),
        ),
      },
      // AppBottomActionBar keeps the height factor this screen needs: a bottom
      // navigation child receives the scaffold's full height as its upper
      // bound, and without one the bar expands to that bound and leaves almost
      // no viewport for the quote list above it.
      bottomNavigationBar: quote.hasValue
          ? AppBottomActionBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PayableSummary(amount: quote.requireValue.total),
                  Gap.h12,
                  AsyncButton(
                    label: 'Confirm booking',
                    icon: Icons.lock_outline_rounded,
                    expand: true,
                    enabled: _acceptedTerms,
                    onPressed: _confirm,
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class _QuoteBody extends StatelessWidget {
  const _QuoteBody({
    required this.quote,
    required this.acceptedTerms,
    required this.onAcceptedChanged,
  });

  final BookingQuote quote;
  final bool acceptedTerms;
  final ValueChanged<bool> onAcceptedChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
          children: [
            const AppStepper.horizontal(steps: _bookingSteps, currentIndex: 0),
            Gap.h24,
            Text(
              'Secure this unit',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Gap.h4,
            Text(
              'Review the server-issued quote before confirming your booking.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Gap.h16,
            SectionCard(
              title: 'To pay now',
              children: [
                DetailRow(
                  label: 'Booking fee',
                  valueWidget: MoneyText(quote.bookingFee),
                ),
                if (quote.taxAmount != null && quote.taxAmount!.isPositive)
                  DetailRow(
                    label: quote.taxLabel ?? 'Tax',
                    valueWidget: MoneyText(quote.taxAmount!),
                  ),
                const Divider(),
                DetailRow(
                  label: 'Total',
                  // The server's total, rendered as received.
                  valueWidget: MoneyText(quote.total),
                  emphasise: true,
                ),
                Gap.h8,
                Container(
                  padding: const EdgeInsets.all(Gap.md),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
                      Gap.w12,
                      Expanded(
                        child: Text(
                          'Paying the booking fee holds this unit for '
                          '${quote.expiryHours} hours while you complete the '
                          'requirements below.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Gap.h12,
            SectionCard(
              title: 'To pay before your lease starts',
              children: [
                DetailRow(
                  label: quote.depositMonths == null
                      ? 'Security deposit'
                      : 'Security deposit (${quote.depositMonths} months)',
                  valueWidget: MoneyText(quote.depositAmount),
                ),
                Gap.h8,
                Text(
                  'Invoiced once your booking is confirmed. Refundable at the end '
                  'of your lease, less any deductions.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            Gap.h12,
            SectionCard(
              title: 'Your rent',
              children: [
                DetailRow(
                  label: 'Monthly rent',
                  valueWidget: MoneyText(quote.monthlyRent),
                  emphasise: true,
                ),
                Gap.h8,
                Text(
                  // Section 21, stated to the tenant because it is a commitment
                  // being made to them, not just an implementation detail.
                  'This is the rent your booking is held at. If the listed price '
                  'changes later, your booking and lease keep this figure.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            if (quote.requirements.isNotEmpty) ...[
              Gap.h12,
              SectionCard(
                title: 'What you will need to provide',
                children: [
                  for (final requirement in quote.requirements)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            requirement.requirementType ==
                                    RequirementType.payment
                                ? Icons.payments_outlined
                                : Icons.description_outlined,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          ),
                          Gap.w12,
                          Expanded(
                            child: Text(
                              requirement.isMandatory
                                  ? requirement.name
                                  : '${requirement.name} (optional)',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],

            Gap.h16,
            Card(
              color: acceptedTerms
                  ? scheme.primaryContainer.withValues(alpha: 0.35)
                  : scheme.surfaceContainerLow,
              child: CheckboxListTile(
                value: acceptedTerms,
                onChanged: (value) => onAcceptedChanged(value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: Gap.xs,
                ),
                title: Text(
                  'I understand the booking fee is payable now and that this hold '
                  'expires after ${quote.expiryHours} hours if the requirements are '
                  'not met.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayableSummary extends StatelessWidget {
  const _PayableSummary({required this.amount});

  final Money amount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stack = MediaQuery.textScalerOf(context).scale(1) > 1.2;

    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payable now',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        Text(
          'Secure checkout',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
    final value = MoneyText(amount, emphasise: true);

    return stack
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label, Gap.h8, value],
          )
        : Row(
            children: [
              Expanded(child: label),
              Gap.w12,
              Flexible(child: value),
            ],
          );
  }
}

const _bookingSteps = <AppStep>[
  AppStep(label: 'Review', icon: Icons.receipt_long_outlined),
  AppStep(label: 'Confirm', icon: Icons.payments_outlined),
  AppStep(label: 'Complete', icon: Icons.check_circle_outline_rounded),
];
