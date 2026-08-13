import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/amount_text.dart';
import '../../../components/app_bottom_action_bar.dart';
import '../../../components/app_success_mark.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/billing.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../navigation/routes.dart';
import '../application/payment_controller.dart';

/// Section 77's Payment Status screen.
///
/// This screen is the visible form of section 39's rule that the handset must
/// not decide a payment succeeded. It shows what the *server* currently says,
/// re-asking every few seconds, and it can only reach a success state because
/// the server reported one.
///
/// If polling times out, the payment is not cancelled or failed — it is simply
/// still unknown to this screen, and the tenant is told they will be notified.
/// Saying anything more definite would be a guess.
class PaymentStatusScreen extends ConsumerWidget {
  const PaymentStatusScreen({required this.paymentId, this.intent, super.key});

  final String paymentId;

  /// Passed straight from the payment screen, so the provider instruction
  /// ("check your phone for the M-Pesa prompt") is available immediately rather
  /// than after the first poll.
  final PaymentIntent? intent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ref.watch(paymentStatusProvider(paymentId));

    return PopScope(
      // Leaving mid-payment is allowed, but not by accident: the STK prompt is
      // still live on the tenant's handset.
      canPop: watch.value?.isSettled ?? false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave(context);
        if (leave == true && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payment'),
          automaticallyImplyLeading: false,
        ),
        body: switch (watch) {
          AsyncLoading() when !watch.hasValue => const LoadingView(
            message: 'Setting up your payment…',
          ),
          AsyncError(:final error) => ErrorView(
            failure: error is Failure
                ? error
                : UnknownFailure(error.toString()),
            onRetry: () => ref.invalidate(paymentStatusProvider(paymentId)),
          ),
          _ => _Body(watch: watch.requireValue, intent: intent),
        },
      ),
    );
  }

  Future<bool?> _confirmLeave(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Leave this screen?'),
      content: const Text(
        'Your payment is still being processed. It will carry on without you, '
        'and we will notify you when it completes.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Stay'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
}

class _Body extends ConsumerWidget {
  const _Body({required this.watch, this.intent});

  final PaymentWatch watch;
  final PaymentIntent? intent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payment = watch.payment;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.maxReadingWidth,
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Gap.lg,
                  Gap.xl,
                  Gap.lg,
                  Gap.xxl,
                ),
                children: [
                  _StatusHeader(watch: watch, intent: intent),
                  Gap.h24,

                  SectionCard(
                    title: 'Payment details',
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(Gap.lg),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: AppRadius.medium,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AMOUNT',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontWeight: AppTypography.extraBold,
                                    letterSpacing: 0.8,
                                  ),
                            ),
                            Gap.h4,
                            AmountText(payment.amount, scale: AmountScale.hero),
                          ],
                        ),
                      ),
                      Gap.h12,
                      DetailRow(
                        label: 'Reference',
                        value: payment.paymentReference,
                      ),
                      DetailRow(
                        label: 'Method',
                        value: payment.paymentMethod.label,
                      ),
                      if (payment.invoiceNumber != null)
                        DetailRow(
                          label: 'Invoice',
                          value: payment.invoiceNumber!,
                        ),
                      if (payment.providerTransactionId != null)
                        DetailRow(
                          label: 'Provider reference',
                          value: payment.providerTransactionId!,
                        ),
                      if (payment.paidAt != null)
                        DetailRow(
                          label: 'Paid at',
                          value: AppDate.dateTime(payment.paidAt!),
                        ),
                    ],
                  ),

                  if (payment.allocations.isNotEmpty) ...[
                    Gap.h12,
                    SectionCard(
                      title: 'Allocated to',
                      children: [
                        for (final allocation in payment.allocations)
                          DetailRow(
                            label:
                                allocation.invoiceNumber ??
                                allocation.invoiceId,
                            valueWidget: AmountText(
                              allocation.amount,
                              showCurrency: false,
                              align: TextAlign.end,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        AppBottomActionBar(child: _StatusActions(watch: watch)),
      ],
    );
  }
}

class _StatusActions extends ConsumerWidget {
  const _StatusActions({required this.watch});

  final PaymentWatch watch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payment = watch.payment;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (watch.succeeded) ...[
          if (payment.hasReceipt)
            FilledButton.icon(
              onPressed: () => context.pushReplacementNamed(
                Routes.receipt,
                pathParameters: {'receiptId': payment.receiptId!},
              ),
              icon: const Icon(Icons.receipt_outlined),
              label: const Text('View receipt'),
            ),
          Gap.h8,
          TextButton(
            onPressed: () => context.goNamed(Routes.invoices),
            child: const Text('Back to invoices'),
          ),
        ] else if (watch.isSettled) ...[
          FilledButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
          Gap.h8,
          TextButton(
            onPressed: () => context.goNamed(Routes.invoices),
            child: const Text('Back to invoices'),
          ),
        ] else ...[
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(paymentStatusProvider(payment.id)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Check again'),
          ),
          Gap.h4,
          TextButton(
            onPressed: () => context.goNamed(Routes.invoices),
            child: const Text('I will check later'),
          ),
        ],
      ],
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.watch, this.intent});

  final PaymentWatch watch;
  final PaymentIntent? intent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = watch.payment.status;
    final color = context.statusColors.resolve(status.tone);

    final (icon, title, message) = _content();

    return Column(
      children: [
        SizedBox(
          height: 88,
          width: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (watch.isPolling)
                // Still indeterminate: the server has not decided yet, and an
                // animation that looks resolved would be saying otherwise.
                SizedBox(
                  height: 88,
                  width: 88,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: color.withValues(alpha: 0.6),
                  ),
                ),
              if (watch.succeeded)
                // Drawn only once the server has reported success. This is the
                // one celebratory moment in the app.
                AppSuccessMark(color: color, icon: icon)
              else
                Container(
                  height: 68,
                  width: 68,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 34, color: color),
                ),
            ],
          ),
        ),
        Gap.h24,
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: AppTypography.bold),
        ),
        Gap.h8,
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  (IconData, String, String) _content() {
    final payment = watch.payment;

    if (watch.hasTimedOut && !watch.isSettled) {
      return (
        Icons.hourglass_empty_rounded,
        'Still processing',
        'This is taking longer than usual. Your payment has not been '
            'cancelled — we will notify you as soon as it completes, and it '
            'will appear in your payment history.',
      );
    }

    return switch (payment.status) {
      PaymentStatus.pending => (
        Icons.phone_android_rounded,
        'Check your phone',
        intent?.instruction ??
            'Approve the payment request on your handset to continue.',
      ),
      PaymentStatus.processing => (
        Icons.sync_rounded,
        'Confirming your payment',
        'Your provider is processing the payment. This usually takes a few '
            'seconds.',
      ),
      PaymentStatus.success => (
        Icons.check_circle_outline_rounded,
        'Payment received',
        'Thank you. Your invoice has been updated and a receipt has been '
            'issued.',
      ),
      PaymentStatus.failed => (
        Icons.error_outline_rounded,
        'Payment failed',
        payment.failureReason ??
            'The payment did not go through. Nothing has been charged.',
      ),
      PaymentStatus.cancelled => (
        Icons.cancel_outlined,
        'Payment cancelled',
        'The payment was cancelled. Nothing has been charged.',
      ),
      PaymentStatus.refunded || PaymentStatus.partiallyRefunded => (
        Icons.undo_rounded,
        'Payment refunded',
        'This payment has been refunded.',
      ),
      PaymentStatus.unknown => (
        Icons.help_outline_rounded,
        'Checking',
        'We are confirming the status of this payment.',
      ),
    };
  }
}
