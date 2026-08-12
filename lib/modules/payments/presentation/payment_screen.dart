import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/async_button.dart';
import '../../../components/money_text.dart';
import '../../../components/section_card.dart';
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

  Future<void> _pay() async {
    final result = await ref
        .read(paymentActionsProvider)
        .initiate(
          invoiceId: widget.invoiceId,
          method: _method,
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Gap.lg,
              Gap.sm,
              Gap.lg,
              Gap.xxl,
            ),
            children: [
              SectionCard(
                children: [
                  Text(
                    'Amount due',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Gap.h4,
                  // The server's figure. Not editable, and not assembled here.
                  MoneyText(invoice.amountDue, emphasise: true),
                  Gap.h8,
                  Text(
                    'For ${invoice.invoiceNumber}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              Gap.h16,
              Text(
                'How would you like to pay?',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Gap.h8,
              RadioGroup<PaymentMethod>(
                groupValue: _method,
                onChanged: (value) =>
                    setState(() => _method = value ?? _method),
                child: Column(
                  children: [
                    for (final method in PaymentMethod.tenantSelectable)
                      RadioListTile<PaymentMethod>(
                        value: method,
                        contentPadding: EdgeInsets.zero,
                        title: Text(method.label),
                        subtitle: Text(
                          switch (method) {
                            PaymentMethod.mpesa =>
                              'You will get a prompt on your phone',
                            PaymentMethod.card => 'Visa or Mastercard',
                            PaymentMethod.bankTransfer =>
                              'Transfer using the reference we give you',
                            _ => '',
                          },
                          style: Theme.of(context).textTheme.bodySmall,
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
                  borderRadius: BorderRadius.circular(12),
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
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: AsyncButton(
              label: 'Pay ${invoice.amountDue.format()}',
              icon: Icons.lock_outline_rounded,
              enabled: canPay,
              onPressed: _pay,
            ),
          ),
        ),
      ],
    );
  }
}
