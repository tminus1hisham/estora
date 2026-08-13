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
  /// Navy into deep azure rather than a lighter tint of either: the amount
  /// sits on this, and a dark ground is what makes a large white number feel
  /// like a statement instead of a label.
  static const LinearGradient brandHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppPalette.navy800, AppPalette.navy900, AppPalette.azure950],
    stops: [0, 0.55, 1],
  );

  /// A softer variant for surfaces that sit beside [brandHero] and should not
  /// compete with it.
  static const LinearGradient navySurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppPalette.navy800, AppPalette.navy900],
  );

  /// The fill for the one control a screen is built around.
  ///
  /// Ends darker than it begins so the button reads as a lit surface rather
  /// than a coloured rectangle. Both stops are dark enough to carry the label
  /// in [AppPalette.stone0] at the app's bold label weight.
  static const LinearGradient action = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppPalette.azure600, AppPalette.azure800],
  );

  /// The veil over the photograph on the sign-in stage.
  ///
  /// Heavier at both ends than across the middle, because the middle is where
  /// the building's own lights sit in the photograph and the top and bottom
  /// are where the app's text sits. Keeping one warm band alive is the whole
  /// point of putting a photograph there; letting it reach the headline is how
  /// a sign-in screen becomes unreadable at dusk.
  static final LinearGradient stageVeil = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppPalette.navy950.withValues(alpha: 0.84),
      AppPalette.navy900.withValues(alpha: 0.56),
      AppPalette.navy900.withValues(alpha: 0.48),
      AppPalette.navy950.withValues(alpha: 0.95),
    ],
    stops: const [0, 0.34, 0.62, 1],
  );

  /// Darkens the trailing edge of the stage, for the split layout.
  ///
  /// The single-column layout keeps its text over the dark head and foot of
  /// [stageVeil]. Side by side, the controls sit over the middle of the
  /// photograph instead — which is the part deliberately left bright — and the
  /// captions outside the glass have nothing to be read against. Directional
  /// so the shaded edge follows the column rather than the compass.
  static final LinearGradient stageEdgeVeil = LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: [
      Colors.transparent,
      AppPalette.navy950.withValues(alpha: 0.5),
      AppPalette.navy950.withValues(alpha: 0.84),
    ],
    stops: const [0.4, 0.66, 1],
  );

  /// Darkens the head of a full-bleed header, so a status bar, brand mark and
  /// action icons stay readable over whatever photograph is behind them.
  ///
  /// Navy rather than black: the header runs straight into the balance card
  /// below it, and a neutral black veil over a warm photograph reads as a
  /// different material from the navy the card is built from.
  static final LinearGradient headerVeil = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppPalette.navy950.withValues(alpha: 0.62),
      AppPalette.navy950.withValues(alpha: 0),
    ],
    stops: const [0, 0.55],
  );

  /// Darkens the foot of a full-bleed header.
  ///
  /// Heavier than [mediaScrim] on purpose: the tenant's own name sits on this
  /// at display size, and a name that has to be squinted at is worse than no
  /// photograph at all.
  static final LinearGradient headerScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppPalette.navy950.withValues(alpha: 0),
      AppPalette.navy950.withValues(alpha: 0.58),
      AppPalette.navy950.withValues(alpha: 0.95),
    ],
    stops: const [0.15, 0.6, 1],
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
