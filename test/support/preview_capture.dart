import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders widgets to PNG so a design change can be looked at, not guessed at.
///
/// Only runs under `--dart-define=PREVIEWS=true`; without it the capture is a
/// no-op, so a preview test still passes (and still checks layout) in CI.
const bool kPreviews = bool.fromEnvironment('PREVIEWS');

/// Where captures land. Override with `--dart-define=PREVIEW_DIR=...`.
const String kPreviewDir = String.fromEnvironment(
  'PREVIEW_DIR',
  defaultValue: 'build/previews',
);

/// Loads the app's real fonts, so a capture shows Manrope and real icons
/// rather than the test font's boxes.
Future<void> loadPreviewFonts() async {
  await (FontLoader(
    'Manrope',
  )..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf'))).load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}

/// Sets a phone-sized logical viewport.
void usePhoneViewport(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  addTearDown(tester.view.reset);
  // flutter_test draws shadows as hard shapes, and decorations cache their
  // shadow paint on first paint, so real shadows have to be on before the
  // first pump. [capturePreview] turns the flag back, which the framework
  // requires before the test ends — so under PREVIEWS every test that calls
  // this must end with a capture.
  if (kPreviews) debugDisableShadows = false;
}

/// Captures the [RepaintBoundary] under [key] to `$kPreviewDir/$name.png`.
Future<void> capturePreview(WidgetTester tester, Key key, String name) async {
  if (!kPreviews) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(kPreviewDir).create(recursive: true);
    await File(
      '$kPreviewDir/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
  debugDisableShadows = true;
}
