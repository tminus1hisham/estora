import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../core/theme/app_theme.dart';
import '../core/theme/status_palette.dart';
import '../core/utils/money.dart';
import '../domain/entities/owner.dart';
import 'amount_text.dart';

/// Collected against billed, one column per span of time.
///
/// The app's only chart, and it stays a chart rather than becoming a charting
/// library: two faint rules for scale, a baseline, ticks where the server put
/// them, and no legend chrome. Where a column covers a billing period the
/// faint bar is what was invoiced and the solid one what actually arrived;
/// the gap between them is the whole message. Where it does not — an hour, a
/// day — only the solid bar is drawn, because "billed by the hour" would be a
/// figure without a meaning.
///
/// Touching a column reads it out above the chart: the span in words and the
/// figure, the other columns stepping back a little so the eye lands on the
/// one under the finger. A drag scrubs across them. Nothing here is summed —
/// every figure shown is one the server sent for that column.
///
/// The solid bar can be **taller** than the faint one. That is not a bug and is
/// not clamped: a deposit invoiced in one month and paid in the next collects
/// more than that month billed, and flattening it would hide exactly the kind
/// of timing an owner is looking for.
class CollectionColumns extends StatefulWidget {
  const CollectionColumns({
    required this.points,
    this.height = 132,
    this.ink,
    this.readout = true,
    super.key,
  });

  /// The six-month history the ledger and portfolio already carry.
  CollectionColumns.monthly({
    required List<MonthlyCollection> months,
    double height = 132,
    Color? ink,
    bool readout = true,
    Key? key,
  }) : this(
         points: [for (final month in months) CollectionPoint.month(month)],
         height: height,
         ink: ink,
         readout: readout,
         key: key,
       );

  final List<CollectionPoint> points;

  /// The plotting area, excluding the readout above and the ticks beneath.
  final double height;

  /// The colour of the rules, ticks and billed bars. Defaults to the theme's
  /// `onSurfaceVariant`; a chart on a dark brand card passes its own.
  final Color? ink;

  /// Whether the selected column is read out above the chart.
  final bool readout;

  @override
  State<CollectionColumns> createState() => _CollectionColumnsState();
}

class _CollectionColumnsState extends State<CollectionColumns> {
  /// The column under the finger; null until one is touched, and again once
  /// the same column is tapped a second time.
  int? _selected;

  /// Room on the right for the figures beside the rules.
  static const _gutter = _Rules.gutter;

  @override
  void didUpdateWidget(CollectionColumns old) {
    super.didUpdateWidget(old);
    // A new series is a new set of columns; a selection from the old one
    // would point at the wrong span, or past the end.
    if (old.points != widget.points) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = widget.ink ?? scheme.onSurfaceVariant;
    final fill = context.statusColors.resolve(StatusTone.positive);

    // Scaled to the largest figure in the series, billed or collected, and
    // then rounded up to a figure that reads well on the top rule, so no bar
    // can run past the top of its column.
    var tallest = 0;
    for (final point in points) {
      tallest = math.max(tallest, point.collected.minorUnits);
      final billed = point.billed;
      if (billed != null) tallest = math.max(tallest, billed.minorUnits);
    }
    if (tallest == 0) return const SizedBox.shrink();
    final ceiling = _niceCeiling(tallest);
    final currency = points.first.collected.currency;

    final settled = MediaQuery.disableAnimationsOf(context);
    final selected = _selected == null
        ? null
        : points[_selected!.clamp(0, points.length - 1)];
    final hasBilled = points.any((point) => point.billed != null);

    return Semantics(
      label: _semanticsLabel,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.readout) ...[
            _Readout(
              point: selected,
              ink: ink,
              fill: fill,
              billed: hasBilled,
              figure: widget.ink,
            ),
            Gap.h12,
          ],
          TweenAnimationBuilder<double>(
            tween: Tween(begin: settled ? 1 : 0, end: 1),
            duration: settled ? Duration.zero : AppMotion.slow,
            curve: AppMotion.emphasized,
            builder: (context, t, _) => LayoutBuilder(
              builder: (context, constraints) {
                // The plot stops short of the right edge, where the rule
                // figures sit.
                final width = constraints.maxWidth - _gutter;
                final column = width / points.length;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) =>
                      _select(d.localPosition.dx, column, toggle: true),
                  onHorizontalDragStart: (d) =>
                      _select(d.localPosition.dx, column),
                  onHorizontalDragUpdate: (d) =>
                      _select(d.localPosition.dx, column),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: widget.height,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              painter: _Rules(
                                ink: ink,
                                ceiling: Money(ceiling, currency),
                                textStyle: theme.textTheme.labelSmall,
                              ),
                            ),
                            Padding(
                              // Room for the rule figures on the right.
                              padding: const EdgeInsets.only(right: _gutter),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  for (final (i, point) in points.indexed)
                                    Expanded(
                                      child: _Bar(
                                        billed: point.billed == null
                                            ? null
                                            : point.billed!.minorUnits /
                                                  ceiling *
                                                  t,
                                        collected:
                                            point.collected.minorUnits /
                                            ceiling *
                                            t,
                                        ink: ink,
                                        fill: fill,
                                        // Every column steps back a little
                                        // except the one being read.
                                        emphasis: _selected == null
                                            ? 1
                                            : i == _selected
                                            ? 1
                                            : 0.45,
                                        gap: (column * 0.16).clamp(1.0, 5.0),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Gap.h8,
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _Ticks(
                          points: points,
                          width: width,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: ink.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _select(double dx, double column, {bool toggle = false}) {
    final index = (dx / column).floor().clamp(0, widget.points.length - 1);
    if (index == _selected) {
      if (toggle) setState(() => _selected = null);
      return;
    }
    setState(() => _selected = index);
  }

  /// The chart as one sentence, since the bars themselves say nothing to a
  /// screen reader.
  String get _semanticsLabel {
    final parts = widget.points.map((point) {
      final billed = point.billed;
      return billed == null
          ? '${point.name}: ${point.collected.format()} collected'
          : '${point.name}: ${point.collected.format()} collected of '
                '${billed.format()}';
    });
    return 'Collection over ${widget.points.length} periods. '
        '${parts.join('. ')}';
  }

  /// The smallest of 1, 2, 2.5 or 5 × 10ⁿ at or above [minorUnits].
  ///
  /// Chart scaling, not money: the figure only ever labels the top rule.
  static int _niceCeiling(int minorUnits) {
    final magnitude = math.pow(10, (math.log(minorUnits) / math.ln10).floor());
    final fraction = minorUnits / magnitude;
    final nice = fraction <= 1
        ? 1
        : fraction <= 2
        ? 2
        : fraction <= 2.5
        ? 2.5
        : fraction <= 5
        ? 5
        : 10;
    return (nice * magnitude).round();
  }
}

/// What the bars mean until one is touched, then the touched one in words
/// and figures.
class _Readout extends StatelessWidget {
  const _Readout({
    required this.point,
    required this.ink,
    required this.fill,
    required this.billed,
    this.figure,
  });

  /// The column being read, or null for the legend.
  final CollectionPoint? point;
  final Color ink;
  final Color fill;

  /// Whether any column carries a billed figure, so the legend says so.
  final bool billed;

  /// The figure's colour where the chart sits on something other than a
  /// surface; null takes the theme's.
  final Color? figure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final point = this.point;

    return AnimatedSwitcher(
      duration: AppMotion.fast,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, ?current],
      ),
      child: point == null ? _legend(theme) : _column(theme, point),
    );
  }

  Widget _legend(ThemeData theme) {
    final style = theme.textTheme.labelSmall?.copyWith(
      color: ink.withValues(alpha: 0.85),
    );
    Widget item(Color swatch, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Swatch(color: swatch),
        Gap.w4,
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );

    return Row(
      key: const ValueKey('legend'),
      children: [
        // Wrapped so the two keys stack rather than overflow at large text
        // sizes on a narrow phone, and given the larger share of the row:
        // the keys are information, the hint is only a hint.
        Flexible(
          flex: 3,
          child: Wrap(
            spacing: Gap.md,
            runSpacing: Gap.xs,
            children: [
              item(fill, 'Collected'),
              if (billed) item(ink.withValues(alpha: 0.18), 'Billed'),
            ],
          ),
        ),
        Gap.w12,
        Flexible(
          flex: 2,
          child: Text(
            'Touch a column',
            maxLines: 1,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: style?.copyWith(color: ink.withValues(alpha: 0.6)),
          ),
        ),
      ],
    );
  }

  Widget _column(ThemeData theme, CollectionPoint point) {
    final billed = point.billed;
    return Row(
      key: ValueKey(point.at),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                point.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: ink,
                  fontWeight: AppTypography.semibold,
                ),
              ),
              if (billed != null)
                Text(
                  'of ${billed.format()} billed',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: ink.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
        ),
        Gap.w12,
        // Bounded, so the figure scales down at large text sizes instead of
        // running off the card.
        Flexible(
          child: AmountText(
            point.collected,
            scale: AmountScale.title,
            color: figure,
            align: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.all(Radius.circular(3)),
    ),
  );
}

/// A baseline and two faint rules, with the figure each rule stands for.
class _Rules extends CustomPainter {
  const _Rules({
    required this.ink,
    required this.ceiling,
    required this.textStyle,
  });

  final Color ink;
  final Money ceiling;
  final TextStyle? textStyle;

  static const double gutter = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = size.width - gutter;
    final baseline = Paint()
      ..color = ink.withValues(alpha: 0.32)
      ..strokeWidth = 1;
    final faint = Paint()
      ..color = ink.withValues(alpha: 0.14)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(plot, size.height - 0.5),
      baseline,
    );

    for (final fraction in const [1.0, 0.5]) {
      final y = size.height * (1 - fraction) + 0.5;
      _dashed(canvas, Offset(0, y), Offset(plot, y), faint);

      final text = TextPainter(
        text: TextSpan(
          text: _compact(ceiling.majorUnits * fraction),
          style: textStyle?.copyWith(
            color: ink.withValues(alpha: 0.7),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: gutter);
      text.paint(canvas, Offset(size.width - text.width, y - text.height / 2));
    }
  }

  static void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 3.0;
    const space = 4.0;
    var x = a.dx;
    while (x < b.dx) {
      canvas.drawLine(
        Offset(x, a.dy),
        Offset(math.min(x + dash, b.dx), a.dy),
        paint,
      );
      x += dash + space;
    }
  }

  static String _compact(double major) => NumberFormat.compact().format(major);

  @override
  bool shouldRepaint(_Rules old) =>
      old.ink != ink || old.ceiling != ceiling || old.textStyle != textStyle;
}

/// The ticks beneath the columns, each centred on its column.
///
/// Positioned rather than laid out as one cell per column: a day drawn by the
/// hour has twenty-four columns and four ticks, and a tick wider than its
/// column has to be allowed to spill over the unlabelled ones beside it. The
/// first and last hug their edges so nothing runs off the chart.
class _Ticks extends StatelessWidget {
  const _Ticks({required this.points, required this.width, this.style});

  final List<CollectionPoint> points;
  final double width;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final column = width / points.length;
    final lineHeight = (style?.fontSize ?? 11) * (style?.height ?? 1.45);

    return SizedBox(
      width: width,
      height: lineHeight * MediaQuery.textScalerOf(context).scale(1),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (i, point) in points.indexed)
            if (point.label.isNotEmpty) _tick(i, point.label, column),
        ],
      ),
    );
  }

  /// Centred on its column unless that would run past an edge, in which
  /// case it hugs the edge instead.
  Widget _tick(int index, String label, double column) {
    const reach = 64.0;
    final centred = column * (index + 0.5) - reach / 2;
    final (left, align) = centred < 0
        ? (0.0, TextAlign.start)
        : centred + reach > width
        ? (width - reach, TextAlign.end)
        : (centred, TextAlign.center);
    return Positioned(
      left: left,
      width: reach,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.visible,
        softWrap: false,
        textAlign: align,
        style: style,
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.billed,
    required this.collected,
    required this.ink,
    required this.fill,
    required this.emphasis,
    required this.gap,
  });

  /// Fractions of the plotting height, already animated. [billed] is null
  /// where the column is not a billing period.
  final double? billed;
  final double collected;

  final Color ink;
  final Color fill;

  /// 1 for the column being read, less for the rest.
  final double emphasis;

  /// Breathing room either side of the column.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final billed = this.billed;
    const top = BorderRadius.vertical(top: Radius.circular(4));

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gap),
      child: AnimatedOpacity(
        opacity: emphasis,
        duration: AppMotion.fast,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Billed: the full width of the column, faint.
            if (billed != null)
              FractionallySizedBox(
                heightFactor: billed.clamp(0.0, 1.0),
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: 0.18),
                    borderRadius: top,
                  ),
                ),
              ),
            // Collected: solid, and narrower where it shares the column so
            // both stay readable where they nearly coincide.
            FractionallySizedBox(
              heightFactor: collected.clamp(0.0, 1.0),
              widthFactor: billed == null ? 1 : 0.56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [fill.withValues(alpha: 0.7), fill],
                  ),
                  borderRadius: top,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
