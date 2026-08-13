import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// The Tenant Portal brand mark, drawn in code so it stays crisp at every
/// display density and does not delay first paint.
///
/// Three piers and two arches — the colonnade every retail arcade is built
/// from. It says *many tenants under one roof* rather than *a door*, which is
/// what the platform actually is. The centre pier is wider than the outer two
/// and carries the brass: the load-bearing column the tenancies on either side
/// rest against, and the only part of the accent that survives a 20 px icon.
///
/// The mark does not invert with the theme. It is the same artwork as the
/// launcher icon on every surface in the app, and a logo that changes colour
/// when the lights go out stops being a logo.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({
    this.size = 56,
    this.withShadow = false,
    this.semanticLabel = 'Tenant Portal',
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

  // The arcade on a 512 artboard: outer piers of 48, a centre pier of 64, and
  // two bays of 84. The bays are the widest members so they are the last
  // detail to close up as the icon shrinks.
  static const _top = 118.0;
  static const _bottom = 394.0;
  static const _left = 92.0;
  static const _right = 420.0;
  static const _pierLeft = 224.0;
  static const _pierRight = 288.0;
  static const _bayRadius = 42.0;

  /// Where the arches spring from the piers; the crown sits a radius above it.
  static const _spring = 220.0;

  @override
  void paint(Canvas canvas, Size size) {
    const artboardRect = Rect.fromLTWH(0, 0, _artboard, _artboard);
    canvas
      ..save()
      ..scale(size.width / _artboard, size.height / _artboard);

    // A warm stone tile rather than the navy the mark used to sit on. The
    // arcade is the dark shape now, which is what lets it hold together at
    // launcher sizes; navy-on-cream also stands out on a home screen full of
    // saturated icons in a way one more dark tile does not.
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

    // Piers and arches cut as one outline, so the bays are true negative space
    // and the whole mark reduces to a single path for the Android monochrome
    // layer and any one-colour use.
    final arcade = Path()
      ..moveTo(_left, _top)
      ..lineTo(_right, _top)
      ..lineTo(_right, _bottom)
      ..lineTo(372, _bottom)
      ..lineTo(372, _spring)
      ..arcToPoint(
        const Offset(_pierRight, _spring),
        radius: const Radius.circular(_bayRadius),
        clockwise: false,
      )
      ..lineTo(_pierRight, _bottom)
      ..lineTo(_pierLeft, _bottom)
      ..lineTo(_pierLeft, _spring)
      ..arcToPoint(
        const Offset(140, _spring),
        radius: const Radius.circular(_bayRadius),
        clockwise: false,
      )
      ..lineTo(140, _bottom)
      ..lineTo(_left, _bottom)
      ..close();

    canvas
      ..drawPath(arcade, Paint()..color = AppPalette.navy900)
      // The load-bearing centre pier. Brass at the mid weight, not the pale
      // one — [AppPalette.brass300] on cream reads as a smudge.
      ..drawRect(
        const Rect.fromLTWH(
          _pierLeft,
          _top,
          _pierRight - _pierLeft,
          _bottom - _top,
        ),
        Paint()..color = AppPalette.brass500,
      )
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
