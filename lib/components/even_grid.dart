import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/theme/app_theme.dart';

/// A responsive grid whose cards are all exactly the same size.
///
/// A [Wrap] gives every card the same width but lets each keep its own height,
/// so a run ends in a ragged line as soon as one card carries an extra line of
/// detail, a meter or a longer figure. [IntrinsicHeight] over a [Row] squares
/// up one row at a time, which leaves a step between the rows instead. This
/// measures every card at the slot width it is about to be given, takes the
/// tallest, and hands that height to all of them — so the grid reads as one
/// block whatever the cards happen to contain.
///
/// Nothing is pinned to a hard-coded height: the measurement is of the real
/// content, so larger platform text makes every card taller rather than
/// clipping one of them, and past the point where a column would be too narrow
/// to read, the grid drops one. The column count comes from [minTileWidth],
/// grown by the text scale for the same reason.
///
/// A short last row keeps the slot width of the rows above it — the spare slots
/// are left empty rather than shared out, which is what keeps three cards in a
/// two-column grid looking like a grid.
///
/// Because the grid measures its children, a card placed in it must not build
/// its own [LayoutBuilder]: that widget cannot report an intrinsic height and
/// will assert.
class EvenGrid extends StatelessWidget {
  const EvenGrid({
    required this.children,
    this.minTileWidth = 260,
    this.spacing = Gap.md,
    this.runSpacing,
    this.maxColumns = 4,
    super.key,
  });

  final List<Widget> children;

  /// The narrowest a card may be before the grid drops a column.
  final double minTileWidth;

  /// Between columns, and between rows unless [runSpacing] says otherwise.
  final double spacing;
  final double? runSpacing;

  /// The grid never grows past this, however wide the window gets.
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final gapBetweenRows = runSpacing ?? spacing;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(context, constraints);

        // Stacked, which is what a narrow phone or very large text comes to.
        // Cards in a single column already agree on their width, and giving
        // them a shared height would only pad the short ones out with nothing.
        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) SizedBox(height: gapBetweenRows),
                child,
              ],
            ],
          );
        }

        return _EvenGridLayout(
          columns: columns,
          spacing: spacing,
          runSpacing: gapBetweenRows,
          children: children,
        );
      },
    );
  }

  int _columnsFor(BuildContext context, BoxConstraints constraints) {
    // An unbounded width has no column count to derive; one per row is the
    // only answer that cannot overflow.
    if (!constraints.hasBoundedWidth) return 1;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final tile = minTileWidth * scale;
    final fits = ((constraints.maxWidth + spacing) / (tile + spacing)).floor();
    return fits.clamp(1, maxColumns.clamp(1, children.length));
  }
}

class _EvenGridLayout extends MultiChildRenderObjectWidget {
  const _EvenGridLayout({
    required this.columns,
    required this.spacing,
    required this.runSpacing,
    required super.children,
  });

  final int columns;
  final double spacing;
  final double runSpacing;

  @override
  RenderEvenGrid createRenderObject(BuildContext context) =>
      RenderEvenGrid(columns: columns, spacing: spacing, runSpacing: runSpacing);

  @override
  void updateRenderObject(BuildContext context, RenderEvenGrid renderObject) {
    renderObject
      ..columns = columns
      ..spacing = spacing
      ..runSpacing = runSpacing;
  }
}

class _EvenGridParentData extends ContainerBoxParentData<RenderBox> {}

/// Lays [EvenGrid]'s children out on a fixed number of columns, every cell the
/// same size.
///
/// The size is measured rather than declared: each child is asked how tall it
/// would be at the slot width, and the tallest answer becomes every cell's
/// height. That is the one thing a [GridView] cannot do — its cells take the
/// aspect ratio they are handed, which is how a grid ends up clipping its own
/// captions the moment someone turns their text size up.
class RenderEvenGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EvenGridParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EvenGridParentData> {
  RenderEvenGrid({
    required int columns,
    required double spacing,
    required double runSpacing,
  }) : _columns = columns,
       _spacing = spacing,
       _runSpacing = runSpacing;

  int _columns;
  int get columns => _columns;
  set columns(int value) {
    if (_columns == value) return;
    _columns = value;
    markNeedsLayout();
  }

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double _runSpacing;
  double get runSpacing => _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing == value) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _EvenGridParentData) {
      child.parentData = _EvenGridParentData();
    }
  }

  int get _rowCount => (childCount + columns - 1) ~/ columns;

  double _slotWidth(double width) =>
      math.max(0, (width - (columns - 1) * spacing) / columns);

  /// The tallest any child wants to be at [slot] wide, and therefore the height
  /// every one of them is given.
  double _cellHeight(double slot) {
    var tallest = 0.0;
    var child = firstChild;
    while (child != null) {
      tallest = math.max(tallest, child.getMaxIntrinsicHeight(slot));
      child = (child.parentData! as _EvenGridParentData).nextSibling;
    }
    return tallest;
  }

  double _heightFor(double width) {
    if (childCount == 0) return 0;
    final rows = _rowCount;
    return rows * _cellHeight(_slotWidth(width)) + (rows - 1) * runSpacing;
  }

  double _widestChild(double Function(RenderBox child) measure) {
    var widest = 0.0;
    var child = firstChild;
    while (child != null) {
      widest = math.max(widest, measure(child));
      child = (child.parentData! as _EvenGridParentData).nextSibling;
    }
    return widest;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _widestChild((child) => child.getMinIntrinsicWidth(double.infinity)) *
          columns +
      (columns - 1) * spacing;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _widestChild((child) => child.getMaxIntrinsicWidth(double.infinity)) *
          columns +
      (columns - 1) * spacing;

  @override
  double computeMinIntrinsicHeight(double width) => _heightFor(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _heightFor(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : computeMaxIntrinsicWidth(double.infinity);
    return constraints.constrain(Size(width, _heightFor(width)));
  }

  @override
  void performLayout() {
    if (childCount == 0) {
      size = constraints.smallest;
      return;
    }

    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : computeMaxIntrinsicWidth(double.infinity);
    final slot = _slotWidth(width);
    final cell = _cellHeight(slot);
    final cellConstraints = BoxConstraints.tightFor(width: slot, height: cell);

    var index = 0;
    var child = firstChild;
    while (child != null) {
      child.layout(cellConstraints);
      final parentData = child.parentData! as _EvenGridParentData;
      parentData.offset = Offset(
        (index % columns) * (slot + spacing),
        (index ~/ columns) * (cell + runSpacing),
      );
      child = parentData.nextSibling;
      index++;
    }

    final rows = _rowCount;
    size = constraints.constrain(
      Size(width, rows * cell + (rows - 1) * runSpacing),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
