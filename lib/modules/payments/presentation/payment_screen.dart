import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/amount_text.dart';
import '../../../components/app_bottom_action_bar.dart';
import '../../../components/app_stepper.dart';
import '../../../components/async_button.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/billing.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../navigation/routes.dart';
import '../../auth/application/auth_controller.dart';
import '../../invoices/application/invoice_controller.dart';
import '../application/payment_controller.dart';

/// Section 77's Payment screen. M-Pesa is first-class, per section 39.
///
/// The tenant chooses a method and, for M-Pesa, the handset to prompt. They do
/// not enter an amount — section 65 puts that on the server, which charges what
/// the invoice says is outstanding. Showing an editable amount here would
/// invite exactly the client-supplied total the spec forbids.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  PaymentMethod _method = PaymentMethod.mpesa;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: ref.read(authControllerProvider).user?.phone ?? '',
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// [invoice] supplies the amount, straight off the record the server sent.
  ///
  /// The contract's payment request carries the figure, so it has to come from
  /// somewhere — and the only honest somewhere is the invoice as displayed.
  /// Nothing on this screen adds a fee or a rounding to it.
  Future<void> _pay(Invoice invoice) async {
    final result = await ref
        .read(paymentActionsProvider)
        .initiate(
          invoiceId: widget.invoiceId,
          method: _method,
          amount: invoice.amountDue,
          phoneNumber: _method == PaymentMethod.mpesa
              ? _phoneController.text.trim()
              : null,
        );

    if (!mounted) return;

    switch (result) {
      case Ok(:final value):
        // Straight to the status screen, which polls. Replacing rather than
        // pushing: going "back" to a payment form for a payment already in
        // flight would invite a second attempt.
        context.pushReplacementNamed(
          Routes.paymentStatus,
          pathParameters: {'paymentId': value.paymentId},
          extra: value,
        );
      case Err(:final failure):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = ref.watch(invoiceDetailProvider(widget.invoiceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Make a payment')),
      body: switch (invoice) {
        AsyncLoading() => const LoadingView(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () =>
              ref.invalidate(invoiceDetailProvider(widget.invoiceId)),
        ),
        AsyncData(:final value) => _buildForm(value),
      },
    );
  }

  Widget _buildForm(Invoice invoice) {
    final scheme = Theme.of(context).colorScheme;
    final canPay =
        _method != PaymentMethod.mpesa ||
        _phoneController.text.trim().length >= 9;

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
                  Gap.sm,
                  Gap.lg,
                  Gap.xxl,
                ),
                children: [
                  const AppStepper.horizontal(
                    steps: _paymentSteps,
                    currentIndex: 0,
                  ),
                  Gap.h24,
                  Container(
                    padding: const EdgeInsets.all(Gap.xl),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.55),
                      borderRadius: AppRadius.large,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AMOUNT DUE',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.primary,
                                fontWeight: AppTypography.extraBold,
                                letterSpacing: 0.8,
                              ),
                        ),
                        Gap.h8,
                        // The server's figure. Not editable, and not assembled here.
                        // The one figure this screen exists to show, so it takes
                        // the hero scale — size carries it, not weight.
                        AmountText(invoice.amountDue, scale: AmountScale.hero),
                        Gap.h12,
                        Text(
                          invoice.invoiceNumber,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),

                  Gap.h16,
                  Text(
                    'How would you like to pay?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                  Gap.h8,
                  RadioGroup<PaymentMethod>(
                    groupValue: _method,
                    onChanged: (value) =>
                        setState(() => _method = value ?? _method),
                    child: Column(
                      children: [
                        for (final method in PaymentMethod.tenantSelectable)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Gap.sm),
                            child: _PaymentMethodTile(
                              method: method,
                              selected: method == _method,
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (_method == PaymentMethod.mpesa) ...[
                    Gap.h12,
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'M-Pesa number',
                        hintText: '+254 712 345 678',
                        prefixIcon: Icon(Icons.phone_android_rounded),
                        helperText: 'The prompt is sent to this number',
                      ),
                    ),
                  ],

                  Gap.h16,
                  Container(
                    padding: const EdgeInsets.all(Gap.md),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: AppRadius.small,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        Gap.w12,
                        Expanded(
                          child: Text(
                            // Section 39, in plain language: the app does not get
                            // to decide the payment worked.
                            'Your payment is confirmed by your provider and '
                            'verified by us before your invoice is marked paid.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AppBottomActionBar(
          child: AsyncButton(
            label: 'Pay ${invoice.amountDue.format()}',
            icon: Icons.lock_outline_rounded,
            expand: true,
            enabled: canPay,
            onPressed: () => _pay(invoice),
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({required this.method, required this.selected});

  final PaymentMethod method;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (method) {
      PaymentMethod.mpesa => Icons.phone_android_rounded,
      PaymentMethod.card => Icons.credit_card_rounded,
      PaymentMethod.bankTransfer => Icons.account_balance_outlined,
      _ => Icons.payments_outlined,
    };
    final subtitle = switch (method) {
      PaymentMethod.mpesa => 'Prompt sent securely to your phone',
      PaymentMethod.card => 'Visa or Mastercard',
      PaymentMethod.bankTransfer => 'Use a unique payment reference',
      _ => '',
    };

    // Animated so that choosing a method reads as a change of state rather
    // than a repaint. The border weight carries most of it; the fill is a
    // supporting cue for anyone who cannot see the colour shift.
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.enter,
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.45)
            : scheme.surface,
        borderRadius: AppRadius.medium,
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: RadioListTile<PaymentMethod>(
        value: method,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.xs,
        ),
        secondary: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: AppRadius.small,
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          method.label,
          style: const TextStyle(fontWeight: AppTypography.bold),
        ),
        subtitle: Text(subtitle),
      ),
    );
  }
}

const _paymentSteps = <AppStep>[
  AppStep(label: 'Method'),
  AppStep(label: 'Authorise'),
  AppStep(label: 'Receipt'),
];
