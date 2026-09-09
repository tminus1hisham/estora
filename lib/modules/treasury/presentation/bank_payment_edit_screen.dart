import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_bottom_action_bar.dart';
import '../../../components/async_button.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/treasury.dart';
import '../../owner/presentation/widgets/owner_form.dart';
import '../application/treasury_controller.dart';

/// Correcting a recorded bank payment, or removing one entered in error.
///
/// Only reachable for a payment nobody has reconciled yet. Once it has been
/// matched against a statement it is a closed financial record, and the way to
/// undo one of those is a credit note, not an edit.
class BankPaymentEditScreen extends ConsumerStatefulWidget {
  const BankPaymentEditScreen({required this.paymentId, super.key});

  final String paymentId;

  @override
  ConsumerState<BankPaymentEditScreen> createState() =>
      _BankPaymentEditScreenState();
}

class _BankPaymentEditScreenState extends ConsumerState<BankPaymentEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _purposeController = TextEditingController();
  final _paidByController = TextEditingController();
  final _bankController = TextEditingController();
  final _branchController = TextEditingController();
  final _accountController = TextEditingController();

  String _method = BankPaymentDraft.methods.first;
  DateTime? _paidAt;
  bool _seeded = false;

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _purposeController.dispose();
    _paidByController.dispose();
    _bankController.dispose();
    _branchController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  void _seed(BankPayment payment) {
    if (_seeded) return;
    _seeded = true;
    _amountController.text = payment.amount.majorUnits.toStringAsFixed(0);
    _referenceController.text = payment.paymentReference;
    _purposeController.text = payment.purpose ?? '';
    _paidByController.text = payment.paidByName ?? '';
    _bankController.text = payment.bankName ?? '';
    _branchController.text = payment.branchName ?? '';
    _accountController.text = payment.bankAccountNumber ?? '';
    _paidAt = payment.paidAt;
    // Free text on the wire, so a stored method the picker does not offer is
    // added rather than silently replaced with the first option.
    _method = BankPaymentDraft.methods.contains(payment.paymentMethod)
        ? payment.paymentMethod
        : (payment.paymentMethod.isEmpty
              ? BankPaymentDraft.methods.first
              : payment.paymentMethod);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidAt ?? now,
      // A payment cannot have arrived in the future, and one from before the
      // platform existed is a typo.
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked != null) setState(() => _paidAt = picked);
  }

  Future<void> _save(BankPayment original) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = MoneyField.parse(
      _amountController.text,
      original.amount.currency,
    );
    if (amount == null) return;

    final result = await ref
        .read(treasuryActionsProvider)
        .updateBankPayment(
          BankPayment(
            id: original.id,
            amount: amount,
            paidAt: _paidAt ?? original.paidAt,
            paymentMethod: _method,
            paymentReference: _referenceController.text.trim(),
            invoiceId: original.invoiceId,
            tenantId: original.tenantId,
            propertyId: original.propertyId,
            blockId: original.blockId,
            purpose: _emptyToNull(_purposeController.text),
            paidByName: _emptyToNull(_paidByController.text),
            bankAccountNumber: _emptyToNull(_accountController.text),
            bankName: _emptyToNull(_bankController.text),
            branchName: _emptyToNull(_branchController.text),
            status: original.status,
            proofOfPaymentUrl: original.proofOfPaymentUrl,
            isProcessed: original.isProcessed,
            isSplit: original.isSplit,
            isReissued: original.isReissued,
            createdByName: original.createdByName,
            createdAt: original.createdAt,
          ),
        );

    if (!mounted) return;

    switch (result) {
      case Ok():
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment updated.'),
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

  Future<void> _confirmDelete(BankPayment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this payment?'),
        content: Text(
          'The record of ${payment.amount.format()} against reference '
          '${payment.paymentReference} is deleted. Do this only if it was '
          'entered in error — a payment that genuinely arrived should be '
          'corrected, not removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(treasuryActionsProvider)
        .deleteBankPayment(payment.id);
    if (!mounted) return;

    switch (result) {
      case Ok():
        Navigator.of(context).pop();
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
    final payments = ref.watch(bankPaymentsProvider);

    return switch (payments) {
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(title: const Text('Bank payment')),
        body: ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(bankPaymentsProvider),
        ),
      ),
      AsyncData(:final value) => _resolve(value),
      _ => Scaffold(
        appBar: AppBar(title: const Text('Bank payment')),
        body: const LoadingView(),
      ),
    };
  }

  Widget _resolve(List<BankPayment> payments) {
    for (final payment in payments) {
      if (payment.id == widget.paymentId) return _form(payment);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Bank payment')),
      body: const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'That payment is no longer listed',
        message: 'It may have been removed or reconciled from another device.',
      ),
    );
  }

  Widget _form(BankPayment payment) {
    _seed(payment);
    final currency = payment.amount.currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank payment'),
        actions: [
          IconButton(
            onPressed: () => _confirmDelete(payment),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Remove payment',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
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
                SectionCard(
                  title: 'The payment',
                  children: [
                    MoneyField(
                      label: 'Amount',
                      controller: _amountController,
                      currency: currency,
                    ),
                    Gap.h12,
                    OwnerField(
                      label: 'Bank reference',
                      controller: _referenceController,
                      textCapitalization: TextCapitalization.characters,
                      helper: 'What reconciliation matches on.',
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Enter the bank reference'
                          : null,
                    ),
                    Gap.h12,
                    DropdownButtonFormField<String>(
                      initialValue: _method,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Method'),
                      items: [
                        for (final method in {
                          ...BankPaymentDraft.methods,
                          _method,
                        })
                          DropdownMenuItem(value: method, child: Text(method)),
                      ],
                      onChanged: (value) =>
                          setState(() => _method = value ?? _method),
                    ),
                    Gap.h12,
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: const Text('Payment date'),
                      subtitle: Text(AppDate.full(_paidAt ?? payment.paidAt)),
                      trailing: TextButton(
                        onPressed: _pickDate,
                        child: const Text('Change'),
                      ),
                    ),
                  ],
                ),
                Gap.h12,
                SectionCard(
                  title: 'Who paid',
                  children: [
                    OwnerField(
                      label: 'Paid by',
                      controller: _paidByController,
                      textCapitalization: TextCapitalization.words,
                      validator: (_) => null,
                    ),
                    Gap.h12,
                    OwnerField(
                      label: 'Purpose',
                      controller: _purposeController,
                      helper: 'What the payment is for.',
                      validator: (_) => null,
                    ),
                  ],
                ),
                Gap.h12,
                SectionCard(
                  title: 'Bank details',
                  children: [
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
                if (payment.createdByName != null) ...[
                  Gap.h12,
                  Text(
                    'Recorded by ${payment.createdByName}'
                    '${payment.createdAt == null ? '' : ' on ${AppDate.full(payment.createdAt!)}'}.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomActionBar(
        child: AsyncButton(
          label: 'Save changes',
          icon: Icons.check_rounded,
          expand: true,
          onPressed: () => _save(payment),
        ),
      ),
    );
  }
}
