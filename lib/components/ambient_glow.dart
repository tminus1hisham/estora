import 'package:flutter/material.dart';

/// A soft radial light, used to give a large dark surface its depth.
///
/// A radial fill rather than a real blur: the same look on screen, none of the
/// cost of an extra composited layer. Sized generously and positioned so most
/// of it falls outside its parent — a glow that fits inside the surface reads
/// as a drawn circle, one that runs off the edge reads as a light source.
class AmbientGlow extends StatelessWidget {
  const AmbientGlow({
    required this.color,
    required this.size,
    this.opacity = 1,
    super.key,
  });

  /// The colour at the centre. Fades to fully transparent at the rim.
  final Color color;

  final double size;

  /// Scales the whole light without having to restate [color] with an alpha.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: color.a * opacity),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
