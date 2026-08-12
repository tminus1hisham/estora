import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/money_text.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/billing.dart';
import '../../documents/application/document_controller.dart';
import '../application/payment_controller.dart';

/// Section 77's Receipt screen. Section 40 requires one for every successful
/// payment, downloadable as a PDF.
class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({required this.receiptId, super.key});

  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = ref.watch(receiptProvider(receiptId));

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: switch (receipt) {
        AsyncLoading() => const LoadingView(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(receiptProvider(receiptId)),
        ),
        AsyncData(:final value) => _Body(receipt: value),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, Gap.xxl),
      children: [
        Column(
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 32,
                color: scheme.onPrimaryContainer,
              ),
            ),
            Gap.h16,
            MoneyText(receipt.amount, emphasise: true),
            Gap.h4,
            Text(
              'Received ${AppDate.full(receipt.issuedAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        Gap.h32,
        SectionCard(
          children: [
            DetailRow(label: 'Receipt number', value: receipt.receiptNumber),
            if (receipt.paymentReference != null)
              DetailRow(
                label: 'Payment reference',
                value: receipt.paymentReference!,
              ),
            if (receipt.paymentMethod != null)
              DetailRow(label: 'Method', value: receipt.paymentMethod!.label),
            if (receipt.propertyName != null)
              DetailRow(label: 'Property', value: receipt.propertyName!),
            DetailRow(
              label: 'Issued',
              value: AppDate.dateTime(receipt.issuedAt),
            ),
          ],
        ),
        Gap.h24,
        if (receipt.documentId != null)
          FilledButton.icon(
            onPressed: () => ref
                .read(documentActionsProvider)
                .openDocument(context, receipt.documentId!),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download PDF'),
          ),
      ],
    );
  }
}
