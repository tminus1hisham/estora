import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';

/// The tenant screens' glass: a lit ground, frosted panes over it, and a
/// press that answers the finger.
///
/// Glass only reads as glass when there is something behind it to blur, and a
/// flat cream page has nothing. So the material comes in two halves that are
/// meant to be used together:
///
/// * [GlassScene] paints the ground — the page colour with a few wide, soft
///   lights in it — and stays put while the content scrolls over it.
/// * [FrostedPane] is a pane of that glass. It blurs whatever of the scene is
///   behind it, lifts the saturation the way iOS materials do so the lights
///   come through as colour rather than as grey, and catches a hairline of
///   light along its upper edge.
///
/// Because the lights are fixed and the panes scroll, a card warms as it passes
/// over the brass and cools over the azure. That drift is the whole effect; no
/// animation is spent on it.

/// Corner radii on the continuous (squircle) curve iOS uses. A circular corner
/// meets the straight edge with a visible kink at these sizes; the superellipse
/// does not, which is most of what makes a card look native on an iPhone.
abstract final class GlassRadius {
  static const double tile = 22;
  static const double card = 26;
  static const double platter = 30;
  static const double capsule = 999;
}

/// The page ground the glass sits on.
///
/// Wrap a screen's scroll view in this. It paints the surface colour and the
/// lights behind [child] and groups every [FrostedPane] below it so they share
/// one read of the backdrop instead of taking one each.
class GlassScene extends StatelessWidget {
  const GlassScene({
    required this.child,
    this.lights = GlassLights.standard,
    super.key,
  });

  final Widget child;

  /// Where the lights sit. Screens with a dark header above the fold use
  /// [GlassLights.belowHeader] so the first light lands on the content rather
  /// than under the photograph.
  final GlassLights lights;

  @override
  Widget build(BuildContext context) {
    return BackdropGroup(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: GlassGround(lights: lights)),
          child,
        ],
      ),
    );
  }
}

/// Where a [GlassScene]'s lights are placed, as fractions of the screen.
enum GlassLights {
  /// Azure high on the trailing side, brass across the middle on the leading
  /// side, a cool violet low down.
  standard(azureTop: 0.02, brassTop: 0.38, violetTop: 0.74),

  /// The same set pushed down, for a screen that opens on a dark header.
  belowHeader(azureTop: 0.30, brassTop: 0.55, violetTop: 0.86);

  const GlassLights({
    required this.azureTop,
    required this.brassTop,
    required this.violetTop,
  });

  final double azureTop;
  final double brassTop;
  final double violetTop;
}

/// The painted half of [GlassScene], for a screen that needs to place the
/// ground itself.
class GlassGround extends StatelessWidget {
  const GlassGround({this.lights = GlassLights.standard, super.key});

  final GlassLights lights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    // Wide and faint. In light mode they are washes on cream, never shapes; in
    // dark mode they are the only colour on the page and can carry a little
    // more.
    final azure = dark
        ? AppPalette.azure600.withValues(alpha: 0.34)
        : AppPalette.azure200.withValues(alpha: 0.62);
    final brass = dark
        ? AppPalette.brass500.withValues(alpha: 0.16)
        : AppPalette.brass200.withValues(alpha: 0.46);
    final violet = dark
        ? AppPalette.violet700.withValues(alpha: 0.30)
        : AppPalette.violet300.withValues(alpha: 0.30);

    return IgnorePointer(
      child: RepaintBoundary(
        child: ColoredBox(
          color: scheme.surface,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final size = (w * 1.25).clamp(360.0, 900.0);
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    top: h * lights.azureTop - size * 0.35,
                    right: -size * 0.42,
                    child: _Light(color: azure, size: size),
                  ),
                  Positioned(
                    top: h * lights.brassTop - size * 0.4,
                    left: -size * 0.5,
                    child: _Light(color: brass, size: size * 0.95),
                  ),
                  Positioned(
                    top: h * lights.violetTop - size * 0.4,
                    right: -size * 0.3,
                    child: _Light(color: violet, size: size * 0.9),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Light extends StatelessWidget {
  const _Light({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            // A flatter falloff than a two-stop radial: the centre is held for
            // a while so the light reads as a wash, not as a spot.
            colors: [
              color,
              color.withValues(alpha: color.a * 0.55),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
      ),
    );
  }
}

/// How much a [FrostedPane] stands forward.
enum GlassDepth {
  /// A pane inside another pane, or a control on a card.
  inset,

  /// A card on the page. The default.
  card,

  /// A bar or platter that other content passes under.
  chrome,

  /// A sheet floated over the page: barely tinted, heavily blurred, so the
  /// page shows through as colour while its detail melts away.
  sheet,
}

/// A pane of frosted glass with continuous corners.
///
/// [tone] washes the pane faintly with a colour of its own — a status, an
/// accent — without changing the material, so a column of these still reads
/// as one set. Keep it for the card's meaning, not for decoration.
class FrostedPane extends StatelessWidget {
  const FrostedPane({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.radius = GlassRadius.card,
    this.depth = GlassDepth.card,
    this.tone,
    this.onDark = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final GlassDepth depth;
  final Color? tone;

  /// Set for a pane laid on a brand surface, which is navy in both themes.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = onDark || theme.brightness == Brightness.dark;
    final borderRadius = BorderRadius.all(Radius.circular(radius));

    final blur = switch (depth) {
      GlassDepth.inset => 12.0,
      GlassDepth.card => 26.0,
      GlassDepth.chrome => 30.0,
      GlassDepth.sheet => 44.0,
    };

    // The veil. Light panes are milk; dark panes are navy smoke. Thin enough
    // that the scene's lights come through, dense enough that text on it
    // never depends on what happens to be behind.
    final Color fill;
    if (onDark) {
      fill = Colors.white.withValues(alpha: 0.08);
    } else if (dark) {
      fill = switch (depth) {
        GlassDepth.inset => AppPalette.navy700.withValues(alpha: 0.28),
        GlassDepth.card => AppPalette.navy800.withValues(alpha: 0.46),
        GlassDepth.chrome => AppPalette.navy900.withValues(alpha: 0.62),
        GlassDepth.sheet => AppPalette.navy900.withValues(alpha: 0.30),
      };
    } else {
      fill = switch (depth) {
        GlassDepth.inset => Colors.white.withValues(alpha: 0.42),
        GlassDepth.card => Colors.white.withValues(alpha: 0.58),
        GlassDepth.chrome => AppPalette.stone0.withValues(alpha: 0.72),
        GlassDepth.sheet => Colors.white.withValues(alpha: 0.20),
      };
    }

    // Only cards share the scene's backdrop read. Impeller takes that read
    // once, before the first grouped pane paints, so anything painted after
    // it is missing from the shared copy. Cards over the ground only need the
    // ground, which is always there first; a pinned bar needs the cards that
    // are scrolling under it, and an inset pane needs the card it sits on, so
    // those take a read of their own.
    final grouped = depth == GlassDepth.card && !onDark;
    final filter = ui.ImageFilter.compose(
      outer: ui.ImageFilter.blur(
        sigmaX: blur,
        sigmaY: blur,
        tileMode: TileMode.mirror,
      ),
      // iOS lifts saturation under its materials so colour behind the glass
      // survives the blur. Without it the lights come through as a muddy grey
      // and the pane reads as dirty rather than frosted.
      inner: const ColorFilter.matrix(_saturate),
    );
    final body = CustomPaint(
      painter: _PanePainter(
        radius: borderRadius,
        fill: fill,
        tone: tone,
        dark: dark,
      ),
      foregroundPainter: _RimPainter(radius: borderRadius, dark: dark),
      child: Padding(padding: padding, child: child),
    );

    return ClipRSuperellipse(
      borderRadius: borderRadius,
      child: grouped
          ? BackdropFilter.grouped(filter: filter, child: body)
          : BackdropFilter(filter: filter, child: body),
    );
  }

  /// A 1.7× saturation matrix (Rec. 709 luma weights).
  static const List<double> _saturate = [
    1.5073, -0.4291, -0.0782, 0, 0, //
    -0.1427, 1.2209, -0.0782, 0, 0, //
    -0.1427, -0.4291, 1.5718, 0, 0, //
    0, 0, 0, 1, 0,
  ];
}

/// The veil, the tone wash and the soft light across the top of a pane.
class _PanePainter extends CustomPainter {
  const _PanePainter({
    required this.radius,
    required this.fill,
    required this.tone,
    required this.dark,
  });

  final BorderRadius radius;
  final Color fill;
  final Color? tone;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = radius.toRSuperellipse(rect);

    canvas.drawRSuperellipse(shape, Paint()..color = fill);

    final tone = this.tone;
    if (tone != null) {
      // From the leading top corner, fading before the middle: the pane is
      // lit by its meaning, not painted with it.
      canvas.drawRSuperellipse(
        shape,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-1, -1.1),
            radius: 1.25,
            colors: [
              tone.withValues(alpha: dark ? 0.22 : 0.16),
              tone.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    // Room light on the upper third.
    canvas.drawRSuperellipse(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: dark ? 0.06 : 0.34),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.42],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_PanePainter old) =>
      old.fill != fill ||
      old.tone != tone ||
      old.dark != dark ||
      old.radius != radius;
}

/// The hairline rim: bright where the light catches the upper-leading edge,
/// almost gone along the lower-trailing one.
class _RimPainter extends CustomPainter {
  const _RimPainter({required this.radius, required this.dark});

  final BorderRadius radius;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    canvas.drawRSuperellipse(
      radius.toRSuperellipse(rect),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  Colors.white.withValues(alpha: 0.22),
                  Colors.white.withValues(alpha: 0.06),
                  Colors.white.withValues(alpha: 0.10),
                ]
              : [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.45),
                  AppPalette.navy900.withValues(alpha: 0.08),
                ],
          stops: const [0, 0.5, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.dark != dark || old.radius != radius;
}

/// An iOS-style press: the surface sinks under the finger, springs back on
/// release, and the device gives a light tick.
///
/// No ripple. A ripple is Material's answer to "did that register"; on glass it
/// smears a grey disc across the lights, and the scale already answers it.
class GlassTap extends StatefulWidget {
  const GlassTap({
    required this.child,
    required this.onTap,
    this.scale = 0.96,
    this.semanticLabel,
    this.haptic = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// How far the surface sinks. 0.96 suits a tile; a full-width card wants
  /// something shallower, around 0.98.
  final double scale;

  final String? semanticLabel;
  final bool haptic;

  @override
  State<GlassTap> createState() => _GlassTapState();
}

class _GlassTapState extends State<GlassTap> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final still = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: enabled
            ? () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _pressed && !still ? widget.scale : 1,
          duration: _pressed
              ? AppMotion.instant
              : const Duration(milliseconds: 380),
          // Down fast, back with a small overshoot, so the release lands.
          curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: _pressed ? 0.86 : 1,
            duration: _pressed ? AppMotion.instant : AppMotion.standard,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// The capsule button that goes on glass.
///
/// [prominent] is the one action a card exists for — "Pay now" — lit azure,
/// with a highlight along its top so it reads as a lit surface rather than a
/// flat fill. Otherwise it is a clear capsule of the same glass as the card,
/// which is how iOS sets a secondary action on a material.
class GlassCapsuleButton extends StatelessWidget {
  const GlassCapsuleButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.prominent = true,
    this.expand = false,
    this.onDark = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool prominent;

  /// Fill the width it is given, for the stacked layout at large text sizes.
  final bool expand;

  /// Set on a brand surface, where the clear capsule has to be light.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = onDark || theme.brightness == Brightness.dark;

    final Color foreground;
    final Decoration decoration;
    if (prominent) {
      foreground = dark ? AppPalette.azure950 : AppPalette.stone0;
      decoration = ShapeDecoration(
        shape: const StadiumBorder(),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [AppPalette.azure100, AppPalette.azure200]
              : const [AppPalette.azure600, AppPalette.azure700],
        ),
        shadows: [
          BoxShadow(
            color: (dark ? AppPalette.azure300 : AppPalette.azure600)
                .withValues(alpha: dark ? 0.10 : 0.14),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      );
    } else {
      foreground = dark ? AppPalette.stone0 : AppPalette.navy900;
      decoration = ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.9),
          ),
        ),
        color: dark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.55),
      );
    }

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            // Grows with the label, so at a large text size the glyph is not
            // left a speck beside the words.
            size: MediaQuery.textScalerOf(context).scale(17).clamp(17.0, 24.0),
            color: foreground,
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: AppTypography.semibold,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );

    return GlassTap(
      onTap: onPressed,
      scale: 0.95,
      semanticLabel: label,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: DecoratedBox(
            decoration: decoration,
            child: Stack(
              children: [
                if (prominent)
                  // The lip of light along the top of a lit capsule.
                  Positioned(
                    left: 10,
                    right: 10,
                    top: 1,
                    height: 12,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: const StadiumBorder(),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: dark ? 0.3 : 0.14),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  child: content,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
