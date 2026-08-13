import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// The Tenant Portal brand mark, drawn in code so it stays crisp at every
/// display density and does not delay first paint.
///
/// The porcelain arch represents the property, the open brass door represents
/// a welcoming commercial space, and the azure threshold represents access.
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
            borderRadius: BorderRadius.circular(size * 0.21875),
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

  static const _artboardSize = 512.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / _artboardSize, size.height / _artboardSize)
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, _artboardSize, _artboardSize),
          const Radius.circular(112),
        ),
        Paint()..color = AppPalette.navy900,
      );

    final arch = Path()
      ..moveTo(112, 400)
      ..lineTo(112, 222)
      ..cubicTo(112, 129, 176, 72, 256, 72)
      ..cubicTo(336, 72, 400, 129, 400, 222)
      ..lineTo(400, 400)
      ..lineTo(326, 400)
      ..lineTo(326, 224)
      ..cubicTo(326, 178, 297, 148, 256, 148)
      ..cubicTo(215, 148, 186, 178, 186, 224)
      ..lineTo(186, 400)
      ..close();
    canvas.drawPath(arch, Paint()..color = AppPalette.stone50);

    final keystone = Path()
      ..moveTo(232, 104)
      ..lineTo(280, 104)
      ..lineTo(269, 153)
      ..cubicTo(260, 149, 252, 149, 243, 153)
      ..close();
    canvas.drawPath(keystone, Paint()..color = AppPalette.brass300);

    final openDoor = Path()
      ..moveTo(216, 246)
      ..lineTo(263, 255)
      ..cubicTo(284, 259, 296, 274, 296, 294)
      ..lineTo(296, 370)
      ..lineTo(216, 398)
      ..close();
    canvas.drawPath(openDoor, Paint()..color = AppPalette.brass300);

    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(164, 384, 184, 24),
          const Radius.circular(12),
        ),
        Paint()..color = AppPalette.azure500,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) => false;
}
