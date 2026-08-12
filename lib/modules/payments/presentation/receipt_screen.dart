import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_bottom_action_bar.dart';
import '../../../components/app_success_mark.dart';
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
                AppSuccessMark(
                  color: scheme.primary,
                  icon: Icons.check_rounded,
                ),
                Gap.h16,
                Text(
                  'Payment received',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
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
            _ReceiptPaper(
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

/// The receipt itself, drawn as a piece of paper rather than as a card.
///
/// A receipt is the one artefact in this flow the tenant may screenshot, file
/// or send to an accountant, so it is worth it looking like a document. The
/// torn edges are the whole of the effect — everything inside is the same
/// DetailRow layout used on every other detail screen.
class _ReceiptPaper extends StatelessWidget {
  const _ReceiptPaper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // PhysicalShape rather than a DecoratedBox: it casts a shadow that follows
    // the torn outline, where a box shadow would draw a rectangle behind the
    // notches and give the illusion away.
    return PhysicalShape(
      clipper: const _TornPaperClipper(),
      color: scheme.surfaceContainerLowest,
      elevation: AppElevation.medium,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      child: child,
    );
  }
}

/// A rectangle whose top and bottom edges are torn into semicircular notches.
class _TornPaperClipper extends CustomClipper<Path> {
  const _TornPaperClipper();

  /// Chosen so the notches divide evenly into any width: the count is derived
  /// from the width and the radius follows, rather than the other way round,
  /// which would leave a clipped part-notch at one end.
  static const double _targetNotchWidth = 18;

  @override
  Path getClip(Size size) {
    final count = (size.width / _targetNotchWidth).round().clamp(4, 60);
    final notch = size.width / count;
    final radius = notch / 2;

    final path = Path()..moveTo(0, radius);

    for (var i = 0; i < count; i++) {
      path.arcToPoint(
        Offset((i + 1) * notch, radius),
        radius: Radius.circular(radius),
        clockwise: false,
      );
    }

    path.lineTo(size.width, size.height - radius);

    for (var i = count; i > 0; i--) {
      path.arcToPoint(
        Offset((i - 1) * notch, size.height - radius),
        radius: Radius.circular(radius),
        clockwise: false,
      );
    }

    return path..close();
  }

  @override
  bool shouldReclip(_TornPaperClipper oldClipper) => false;
}
