import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/glass_material.dart';
import '../../../../components/glass_tinted_capsule.dart';
import '../../../../components/glass_well.dart';
import '../../../../components/property_tag.dart';
import '../../../../components/surface_atoms.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/billing.dart';
import '../../../../domain/enums/domain_enums.dart';
import '../../../../navigation/routes.dart';
import '../../application/billing_property_filter.dart';
import 'pay_invoice.dart';

/// One invoice, as a compact pane of frosted glass.
///
/// Laid out the way a Wallet transaction row is: what it is down the left —
/// the number with its status, what it covers, and which shop it is for — and
/// what it costs down the right, the figure over its due date with "Pay now"
/// tucked under both. The statement and the home preview use this same card,
/// so an invoice half-remembered from home is recognisably the same object on
/// the invoices tab, down to where its "Pay now" sits.
///
/// It is kept short on purpose. A statement is a list; the earlier pass-style
/// card spent a band on its header, a perforation and a band on its fare, and
/// showed four invoices to a screen. Here the figure shares its lines with the
/// number and the period, and the only line of its own is the property tag,
/// which the button rides on the end of.
///
/// The property tag is there because a tenant can lease in more than one mall;
/// "Rent · Sep 2026" is ambiguous until it says whose rent.
///
/// Its meaning lights it rather than paints it: an overdue invoice is washed
/// faintly red from its corner and says "Overdue" in red under the figure; a
/// settled one is washed green; one due within the week, brass. Nothing is a
/// red slab. A statement with one late invoice in it should read as a
/// statement with something to see to, not as an alarm.
///
/// Nothing here is summed: the figure is the server's `amountDue` as supplied
/// (section 84 rule 7, section 65).
class InvoiceCard extends ConsumerWidget {
  const InvoiceCard({required this.invoice, super.key});

  final Invoice invoice;

  /// The glyph well: small enough to sit beside two lines of text rather than
  /// set the height of the card.
  static const double _well = 36;

  static final DateFormat _month = DateFormat('MMM');
  static final DateFormat _monthShort = DateFormat('MMM yyyy');
  static final DateFormat _dayMonth = DateFormat('d MMM');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statuses = context.statusColors;
    final stacked = prefersStacked(context);
    final (caption, captionColor) = _caption(context, short: !stacked);

    final status = _StatusMark(
      label: invoice.isDeferred ? 'Deferred' : invoice.status.label,
      color: statuses.resolve(
        invoice.isDeferred ? StatusTone.neutral : invoice.status.tone,
      ),
    );

    final number = Text(
      invoice.invoiceNumber,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: AppTypography.semibold,
        letterSpacing: -0.2,
      ),
    );

    final subtitle = Text(
      _subtitle(short: !stacked),
      maxLines: stacked ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        height: 1.35,
      ),
    );

    // Once the statement is narrowed to one property the pill above it
    // already names it, and the same tag on every card only costs a line.
    final showTag =
        ref.watch(selectedBillingPropertyProvider) == null &&
        PropertyTag.canShow(
          name: invoice.propertyName,
          unit: invoice.unitNumber,
        );
    final tag = PropertyTag(
      name: invoice.propertyName,
      unit: invoice.unitNumber,
      maxLines: stacked ? 2 : 1,
    );

    final well = GlassWell(
      icon: _icon,
      color: statuses.resolve(_meaning),
      size: _well,
      iconSize: 18,
    );

    // A settled invoice is a record now, not a demand; its figure steps back
    // so the ones still owed lead the eye.
    final figure = AmountText(
      invoice.isPayable ? invoice.amountDue : invoice.total,
      scale: AmountScale.title,
      align: stacked ? TextAlign.start : TextAlign.end,
      color: invoice.isPayable ? scheme.onSurface : scheme.onSurfaceVariant,
    );

    // Quiet on every card, urgent or not. A lit capsule down a statement is
    // a wall of buttons, and the tenant was told the button shouted; how
    // late an invoice is already shows in its caption and the wash on its
    // pane, so the action does not need to say it a third time.
    final Widget? payButton = invoice.isPayable
        ? GlassTintedCapsule(
            label: 'Pay now',
            expand: stacked,
            onPressed: () => payInvoice(context, ref, invoice),
          )
        : null;

    final Widget body;
    final EdgeInsets padding;
    if (stacked) {
      body = _stackedBody(
        context,
        well: well,
        number: number,
        status: status,
        subtitle: subtitle,
        tag: showTag ? tag : null,
        figure: figure,
        caption: caption,
        captionColor: captionColor,
        payButton: payButton,
      );
      padding = const EdgeInsets.all(Gap.lg);
    } else {
      // The line under the figure is the card's one statement of where the
      // invoice stands. A status word beside the number said "Overdue" a
      // second time under the figure, and on a phone "Partially paid" could
      // not fit beside the number at all, so the status is folded in here:
      // the most pressing fact wins, and a part-paid invoice says so ahead
      // of its date because the figure above it is a balance, not the bill.
      final prefix = _captionPrefix;
      final faint = scheme.onSurfaceVariant.withValues(alpha: 0.6);
      final captionText = Semantics(
        label: 'Status: ${status.label}. $caption',
        container: true,
        excludeSemantics: true,
        child: Text.rich(
          TextSpan(
            children: [
              if (prefix != null) ...[
                TextSpan(
                  text: prefix,
                  style: TextStyle(color: statuses.warning),
                ),
                TextSpan(
                  text: ' · ',
                  style: TextStyle(color: faint),
                ),
              ],
              // Mid-line, the date reads as a clause: "Part paid · due 4 Oct".
              TextSpan(
                text: prefix == null
                    ? caption
                    : caption.replaceFirst('Due', 'due'),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: theme.textTheme.bodySmall?.copyWith(
            color: captionColor,
            height: 1.35,
            fontWeight: AppTypography.medium,
          ),
        ),
      );

      // The figure takes the width it needs, up to a little over half the
      // line; past that the caption ellipsises and the figure scales down,
      // so the invoice number is never the one cut short.
      final top = LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [number, const SizedBox(height: 2), subtitle],
              ),
            ),
            Gap.w12,
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 0.56,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [figure, const SizedBox(height: 2), captionText],
              ),
            ),
          ],
        ),
      );

      // The tag and the button share the last line: the tag reads from the
      // left edge of the text, the button sits under the figure it pays.
      final Widget? foot = switch ((showTag, payButton)) {
        (false, null) => null,
        (true, null) => Align(alignment: Alignment.centerLeft, child: tag),
        (_, final Widget pay) => Row(
          children: [
            Expanded(
              child: showTag
                  ? Align(alignment: Alignment.centerLeft, child: tag)
                  : const SizedBox.shrink(),
            ),
            Gap.w8,
            pay,
          ],
        ),
      };

      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          well,
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                top,
                if (foot != null) ...[
                  // The button's own 44pt target carries clear space above
                  // and below the capsule, so the line it sits on needs
                  // barely any gap of its own.
                  SizedBox(height: payButton == null ? Gap.sm : 0),
                  foot,
                ],
              ],
            ),
          ),
        ],
      );
      padding = EdgeInsets.fromLTRB(
        14,
        Gap.md,
        14,
        // Likewise below: the target's margin is the rest of the padding.
        payButton == null ? Gap.md : Gap.xs,
      );
    }

    return GlassTap(
      scale: 0.98,
      onTap: () => context.pushNamed(
        Routes.invoiceDetail,
        pathParameters: {'invoiceId': invoice.id},
      ),
      child: FrostedPane(tone: _wash(statuses), padding: padding, child: body),
    );
  }

  /// The large-text layout: everything in one column, the figure under the
  /// words at full width and "Pay now" across the card, so nothing has to
  /// share a line it no longer fits on.
  Widget _stackedBody(
    BuildContext context, {
    required Widget well,
    required Widget number,
    required Widget status,
    required Widget subtitle,
    required Widget? tag,
    required Widget figure,
    required String caption,
    required Color captionColor,
    required Widget? payButton,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final header = Row(
      // Beside a tall title block the glyph belongs at the top, with the
      // number, not floating at the middle of it.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        well,
        Gap.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              number,
              Gap.h4,
              status,
              Gap.h4,
              subtitle,
              if (tag != null) ...[Gap.h8, tag],
            ],
          ),
        ),
      ],
    );

    // The label and the due date share one line above the figure: both are
    // small print about the same number.
    final label = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: invoice.isPayable ? 'Amount due' : 'Invoice total',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          TextSpan(
            text: ' · ',
            style: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          TextSpan(
            text: caption,
            style: TextStyle(
              color: captionColor,
              fontWeight: AppTypography.semibold,
            ),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        Gap.h12,
        label,
        Gap.h4,
        figure,
        if (payButton != null) ...[Gap.h12, payButton],
      ],
    );
  }

  /// "Part paid", ahead of the date under the figure, while that is the most
  /// useful thing to add: not once the invoice is late or due this week,
  /// where the urgency outranks it and the line has no room for both.
  String? get _captionPrefix {
    if (invoice.status != InvoiceStatus.partiallyPaid) return null;
    if (invoice.isDeferred || invoice.isOverdue || invoice.isDueSoon) {
      return null;
    }
    return 'Part paid';
  }

  /// What the card is lit with, if anything: only the states a tenant has to
  /// notice. An invoice with weeks to run is plain glass.
  Color? _wash(StatusColors statuses) {
    if (invoice.isDeferred) return null;
    if (invoice.isOverdue) return statuses.danger;
    if (invoice.status == InvoiceStatus.paid) return statuses.positive;
    if (invoice.isDueSoon) return statuses.warning;
    return null;
  }

  /// The well's hue: the invoice's state, with "due this week" counted as a
  /// state of its own so the glyph agrees with the brass wash around it.
  StatusTone get _meaning {
    if (invoice.isDeferred) return StatusTone.neutral;
    if (invoice.status == InvoiceStatus.issued && invoice.isDueSoon) {
      return StatusTone.warning;
    }
    return invoice.status.tone;
  }

  /// What the invoice is for. The status already has its words and colour;
  /// the glyph says "rent" or "power" at a glance down a long statement.
  IconData get _icon {
    if (invoice.status == InvoiceStatus.cancelled ||
        invoice.status == InvoiceStatus.invoiceVoid) {
      return Icons.block_rounded;
    }
    final line = invoice.lines.isEmpty ? null : invoice.lines.first.lineType;
    return switch (line) {
      InvoiceLineType.rent => Icons.storefront_rounded,
      InvoiceLineType.deposit => Icons.savings_rounded,
      InvoiceLineType.bookingFee => Icons.event_available_rounded,
      InvoiceLineType.serviceCharge => Icons.cleaning_services_rounded,
      InvoiceLineType.electricity => Icons.bolt_rounded,
      InvoiceLineType.water => Icons.water_drop_rounded,
      InvoiceLineType.internet => Icons.wifi_rounded,
      InvoiceLineType.parking => Icons.local_parking_rounded,
      InvoiceLineType.maintenance => Icons.handyman_rounded,
      InvoiceLineType.utility => Icons.electrical_services_rounded,
      InvoiceLineType.penalty || InvoiceLineType.lateFee => Icons.gavel_rounded,
      _ => Icons.receipt_long_rounded,
    };
  }

  /// What the invoice covers, in one line. The unit is on the property tag
  /// now, so it is not repeated here; the month is abbreviated beside the
  /// figure, where the line is shared, and spelled out when it has the width
  /// (see [_period]).
  String _subtitle({required bool short}) {
    final parts = <String>[
      if (invoice.lines.isNotEmpty) invoice.lines.first.lineType.label,
      if (invoice.hasBillingPeriod)
        short
            ? _period(invoice.billingPeriodStart!.toLocal())
            : AppDate.monthYear(invoice.billingPeriodStart!),
    ];
    return parts.isEmpty
        ? 'Issued ${AppDate.short(invoice.invoiceDate)}'
        : parts.join(' · ');
  }

  /// The billing month beside the figure: "Sep" while it is this year's, the
  /// way the due date drops its year — the line is shared with the figure,
  /// and "Service charge · Sep 2…" cut short on a narrow phone said less than
  /// "Service charge · Sep" does.
  static String _period(DateTime month) => month.year == DateTime.now().year
      ? _month.format(month)
      : _monthShort.format(month);

  /// The line under the figure: when it falls due, or where it ended up.
  ///
  /// Under the figure the date drops its year while it is this year's — the
  /// month heading above the card already says which year the statement is
  /// in.
  (String, Color) _caption(BuildContext context, {required bool short}) {
    final scheme = Theme.of(context).colorScheme;
    final statuses = context.statusColors;

    String date(DateTime value) =>
        short && value.toLocal().year == DateTime.now().year
        ? _dayMonth.format(value.toLocal())
        : AppDate.short(value);

    if (invoice.isDeferred) return ('Deferred', scheme.onSurfaceVariant);
    if (invoice.isOverdue) return ('Overdue', statuses.danger);
    if (!invoice.isPayable) {
      // In the stacked layout the status has its own mark under the number,
      // so this line can say when; beside the figure it is the only place
      // the status is said.
      if (!short) {
        return ('Issued ${date(invoice.invoiceDate)}', scheme.onSurfaceVariant);
      }
      return (
        invoice.status.label,
        invoice.status == InvoiceStatus.paid
            ? statuses.positive
            : scheme.onSurfaceVariant,
      );
    }

    final days = invoice.daysUntilDue;
    if (days == 0) return ('Due today', statuses.warning);
    if (days == 1) return ('Due tomorrow', statuses.warning);
    if (days > 1 && days <= 7) return ('Due in $days days', statuses.warning);
    return ('Due ${date(invoice.dueDate)}', scheme.onSurface);
  }
}

/// The invoice's status as a dot of its colour and its name — no capsule.
///
/// Only in the stacked, large-text layout, where the number has a line to
/// itself and the status can sit under it. Beside the figure the caption says
/// it instead (see [InvoiceCard]). Quieter than a badge on purpose: the card
/// is already washed in the same colour, and a filled, bordered chip said the
/// same thing again, louder.
class _StatusMark extends StatelessWidget {
  const _StatusMark({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: $label',
      container: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const SizedBox.square(dimension: 6),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                height: 1.25,
                fontWeight: AppTypography.semibold,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
