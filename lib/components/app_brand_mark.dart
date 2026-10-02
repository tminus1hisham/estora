import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// The Estora brand mark, drawn in code so it stays crisp at every
/// display density and does not delay first paint.
///
/// Four rounded units on warm stone, with the upper-right unit in brass.
/// The artwork stays the same in light and dark themes.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({
    this.size = 56,
    this.withShadow = false,
    this.semanticLabel = 'Estora',
    super.key,
  });

  final double size;
  final bool withShadow;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              size * _BrandMarkPainter.radiusRatio,
            ),
            boxShadow: withShadow
                ? AppElevation.soft(Colors.black)
                : const <BoxShadow>[],
          ),
          child: CustomPaint(painter: const _BrandMarkPainter()),
        ),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter();

  static const _artboard = 512.0;

  /// 112 / 512 — the corner radius the platform launcher masks assume.
  static const radiusRatio = 0.21875;

  @override
  void paint(Canvas canvas, Size size) {
    const artboardRect = Rect.fromLTWH(0, 0, _artboard, _artboard);
    canvas
      ..save()
      ..scale(size.width / _artboard, size.height / _artboard);

    const tileRadius = Radius.circular(_artboard * radiusRatio);
    final tile = RRect.fromRectAndRadius(artboardRect, tileRadius);
    canvas.drawRRect(
      tile,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppPalette.stone0, AppPalette.stone50, AppPalette.stone100],
          stops: [0, 0.55, 1],
        ).createShader(artboardRect),
    );

    for (final origin in const [
      Offset(84, 84),
      Offset(262, 84),
      Offset(84, 262),
      Offset(262, 262),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(origin.dx, origin.dy, 166, 166),
          const Radius.circular(42),
        ),
        Paint()
          ..color = origin == const Offset(262, 84)
              ? AppPalette.brass500
              : AppPalette.navy900,
      );
    }
    canvas
      // The tile is close enough to [AppPalette.stone50] that without this the
      // mark loses its edge on a light surface.
      ..drawRRect(
        tile.deflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = AppPalette.navy900.withValues(alpha: 0.12),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) => false;
}
