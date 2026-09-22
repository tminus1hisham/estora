import 'package:flutter/material.dart';

/// A glyph set into a squircle well in the glass, washed in a hue of its own.
///
/// The same object the home shortcuts sit in, for a card that wants to say
/// what it is before it is read. It is deliberately not a second pane of
/// glass: it always sits inside one already, and a blur inside a blur only
/// costs a layer. A tinted wash, a rim of caught light and a lip along the top
/// are enough to read as a hollow in the pane.
class GlassWell extends StatelessWidget {
  const GlassWell({
    required this.icon,
    required this.color,
    this.size = 44,
    this.iconSize,
    super.key,
  });

  final IconData icon;

  /// The glyph's colour, which the well is washed in too. Pass the colour as
  /// it should read in the current theme.
  final Color color;

  final double size;

  /// Defaults to a little under half the well.
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // The continuous corner at the proportion iOS gives an app icon, so a
    // small well and a large one are visibly the same shape.
    final radius = BorderRadius.all(Radius.circular(size * 0.33));

    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: radius,
            side: BorderSide(
              color: dark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.9),
            ),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [color.withValues(alpha: 0.24), color.withValues(alpha: 0.07)]
                : [
                    Color.alphaBlend(
                      color.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.75),
                    ),
                    Color.alphaBlend(
                      color.withValues(alpha: 0.06),
                      Colors.white.withValues(alpha: 0.4),
                    ),
                  ],
          ),
          shadows: [
            BoxShadow(
              color: color.withValues(alpha: dark ? 0.16 : 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // Light caught across the top, fading out before the glyph. One wash
        // over the whole shape: an inset band showed its own corners.
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(borderRadius: radius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: dark ? 0.10 : 0.5),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [0, 0.5],
            ),
          ),
          child: Center(
            child: Icon(icon, size: iconSize ?? size * 0.46, color: color),
          ),
        ),
      ),
    );
  }
}
