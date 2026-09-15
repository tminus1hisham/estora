import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/amount_text.dart';
import '../../../components/app_bottom_action_bar.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/state_views.dart';
import '../../../components/surface_atoms.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/billing.dart';
import '../../../navigation/routes.dart';
import '../application/invoice_controller.dart';
import 'widgets/invoice_document.dart';

/// Section 77's Invoice Details screen.
///
/// Read as a document: the head of the invoice on the brand surface, then what
/// it is made of, then — only if it applies — the warning. Nothing between
/// those three is a card for its own sake.
class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(invoiceDetailProvider(invoiceId));

    // The two ways of dealing with an invoice that are not "pay it now": tell
    // us about a payment made at a bank, and ask for more time. Both are real
    // and neither belongs on the primary action, so they sit in the overflow
    // rather than competing with it.
    final payable = invoice.value?.isPayable ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(invoice.value?.invoiceNumber ?? 'Invoice'),
        actions: [
          if (payable)
            PopupMenuButton<String>(
              onSelected: (action) => context.pushNamed(
                action == 'bank' ? Routes.bankTransfer : Routes.deferInvoice,
                pathParameters: {'invoiceId': invoiceId},
              ),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'bank',
                  child: Text('I paid by bank transfer'),
                ),
                if (invoice.requireValue.canRequestDeferral)
                  const PopupMenuItem(
                    value: 'defer',
                    child: Text('Request more time'),
                  ),
              ],
            ),
        ],
      ),
      body: switch (invoice) {
        AsyncLoading() when !invoice.hasValue => const AppSkeletonDetail(
          heroHeight: 260,
        ),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () async {
            await ref
                .refresh(invoiceDetailProvider(invoiceId).future)
                .then<void>((_) {});
          },
        ),
        _ => _Body(invoice: invoice.requireValue),
      },
      bottomNavigationBar: (invoice.value?.isPayable ?? false)
          ? _PayBar(invoice: invoice.requireValue)
          : null,
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = <Widget>[
      InvoiceDocumentHero(invoice: invoice),
      InvoiceLedger(invoice: invoice),
      if (invoice.isOverdue) const InvoiceOverdueNotice(),
    ];

    return AppRefreshIndicator(
      onRefresh: () async {
        await ref
            .refresh(invoiceDetailProvider(invoice.id).future)
            .then<void>((_) {});
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.xxl),
            itemCount: sections.length,
            separatorBuilder: (_, _) => Gap.h16,
            itemBuilder: (context, index) =>
                AppReveal(index: index, child: sections[index]),
          ),
        ),
      ),
    );
  }
}

/// The amount owed, and the way to settle it, held at the foot of the screen.
class _PayBar extends StatelessWidget {
  const _PayBar({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stacked = prefersStacked(context);

    final amount = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'AMOUNT DUE',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        Gap.h4,
        AmountText(
          invoice.amountDue,
          scale: AmountScale.title,
          color: invoice.isOverdue ? scheme.error : null,
        ),
      ],
    );

    final pay = FilledButton.icon(
      onPressed: () => context.pushNamed(
        Routes.payment,
        pathParameters: {'invoiceId': invoice.id},
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppLayout.controlHeight),
      ),
      icon: const Icon(Icons.lock_outline_rounded),
      label: const Text('Pay securely'),
    );

    return AppBottomActionBar(
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [amount, Gap.h12, pay],
            )
          : Row(
              children: [
                Expanded(child: amount),
                Gap.w16,
                Expanded(child: pay),
              ],
            ),
    );
  }
}
