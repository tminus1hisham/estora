import 'dart:ui' as ui;

import 'package:estora/components/app_brand_mark.dart';
import 'package:estora/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('brand has three navy units, a brass unit and open gaps', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: const AppBrandMark(size: 512),
          ),
        ),
      ),
    );
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage());
    final bytes = (await tester.runAsync(() => image!.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    )))!;
    Color pixel(int x, int y) {
      final offset = (y * image!.width + x) * 4;
      return Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
    }

    expect(pixel(167, 167), AppPalette.navy900);
    expect(pixel(345, 167), AppPalette.brass500);
    expect(pixel(167, 345), AppPalette.navy900);
    expect(pixel(345, 345), AppPalette.navy900);
    expect(pixel(256, 256), isNot(AppPalette.navy900));
    image!.dispose();
  });
}
