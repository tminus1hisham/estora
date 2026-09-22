import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/billing.dart';
import 'invoice_card.dart';

/// A month of invoices, and the invoices in it, newest month first.
typedef InvoiceMonth = ({DateTime month, List<Invoice> invoices});

/// Groups invoices into months by their issue date.
///
/// A statement is read by month — "what did September cost me" — and an
/// undivided list of twenty invoices is not a statement. The order is newest
/// first in both dimensions, which is the order the question is usually asked
/// in.
List<InvoiceMonth> groupInvoicesByMonth(List<Invoice> invoices) {
  final sorted = [...invoices]
    ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));

  final months = <InvoiceMonth>[];
  for (final invoice in sorted) {
    final local = invoice.invoiceDate.toLocal();
    final key = DateTime(local.year, local.month);
    if (months.isNotEmpty && months.last.month == key) {
      months.last.invoices.add(invoice);
    } else {
      months.add((month: key, invoices: [invoice]));
    }
  }
  return months;
}

/// One month's heading and the invoices issued in it.
///
/// The month is the grouping; the invoices inside it are separate cards rather
/// than rows of one surface, because each carries an amount and, while it is
/// owed, an action of its own.
class InvoiceMonthSection extends StatelessWidget {
  const InvoiceMonthSection({required this.group, super.key});

  final InvoiceMonth group;

  @override
  Widget build(BuildContext context) {
    final count = group.invoices.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // Tight to its cards: the heading belongs to what is under it, and
          // the compact cards would sit adrift under a wider gap.
          padding: const EdgeInsets.fromLTRB(Gap.xs, 0, Gap.xs, 10),
          child: InvoiceSectionHeader(
            title: AppDate.monthYear(group.month).toUpperCase(),
            trailing: count == 1 ? '1 invoice' : '$count invoices',
          ),
        ),
        for (final (index, invoice) in group.invoices.indexed) ...[
          // Enough to keep each card's glass edge distinct, no more — the
          // cards are short, and a wide gap between them would make the
          // statement read as loose tiles rather than a list.
          if (index > 0) const SizedBox(height: 10),
          InvoiceCard(invoice: invoice),
        ],
      ],
    );
  }
}

/// A section heading in the iOS manner: small capitals in the secondary
/// colour, a count set against the far margin, and between them a hairline
/// of brass that fades out before it gets there.
///
/// The rule is the statement's one touch of brass. It is what lets the eye
/// run from the month to its count across a wide screen, and it is thin
/// enough that four of them down a page still read as structure rather than
/// ornament.
class InvoiceSectionHeader extends StatelessWidget {
  const InvoiceSectionHeader({required this.title, this.trailing, super.key});

  final String title;
  final String? trailing;

  /// The shortest the rule may be before it is dropped.
  static const double _minRule = 24;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final brass = dark ? AppPalette.brass300 : AppPalette.brass500;
    final trailing = this.trailing;

    final titleStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: AppTypography.semibold,
      letterSpacing: 1.2,
    );
    final trailingStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: AppTypography.medium,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        double measure(String text, TextStyle? style) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width;
        }

        final needed =
            measure(title, titleStyle) +
            (trailing == null ? 0 : measure(trailing, trailingStyle) + 12) +
            12 +
            _minRule;

        // At a large text size the month and its count stop fitting on one
        // line with a rule between them. The rule goes first, then the count
        // moves under the month — a heading is never broken mid-word.
        if (needed > constraints.maxWidth) {
          return Wrap(
            spacing: Gap.md,
            runSpacing: Gap.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(title, style: titleStyle),
              if (trailing != null) Text(trailing, style: trailingStyle),
            ],
          );
        }

        return Row(
          children: [
            Text(title, maxLines: 1, style: titleStyle),
            Gap.w12,
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      brass.withValues(alpha: dark ? 0.45 : 0.55),
                      brass.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            if (trailing != null) ...[
              Gap.w12,
              Text(trailing, maxLines: 1, style: trailingStyle),
            ],
          ],
        );
      },
    );
  }
}
