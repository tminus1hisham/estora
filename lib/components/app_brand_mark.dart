import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// The Tenant Portal brand mark, drawn in code so it stays crisp at every
/// display density and does not delay first paint.
///
/// The ink block represents the building, the warm-stone portal represents a
/// welcoming commercial space, and the emerald threshold represents access.
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
    final brightness = Theme.of(context).brightness;

    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.27),
            boxShadow: withShadow
                ? AppElevation.soft(Colors.black)
                : const <BoxShadow>[],
          ),
          child: CustomPaint(
            painter: _BrandMarkPainter(brightness: brightness),
          ),
        ),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({required this.brightness});

  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.shortestSide * 0.27);
    final background = Paint()
      ..color = brightness == Brightness.dark
          ? AppPalette.ink800
          : AppPalette.ink950;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), background);

    final portal = Path()..fillType = PathFillType.evenOdd;
    portal
      ..moveTo(size.width * 0.25, size.height * 0.73)
      ..lineTo(size.width * 0.25, size.height * 0.47)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.28,
        size.width * 0.36,
        size.height * 0.20,
        size.width * 0.50,
        size.height * 0.20,
      )
      ..cubicTo(
        size.width * 0.64,
        size.height * 0.20,
        size.width * 0.75,
        size.height * 0.28,
        size.width * 0.75,
        size.height * 0.47,
      )
      ..lineTo(size.width * 0.75, size.height * 0.73)
      ..close()
      ..moveTo(size.width * 0.40, size.height * 0.73)
      ..lineTo(size.width * 0.40, size.height * 0.49)
      ..cubicTo(
        size.width * 0.40,
        size.height * 0.40,
        size.width * 0.44,
        size.height * 0.36,
        size.width * 0.50,
        size.height * 0.36,
      )
      ..cubicTo(
        size.width * 0.56,
        size.height * 0.36,
        size.width * 0.60,
        size.height * 0.40,
        size.width * 0.60,
        size.height * 0.49,
      )
      ..lineTo(size.width * 0.60, size.height * 0.73)
      ..close();

    canvas.drawPath(
      portal,
      Paint()
        ..color = brightness == Brightness.dark
            ? AppPalette.stone100
            : AppPalette.stone50,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.22,
          size.height * 0.71,
          size.width * 0.56,
          size.height * 0.09,
        ),
        Radius.circular(size.height * 0.045),
      ),
      Paint()
        ..color = brightness == Brightness.dark
            ? AppPalette.emerald300
            : AppPalette.emerald500,
    );
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) =>
      brightness != oldDelegate.brightness;
}
