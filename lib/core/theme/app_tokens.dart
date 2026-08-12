import 'package:flutter/widgets.dart';

/// The spacing rhythm used across the app.
///
/// Keeping this deliberately small makes screens feel related even when they
/// are owned by different features.
class AppSpace {
  const AppSpace._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double display = 64;
}

/// Backwards-compatible spacing helpers used by the existing screens.
class Gap {
  const Gap._();

  static const double xs = AppSpace.xs;
  static const double sm = AppSpace.sm;
  static const double md = AppSpace.md;
  static const double lg = AppSpace.lg;
  static const double xl = AppSpace.xl;
  static const double xxl = AppSpace.xxl;

  static const Widget h4 = SizedBox(height: xs);
  static const Widget h8 = SizedBox(height: sm);
  static const Widget h12 = SizedBox(height: md);
  static const Widget h16 = SizedBox(height: lg);
  static const Widget h24 = SizedBox(height: xl);
  static const Widget h32 = SizedBox(height: xxl);
  static const Widget h48 = SizedBox(height: AppSpace.xxxl);

  static const Widget w4 = SizedBox(width: xs);
  static const Widget w8 = SizedBox(width: sm);
  static const Widget w12 = SizedBox(width: md);
  static const Widget w16 = SizedBox(width: lg);
  static const Widget w24 = SizedBox(width: xl);
}

/// Corner radii. Cards use a softer radius than controls, while pills are
/// reserved for short statuses and compact selectors.
class AppRadius {
  const AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius small = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(md));
  static const BorderRadius large = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius extraLarge = BorderRadius.all(Radius.circular(xl));
}

/// Elevation levels are intentionally low. Hierarchy primarily comes from
/// tonal surfaces and borders, with shadows only where depth is meaningful.
class AppElevation {
  const AppElevation._();

  static const double none = 0;
  static const double low = 1;
  static const double medium = 4;
  static const double high = 10;

  static List<BoxShadow> soft(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.08),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
  ];

  /// A two-layer shadow: a tight contact shadow that anchors the surface to
  /// what is behind it, and a wide ambient one that gives it room.
  ///
  /// A single blur reads as a smudge at the sizes this app uses; the pair is
  /// what makes a raised surface look lit rather than merely offset. [level]
  /// runs 1–3 and scales both layers together.
  ///
  /// Dark surfaces need a denser shadow to register at all against a dark
  /// background, so [brightness] scales the alpha rather than the geometry.
  static List<BoxShadow> lifted(
    Color shadow, {
    int level = 1,
    Brightness brightness = Brightness.light,
  }) {
    final depth = level.clamp(1, 3);
    final density = brightness == Brightness.dark ? 2.1 : 1.0;

    return [
      BoxShadow(
        color: shadow.withValues(alpha: 0.05 * density),
        blurRadius: 2.0 * depth,
        offset: Offset(0, 1.0 * depth),
      ),
      BoxShadow(
        color: shadow.withValues(alpha: 0.06 * density),
        blurRadius: 12.0 * depth,
        offset: Offset(0, 4.0 * depth),
      ),
    ];
  }
}

/// Shared durations and curves keep state changes calm and predictable.
class AppMotion {
  const AppMotion._();

  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 420);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// How far a surface travels while fading in. Small on purpose: the eye
  /// reads the fade, and a long slide just makes the screen feel slow.
  static const double enterOffset = 12;

  /// The delay before the item at [index] enters.
  ///
  /// Capped deliberately. Un-capped stagger means the last card of a long list
  /// waits on every card above it, so a ten-item list would take most of a
  /// second to finish arriving; after a few items the effect has landed and
  /// further delay is just latency.
  static Duration stagger(int index, {int cap = 6}) =>
      Duration(milliseconds: 45 * index.clamp(0, cap));
}

/// Width and sizing constraints for responsive layouts.
class AppLayout {
  const AppLayout._();

  static const double compactBreakpoint = 600;
  static const double mediumBreakpoint = 840;
  static const double maxFormWidth = 480;
  static const double maxReadingWidth = 720;
  static const double maxContentWidth = 1200;
  static const double minTouchTarget = 48;
  static const double controlHeight = 52;
  static const double pagePaddingCompact = 20;
  static const double pagePaddingExpanded = 32;

  static double pagePaddingFor(double width) =>
      width < compactBreakpoint ? pagePaddingCompact : pagePaddingExpanded;
}

/// Typography primitives shared by [ThemeData] and one-off emphasis styles.
class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'Manrope';
  static const List<String> fontFallback = <String>[
    'Inter',
    'Segoe UI',
    'Roboto',
    'Arial',
  ];

  static const double bodyHeight = 1.45;
  static const double titleHeight = 1.18;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;
}
