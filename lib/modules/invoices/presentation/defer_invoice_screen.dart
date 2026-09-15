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
import '../application/invoice_controller.dart';

/// Asking for an invoice to be postponed.
///
/// Two things this screen is careful not to imply. It does not grant anything —
/// the landlord decides, and the copy says so. And it does not reduce the
/// balance: a deferred invoice is still owed in full, which is stated on the
/// screen rather than left to be discovered later.
///
/// The reason is required. A deferral request with no reason cannot be acted
/// on by whoever reads it, so it would sit unanswered — worse for the tenant
/// than being asked one question.
class DeferInvoiceScreen extends ConsumerStatefulWidget {
  const DeferInvoiceScreen({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  ConsumerState<DeferInvoiceScreen> createState() => _DeferInvoiceScreenState();
}

class _DeferInvoiceScreenState extends ConsumerState<DeferInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  /// Common reasons, offered as a starting point rather than as the whole
  /// answer — tapping one fills the field, which stays editable.
  static const List<String> _suggestions = [
    'Waiting on a customer payment',
    'Cash flow this month',
    'Disputing part of this invoice',
    'Business disruption',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit(Invoice invoice) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await ref
        .read(invoiceActionsProvider)
        .deferInvoice(
          invoiceId: invoice.id,
          reason: _reasonController.text.trim(),
        );

    if (!mounted) return;

    switch (result) {
      case Ok():
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request sent. You will hear back shortly.'),
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

  @override
  Widget build(BuildContext context) {
    final invoice = ref.watch(invoiceDetailProvider(widget.invoiceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Request more time')),
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
          _ => _body(invoice.requireValue),
        },
      ),
      bottomNavigationBar: invoice.hasValue && !invoice.requireValue.isDeferred
          ? AppBottomActionBar(
              child: AsyncButton(
                label: 'Send request',
                icon: Icons.schedule_send_outlined,
                expand: true,
                onPressed: () => _submit(invoice.requireValue),
              ),
            )
          : null,
    );
  }

  Widget _body(Invoice invoice) {
    final scheme = Theme.of(context).colorScheme;

    if (invoice.isDeferred) {
      return EmptyState(
        icon: Icons.schedule_outlined,
        title: 'Already requested',
        message: invoice.deferReason == null
            ? 'A postponement has been requested for this invoice.'
            : 'You asked for this invoice to be postponed: '
                  '"${invoice.deferReason}". We will be in touch.',
      );
    }

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
              Container(
                padding: const EdgeInsets.all(Gap.md),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.45),
                  borderRadius: AppRadius.small,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: scheme.onSecondaryContainer,
                    ),
                    Gap.w12,
                    Expanded(
                      child: Text(
                        'Asking for more time does not reduce what you owe, '
                        'and it is not granted automatically. The landlord '
                        'reads the request and replies.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              Gap.h16,
              SectionCard(
                title: 'Why you need more time',
                children: [
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.sm,
                    children: [
                      for (final suggestion in _suggestions)
                        ActionChip(
                          label: Text(suggestion),
                          onPressed: () => setState(
                            () => _reasonController.text = suggestion,
                          ),
                        ),
                    ],
                  ),
                  Gap.h16,
                  TextFormField(
                    controller: _reasonController,
                    maxLines: 4,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      alignLabelWithHint: true,
                      helperText:
                          'A specific reason, and when you expect to pay, gets '
                          'a faster answer.',
                      helperMaxLines: 2,
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Give a reason for the request';
                      return text.length < 10
                          ? 'Add a little more detail'
                          : null;
                    },
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
