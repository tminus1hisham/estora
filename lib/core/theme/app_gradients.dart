import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Gradients used for hero surfaces and image scrims.
///
/// Kept in one place because the alternative — which this app had — is the
/// same scrim written as a different hardcoded hex on every screen that puts
/// text over a photograph, none of which respond to the theme.
///
/// These are deliberately shallow. A gradient that announces itself dates
/// quickly; these exist to keep a large surface from reading as a flat slab.
abstract final class AppGradients {
  /// The brand surface for the one element on a screen that carries the money.
  ///
  /// Ink to emerald rather than a lighter tint of either: the amount sits on
  /// this, and a dark ground is what makes a large white number feel like a
  /// statement instead of a label.
  static const LinearGradient brandHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppPalette.ink800, AppPalette.ink900, AppPalette.emerald950],
    stops: [0, 0.55, 1],
  );

  /// A softer variant for surfaces that sit beside [brandHero] and should not
  /// compete with it.
  static const LinearGradient inkSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppPalette.ink800, AppPalette.ink900],
  );

  /// Darkens the foot of a photograph so text and badges stay legible.
  ///
  /// [strength] is the alpha at the bottom edge. The default suits a caption;
  /// raise it when a badge sits over a bright image.
  static LinearGradient mediaScrim({double strength = 0.62}) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Colors.black.withValues(alpha: strength * 0.35),
      Colors.black.withValues(alpha: strength),
    ],
    stops: const [0.35, 0.72, 1],
  );

  /// A barely-there top highlight, as if the surface were catching room light.
  ///
  /// Alpha this low is intentional — it should be invisible as an effect and
  /// only noticeable if you remove it.
  static LinearGradient sheen(Brightness brightness) {
    final alpha = brightness == Brightness.dark ? 0.05 : 0.5;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: alpha),
        Colors.white.withValues(alpha: 0),
      ],
      stops: const [0, 0.6],
    );
  }

  /// Fades a scrolling region out at its edge, so clipped content reads as
  /// continuing rather than as having been cut off.
  static LinearGradient fadeOut(Color surface) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surface.withValues(alpha: 0), surface],
  );
}
