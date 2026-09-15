import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/amount_text.dart';
import '../../../components/app_bottom_action_bar.dart';
import '../../../components/async_button.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/billing.dart';
import '../../../domain/entities/treasury.dart';
import '../../invoices/application/invoice_controller.dart';
import '../../owner/presentation/widgets/owner_form.dart';
import '../../treasury/application/treasury_controller.dart';

/// Telling the landlord about a payment made outside the app.
///
/// The contract has one in-app payment route, and it is M-Pesa. Everything
/// else — a transfer, an RTGS, a cheque — happens at a bank and arrives here
/// afterwards as a claim: *I paid this, against this invoice, with this
/// reference*. Nothing on this screen marks the invoice paid. Somebody checks
/// it against the statement first, which is why the amount is prefilled from
/// the balance and still editable: a part payment is a real thing.
class BankTransferScreen extends ConsumerStatefulWidget {
  const BankTransferScreen({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  ConsumerState<BankTransferScreen> createState() => _BankTransferScreenState();
}

class _BankTransferScreenState extends ConsumerState<BankTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _paidByController = TextEditingController();
  final _bankController = TextEditingController();
  final _branchController = TextEditingController();
  final _accountController = TextEditingController();

  String _method = BankPaymentDraft.methods.first;
  DateTime _paidAt = DateTime.now();
  bool _seeded = false;

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _paidByController.dispose();
    _bankController.dispose();
    _branchController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  void _seed(Invoice invoice) {
    if (_seeded) return;
    _seeded = true;
    _amountController.text = invoice.amountDue.majorUnits.toStringAsFixed(0);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null) setState(() => _paidAt = picked);
  }

  Future<void> _submit(Invoice invoice) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = MoneyField.parse(_amountController.text, invoice.currency);
    if (amount == null) return;

    final result = await ref
        .read(treasuryActionsProvider)
        .recordBankPayment(
          BankPaymentDraft(
            amount: amount,
            paidAt: _paidAt,
            paymentMethod: _method,
            paymentReference: _referenceController.text.trim(),
            invoiceId: invoice.id,
            tenantId: invoice.tenantId,
            purpose: 'Invoice ${invoice.invoiceNumber}',
            paidByName: _emptyToNull(_paidByController.text),
            bankName: _emptyToNull(_bankController.text),
            branchName: _emptyToNull(_branchController.text),
            bankAccountNumber: _emptyToNull(_accountController.text),
          ),
        );

    if (!mounted) return;

    switch (result) {
      case Ok():
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment submitted. It will show against the invoice once it is '
              'matched to the statement.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
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

  static String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) {
    final invoice = ref.watch(invoiceDetailProvider(widget.invoiceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Record a bank payment')),
      body: AppRefreshIndicator(
        onRefresh: () async {
          await ref
              .refresh(invoiceDetailProvider(widget.invoiceId).future)
              .then<void>((_) {});
        },
        child: switch (invoice) {
          AsyncLoading() when !invoice.hasValue => const LoadingView(),
          AsyncError(:final error) => ErrorView(
            failure: error is Failure
                ? error
                : UnknownFailure(error.toString()),
            onRetry: () =>
                ref.invalidate(invoiceDetailProvider(widget.invoiceId)),
          ),
          _ => _form(invoice.requireValue),
        },
      ),
      bottomNavigationBar: invoice.hasValue
          ? AppBottomActionBar(
              child: AsyncButton(
                label: 'Submit payment',
                icon: Icons.send_rounded,
                expand: true,
                onPressed: () => _submit(invoice.requireValue),
              ),
            )
          : null,
    );
  }

  Widget _form(Invoice invoice) {
    _seed(invoice);
    final scheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            children: [
              Container(
                padding: const EdgeInsets.all(Gap.md),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: AppRadius.small,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    Gap.w12,
                    Expanded(
                      child: Text(
                        'This tells us about a payment you have already made. '
                        'The invoice is updated once the payment is matched to '
                        'the bank statement.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              Gap.h16,
              SectionCard(
                title: 'Invoice ${invoice.invoiceNumber}',
                children: [
                  DetailRow(
                    label: 'Outstanding',
                    valueWidget: AmountText(
                      invoice.amountDue,
                      align: TextAlign.end,
                    ),
                    emphasise: true,
                  ),
                  DetailRow(label: 'Due', value: AppDate.full(invoice.dueDate)),
                ],
              ),
              Gap.h12,
              SectionCard(
                title: 'What you paid',
                children: [
                  MoneyField(
                    label: 'Amount paid',
                    controller: _amountController,
                    currency: invoice.currency,
                    helper:
                        'Prefilled with the outstanding balance. Change it if '
                        'you paid part of it.',
                  ),
                  Gap.h12,
                  DropdownButtonFormField<String>(
                    initialValue: _method,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'How you paid',
                    ),
                    items: [
                      for (final method in BankPaymentDraft.methods)
                        DropdownMenuItem(value: method, child: Text(method)),
                    ],
                    onChanged: (value) =>
                        setState(() => _method = value ?? _method),
                  ),
                  Gap.h12,
                  OwnerField(
                    label: 'Bank reference',
                    controller: _referenceController,
                    textCapitalization: TextCapitalization.characters,
                    helper:
                        'The reference on your transfer confirmation. This is '
                        'what the payment is matched on.',
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter the reference from your bank'
                        : null,
                  ),
                  Gap.h12,
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Date paid'),
                    subtitle: Text(AppDate.full(_paidAt)),
                    trailing: TextButton(
                      onPressed: _pickDate,
                      child: const Text('Change'),
                    ),
                  ),
                ],
              ),
              Gap.h12,
              SectionCard(
                title: 'Where it came from',
                children: [
                  Text(
                    'Optional, and worth filling in — it is what lets us find '
                    'your payment if the reference does not match.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Gap.h16,
                  OwnerField(
                    label: 'Account name',
                    controller: _paidByController,
                    textCapitalization: TextCapitalization.words,
                    validator: (_) => null,
                  ),
                  Gap.h12,
                  OwnerField(
                    label: 'Bank',
                    controller: _bankController,
                    textCapitalization: TextCapitalization.words,
                    validator: (_) => null,
                  ),
                  Gap.h12,
                  OwnerField(
                    label: 'Branch',
                    controller: _branchController,
                    textCapitalization: TextCapitalization.words,
                    validator: (_) => null,
                  ),
                  Gap.h12,
                  OwnerField(
                    label: 'Account number',
                    controller: _accountController,
                    validator: (_) => null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
