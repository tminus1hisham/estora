import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/components/even_grid.dart';

/// Cards of deliberately different content heights: one line against four.
Widget _card(String label, int lines) => Card(
  margin: EdgeInsets.zero,
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Text(List.filled(lines, label).join('\n')),
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required List<Widget> children,
  double minTileWidth = 150,
  double textScale = 1,
}) async {
  // The grid reads the width it is given, so the window has to be at least as
  // wide as the box under test or the box is the one that gets clamped.
  await tester.binding.setSurfaceSize(Size(width + 80, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: EvenGrid(minTileWidth: minTileWidth, children: children),
            ),
          ),
        ),
      ),
    ),
  );
}

Iterable<Size> _cardSizes(WidgetTester tester) =>
    tester.widgetList<Card>(find.byType(Card)).map((card) {
      final element = tester.element(find.byWidget(card));
      return (element.renderObject! as RenderBox).size;
    });

void main() {
  testWidgets('cards on a row share one size however tall their content', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 600,
      children: [_card('one', 1), _card('four', 4)],
    );

    final sizes = _cardSizes(tester).toList();
    expect(sizes, hasLength(2));
    expect(sizes.first, sizes.last);
  });

  testWidgets('a short last row keeps the slot width of the rows above it', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 600,
      children: [
        _card('a', 1),
        _card('b', 3),
        _card('c', 1),
      ],
    );

    final sizes = _cardSizes(tester).toList();
    expect(sizes, hasLength(3));
    // Four columns fit at 600 wide, so this is really one row; the point is
    // that no card is given the leftover width of an empty slot.
    for (final size in sizes) {
      expect(size.width, sizes.first.width);
    }
  });

  testWidgets('the column count follows the width', (tester) async {
    final children = [
      _card('a', 1),
      _card('b', 1),
      _card('c', 1),
      _card('d', 1),
    ];

    await _pump(tester, width: 340, children: children);
    final narrow = _cardSizes(tester).first.width;

    await _pump(tester, width: 900, children: children);
    final wide = _cardSizes(tester).first.width;

    // Two up on a phone, four across a window, so each card is narrower there
    // even though the window is wider.
    expect(narrow, closeTo((340 - 12) / 2, 0.01));
    expect(wide, closeTo((900 - 36) / 4, 0.01));
  });

  testWidgets('larger text widens the slots rather than dropping a column '
      'onto the cards', (tester) async {
    final children = [_card('a', 1), _card('b', 1)];

    await _pump(tester, width: 340, children: children);
    expect(_cardSizes(tester).first.width, lessThan(340));

    await _pump(tester, width: 340, children: children, textScale: 2);
    // One per row once the text has doubled: a full-width card is the only
    // one that still fits the label.
    expect(_cardSizes(tester).first.width, 340);
  });

  testWidgets('every card in the grid is the same size, rows included', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 340,
      children: [
        _card('a', 1),
        _card('b', 4),
        _card('c', 1),
        _card('d', 2),
      ],
    );

    final sizes = _cardSizes(tester).toList();
    expect(sizes, hasLength(4));
    // Two rows of two. The tallest card sets the height for all of them, so
    // the second row does not step up against the first.
    for (final size in sizes) {
      expect(size, sizes.first);
    }
  });

  testWidgets('the grid is exactly as tall as its rows and their gap', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 340,
      children: [_card('a', 1), _card('b', 4), _card('c', 1)],
    );

    final cell = _cardSizes(tester).first.height;
    final grid = tester.getSize(find.byType(EvenGrid));
    // Two rows: the second holds one card and one empty slot.
    expect(grid.height, closeTo(cell * 2 + 12, 0.01));
    expect(grid.width, 340);
  });

  testWidgets('a single card is not asked to share a row', (tester) async {
    await _pump(tester, width: 600, children: [_card('only', 1)]);
    expect(_cardSizes(tester).single.width, 600);
  });
}
