import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_bottom_action_bar.dart';
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
      bottomNavigationBar: receipt.value?.documentId != null
          ? AppBottomActionBar(
              child: FilledButton.icon(
                onPressed: () => ref
                    .read(documentActionsProvider)
                    .openDocument(context, receipt.requireValue.documentId!),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download PDF'),
              ),
            )
          : null,
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, Gap.xxl),
          children: [
            Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 34,
                    color: scheme.onPrimary,
                  ),
                ),
                Gap.h16,
                Text(
                  'Payment received',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Gap.h4,
                Text(
                  'A verified receipt has been issued.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Gap.h24,
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Gap.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      receipt.propertyName ?? 'TENANT PAYMENT RECEIPT',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Gap.h24,
                    Text(
                      'AMOUNT RECEIVED',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                    Gap.h8,
                    Center(child: MoneyText(receipt.amount, emphasise: true)),
                    Gap.h4,
                    Text(
                      AppDate.full(receipt.issuedAt),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: Gap.xl),
                      child: Divider(),
                    ),
                    DetailRow(
                      label: 'Receipt number',
                      value: receipt.receiptNumber,
                    ),
                    if (receipt.paymentReference != null)
                      DetailRow(
                        label: 'Payment reference',
                        value: receipt.paymentReference!,
                      ),
                    if (receipt.paymentMethod != null)
                      DetailRow(
                        label: 'Method',
                        value: receipt.paymentMethod!.label,
                      ),
                    if (receipt.propertyName != null)
                      DetailRow(
                        label: 'Property',
                        value: receipt.propertyName!,
                      ),
                    DetailRow(
                      label: 'Issued',
                      value: AppDate.dateTime(receipt.issuedAt),
                    ),
                    Gap.h24,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 16,
                          color: scheme.primary,
                        ),
                        Gap.w8,
                        Flexible(
                          child: Text(
                            'Verified digital receipt',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: scheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
