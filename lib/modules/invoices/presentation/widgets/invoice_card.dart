import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/glass_material.dart';
import '../../../../components/property_tag.dart';
import '../../../../components/status_chip.dart';
import '../../../../components/surface_atoms.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/billing.dart';
import '../../../../domain/enums/domain_enums.dart';
import '../../../../navigation/routes.dart';
import '../../application/billing_property_filter.dart';
import 'pay_invoice.dart';

/// One invoice, as a frosted pane with its status down a tinted rail.
///
/// The number and date across the top, the figure opposite "Pay now", and the
/// status as a chip underneath — with the property tag beside it while the
/// statement spans more than one property. The statement and the home
/// preview use this same card.
///
/// Nothing here is summed: the figure is the server's `amountDue` as supplied
/// (section 84 rule 7, section 65).
class InvoiceCard extends ConsumerWidget {
  const InvoiceCard({required this.invoice, super.key});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stacked = prefersStacked(context);
    final (label, tone) = _status;
    final color = context.statusColors.resolve(tone);
    final muted = scheme.onSurfaceVariant;

    final number = Text(
      _number,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(
        color: muted,
        fontWeight: AppTypography.semibold,
      ),
    );

    // Due while it is owed; once settled, when it was issued.
    final date = Semantics(
      label: invoice.isPayable
          ? 'Due ${AppDate.short(invoice.dueDate)}'
          : 'Issued ${AppDate.short(invoice.invoiceDate)}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined, size: 15, color: muted),
          Gap.w4,
          Flexible(
            child: Text(
              AppDate.short(
                invoice.isPayable ? invoice.dueDate : invoice.invoiceDate,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );

    final figure = AmountText(
      invoice.isPayable ? invoice.amountDue : invoice.total,
      scale: AmountScale.title,
      weight: AppTypography.bold,
      color: invoice.isPayable ? scheme.onSurface : muted,
    );

    final Widget? pay = invoice.isPayable
        ? _PayButton(
            expand: stacked,
            onPressed: () => payInvoice(context, ref, invoice),
          )
        : null;

    // Once the statement is narrowed to one property the pill above it
    // already names it, and the same tag on every card only costs space.
    final showTag =
        ref.watch(selectedBillingPropertyProvider) == null &&
        PropertyTag.canShow(
          name: invoice.propertyName,
          unit: invoice.unitNumber,
        );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stacked) ...[
          number,
          Gap.h4,
          Align(alignment: Alignment.centerLeft, child: date),
        ] else
          Row(
            children: [
              Expanded(child: number),
              Gap.w8,
              Flexible(child: date),
            ],
          ),
        Gap.h8,
        if (stacked) ...[
          figure,
          if (pay != null) ...[Gap.h8, pay],
        ] else
          Row(
            children: [
              Expanded(child: figure),
              if (pay != null) ...[Gap.w12, pay],
            ],
          ),
        Gap.h8,
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusChip(label: label, tone: tone, dense: true),
            if (showTag)
              PropertyTag(
                name: invoice.propertyName,
                unit: invoice.unitNumber,
                maxLines: stacked ? 2 : 1,
                color: theme.brightness == Brightness.dark
                    ? AppPalette.violet300
                    : AppPalette.violet700,
              ),
          ],
        ),
      ],
    );

    // The rail's word says what the chip says; it is decoration for the eye,
    // so screen readers hear the status once and its size is held steady.
    const railWidth = 32.0;
    return GlassTap(
      scale: 0.98,
      onTap: () => context.pushNamed(
        Routes.invoiceDetail,
        pathParameters: {'invoiceId': invoice.id},
      ),
      child: FrostedPane(
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: railWidth,
              child: ExcludeSemantics(child: _Rail(label: label, color: color)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                railWidth + Gap.md,
                12,
                Gap.md,
                12,
              ),
              child: body,
            ),
          ],
        ),
      ),
    );
  }

  /// "Invoice #75158" when the server's number is bare digits; a number that
  /// already says what it is ("INV-2026-0042") is shown as it is.
  String get _number => RegExp(r'^\d+$').hasMatch(invoice.invoiceNumber)
      ? 'Invoice #${invoice.invoiceNumber}'
      : invoice.invoiceNumber;

  /// What the rail and chip say. An issued invoice is "Unpaid" to a tenant.
  (String, StatusTone) get _status {
    if (invoice.isDeferred) return ('Deferred', StatusTone.neutral);
    if (invoice.status == InvoiceStatus.issued) {
      return ('Unpaid', StatusTone.danger);
    }
    return (invoice.status.label, invoice.status.tone);
  }
}

/// The status down the card's left edge: a solid bar, a tinted band, and the
/// word turned to read bottom to top.
class _Rail extends StatelessWidget {
  const _Rail({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.16 : 0.09),
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: AppTypography.bold,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Pay now" as a lit green key, rimmed in white light so it reads as a
/// piece of the glass rather than a flat slab laid on it.
class _PayButton extends StatelessWidget {
  const _PayButton({required this.onPressed, this.expand = false});

  final VoidCallback onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    return GlassTap(
      onTap: onPressed,
      scale: 0.95,
      semanticLabel: 'Pay now',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(AppPalette.green700, AppPalette.green300, 0.28)!,
                AppPalette.green700,
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: AppPalette.green700.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'Pay now',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: AppTypography.semibold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
