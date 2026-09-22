import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import 'glass_material.dart';

/// One choice in a [GlassPullDownPill]'s menu.
@immutable
class GlassPullDownOption<T> {
  const GlassPullDownOption({
    required this.value,
    required this.label,
    this.detail,
  });

  final T value;

  /// What the row says, and what the pill reads once it is chosen.
  final String label;

  /// A quieter second line under [label] — "4 invoices" — for when how much
  /// is behind a choice is what decides whether it is worth making.
  final String? detail;
}

/// iOS's pull-down button, set in glass: a capsule naming the current choice
/// with a chevron after it, and on a tap a frosted menu hung from it with a
/// check against the one in force.
///
/// For a scope over a whole screen — which property, which account — rather
/// than a filter inside it. The segmented control is the filter; this sits
/// above it and says what the whole screen is about.
///
/// The capsule is a tint, not a pane: it sits in a bar nothing scrolls under,
/// so there is nothing for glass to blur, and a frosted capsule over a flat
/// ground is only a grey one. The menu is real glass — it opens over the
/// records, and they show through it.
///
/// The first option is taken to be the unnarrowed one ("All properties"):
/// while it is selected the pill is clear, and once another is chosen it
/// takes a faint azure tint so a filtered screen reads as filtered.
class GlassPullDownPill<T> extends StatefulWidget {
  const GlassPullDownPill({
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.semanticPrefix,
    required this.menuLabel,
    this.icon,
    this.leadingGroup = 0,
    super.key,
  });

  final List<GlassPullDownOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  /// What the pill is a choice of, for a screen reader: "Property" reads out
  /// as "Property: Sarit Mall".
  final String semanticPrefix;

  /// The menu's name, for a screen reader arriving in it.
  final String menuLabel;

  /// A small glyph before the label, for what kind of thing is being chosen.
  final IconData? icon;

  /// How many options at the head of the list form a group of their own —
  /// "All properties" above the properties — drawn apart by a section gap.
  final int leadingGroup;

  /// The height the pill needs at the current text size, touch margin
  /// included, for a bar that has to reserve room for it before it builds.
  static double heightOf(BuildContext context) =>
      math.max(_minTouch, _capsuleHeight(context));

  static const double _minTouch = 44;

  static double _capsuleHeight(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: _labelStyle(context)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final line = painter.height;
    painter.dispose();
    return line + _padV * 2;
  }

  static const double _padV = 7;

  static TextStyle _labelStyle(BuildContext context) =>
      (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
        fontSize: 14,
        height: 1.25,
        letterSpacing: -0.1,
        fontWeight: AppTypography.semibold,
      );

  @override
  State<GlassPullDownPill<T>> createState() => _GlassPullDownPillState<T>();
}

class _GlassPullDownPillState<T> extends State<GlassPullDownPill<T>> {
  bool _open = false;

  GlassPullDownOption<T>? get _current {
    for (final option in widget.options) {
      if (option.value == widget.selected) return option;
    }
    return widget.options.isEmpty ? null : widget.options.first;
  }

  Future<void> _show() async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final navigator = Navigator.of(context);
    final overlay = navigator.overlay!.context.findRenderObject() as RenderBox;
    final anchor = MatrixUtils.transformRect(
      box.getTransformTo(overlay),
      Offset.zero & box.size,
    );
    final still = MediaQuery.disableAnimationsOf(context);

    setState(() => _open = true);
    final choice = await navigator.push(
      _GlassPullDownRoute<T>(
        anchor: anchor,
        options: widget.options,
        selected: widget.selected,
        leadingGroup: widget.leadingGroup,
        menuLabel: widget.menuLabel,
        still: still,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (choice != null && choice.value != widget.selected) {
      widget.onSelected(choice.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final still = MediaQuery.disableAnimationsOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    final current = _current;
    final label = current?.label ?? '';

    // At rest on "everything" the pill is the clear glass of the bar. Once it
    // narrows the screen it takes the faint azure of a control that is doing
    // something, so a tenant who comes back to a filtered statement can see
    // that it is filtered before reading a word.
    final narrowed =
        widget.options.isNotEmpty &&
        widget.selected != widget.options.first.value;
    final azure = dark ? AppPalette.azure300 : AppPalette.azure500;
    final ink = narrowed
        ? (dark ? AppPalette.azure100 : AppPalette.azure800)
        : scheme.onSurface;

    final decoration = ShapeDecoration(
      shape: StadiumBorder(
        side: BorderSide(
          color: narrowed
              ? azure.withValues(alpha: dark ? 0.22 : 0.18)
              : dark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.95),
        ),
      ),
      color: narrowed
          ? azure.withValues(alpha: dark ? 0.14 : 0.09)
          : dark
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.white.withValues(alpha: 0.62),
      shadows: [
        BoxShadow(
          color: AppPalette.navy900.withValues(alpha: dark ? 0.24 : 0.06),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );

    return GlassTap(
      onTap: widget.options.length < 2 ? null : _show,
      scale: 0.96,
      semanticLabel: '${widget.semanticPrefix}: $label',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: GlassPullDownPill._minTouch,
          ),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            alignment: AlignmentDirectional.centerStart,
            child: DecoratedBox(
              decoration: decoration,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  11,
                  GlassPullDownPill._padV,
                  9,
                  GlassPullDownPill._padV,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        size: scaler.scale(15).clamp(15.0, 24.0),
                        // The one brass note on the screen: a glyph, not a
                        // fill.
                        color: narrowed
                            ? ink.withValues(alpha: 0.9)
                            : (dark
                                  ? AppPalette.brass300
                                  : AppPalette.brass500),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: still ? Duration.zero : AppMotion.fast,
                        layoutBuilder: (current, previous) => Stack(
                          alignment: AlignmentDirectional.centerStart,
                          children: [...previous, ?current],
                        ),
                        child: Text(
                          label,
                          key: ValueKey(label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GlassPullDownPill._labelStyle(
                            context,
                          ).copyWith(color: ink),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: still ? Duration.zero : AppMotion.standard,
                      curve: AppMotion.emphasized,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: scaler.scale(18).clamp(18.0, 28.0),
                        color: narrowed
                            ? ink.withValues(alpha: 0.8)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The menu, as a route of its own: it takes focus, answers the back button
/// and Escape, and closes on a tap anywhere outside it.
class _GlassPullDownRoute<T> extends PopupRoute<({T value})> {
  _GlassPullDownRoute({
    required this.anchor,
    required this.options,
    required this.selected,
    required this.leadingGroup,
    required this.menuLabel,
    required this.still,
    required this.barrierLabel,
    required this.capturedThemes,
  });

  final Rect anchor;
  final List<GlassPullDownOption<T>> options;
  final T selected;
  final int leadingGroup;
  final String menuLabel;
  final bool still;
  final CapturedThemes capturedThemes;

  @override
  final String barrierLabel;

  @override
  bool get barrierDismissible => true;

  // No scrim. iOS leaves the screen as it was under a pull-down menu; the
  // menu's own glass and shadow are what lift it.
  @override
  Color? get barrierColor => null;

  @override
  Duration get transitionDuration =>
      still ? Duration.zero : const Duration(milliseconds: 360);

  @override
  Duration get reverseTransitionDuration =>
      still ? Duration.zero : const Duration(milliseconds: 180);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    return capturedThemes.wrap(
      CustomSingleChildLayout(
        delegate: _MenuLayout(
          anchor: anchor,
          padding: media.padding + media.viewInsets,
          preferredWidth: media.textScaler.scale(264),
        ),
        child: _PullDownMenu<T>(
          options: options,
          selected: selected,
          leadingGroup: leadingGroup,
          menuLabel: menuLabel,
          onChosen: (value) => Navigator.of(context).pop((value: value)),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (still) return child;
    // Out of the pill: grows from the corner it hangs from with a small
    // spring, and on the way back simply fades — iOS closes a menu faster
    // than it opens one.
    final opening = animation.status != AnimationStatus.reverse;
    final scale = CurvedAnimation(
      parent: animation,
      curve: opening ? const _MenuSpring() : Curves.easeIn,
    );
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: opening ? const Interval(0, 0.45) : Curves.easeIn,
      ),
      child: ScaleTransition(
        alignment: AlignmentDirectional.topStart.resolve(
          Directionality.of(context),
        ),
        scale: Tween<double>(begin: 0.86, end: 1).animate(scale),
        child: child,
      ),
    );
  }
}

/// Hangs the menu under the pill, from its leading edge, kept inside the
/// safe area; wider than the pill so a long name has room, never wider than
/// the screen less its margins.
class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout({
    required this.anchor,
    required this.padding,
    required this.preferredWidth,
  });

  final Rect anchor;
  final EdgeInsets padding;
  final double preferredWidth;

  static const double _margin = AppSpace.lg;

  /// From the pill's touch box, which already stands a few points proud of
  /// the drawn capsule; together they leave the menu hanging just clear of it.
  static const double _gap = 2;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = math.max(0.0, constraints.maxWidth - _margin * 2);
    final width = math.min(maxWidth, math.max(preferredWidth, anchor.width));
    final top = anchor.bottom + _gap;
    final maxHeight = math.max(
      0.0,
      constraints.maxHeight - top - padding.bottom - _margin,
    );
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = size.width - _margin - childSize.width;
    final left = anchor.left
        .clamp(_margin, math.max(_margin, maxLeft))
        .toDouble();
    return Offset(left, anchor.bottom + _gap);
  }

  @override
  bool shouldRelayout(_MenuLayout old) =>
      old.anchor != anchor ||
      old.padding != padding ||
      old.preferredWidth != preferredWidth;
}

class _PullDownMenu<T> extends StatelessWidget {
  const _PullDownMenu({
    required this.options,
    required this.selected,
    required this.leadingGroup,
    required this.menuLabel,
    required this.onChosen,
  });

  final List<GlassPullDownOption<T>> options;
  final T selected;
  final int leadingGroup;
  final String menuLabel;
  final ValueChanged<T> onChosen;

  static const double _radius = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    final rows = <Widget>[];
    for (final (index, option) in options.indexed) {
      if (index > 0) {
        rows.add(
          index == leadingGroup
              // A section gap: a band of the menu's own shadow, as iOS
              // separates a menu's groups.
              ? Container(
                  height: 7,
                  color: dark
                      ? Colors.black.withValues(alpha: 0.22)
                      : AppPalette.navy900.withValues(alpha: 0.05),
                )
              : Container(
                  height: 0.5,
                  color: scheme.onSurfaceVariant.withValues(
                    alpha: dark ? 0.22 : 0.18,
                  ),
                ),
        );
      }
      rows.add(
        _PullDownRow(
          option: option,
          selected: option.value == selected,
          onTap: () => onChosen(option.value),
        ),
      );
    }

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: menuLabel,
      child: CustomPaint(
        painter: _MenuShadow(dark: dark),
        child: FrostedPane(
          depth: GlassDepth.chrome,
          radius: _radius,
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of the menu: a check against the one in force, the label, and a
/// quieter line under it.
///
/// Pressed, the row greys the way an iOS menu row does, rather than sinking;
/// a menu is a list, and a list row that shrinks under the finger pulls away
/// from its neighbours.
class _PullDownRow<T> extends StatefulWidget {
  const _PullDownRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final GlassPullDownOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PullDownRow<T>> createState() => _PullDownRowState<T>();
}

class _PullDownRowState<T> extends State<_PullDownRow<T>> {
  bool _pressed = false;
  bool _focused = false;

  void _activate() {
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final scaler = MediaQuery.textScalerOf(context);
    final option = widget.option;
    final lit = _pressed || _focused;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: option.detail == null
          ? option.label
          : '${option.label}, ${option.detail}',
      excludeSemantics: true,
      onTap: _activate,
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: _activate,
          child: ColoredBox(
            color: lit
                ? (dark
                      ? Colors.white.withValues(alpha: 0.10)
                      : AppPalette.navy900.withValues(alpha: 0.07))
                : Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 16, 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: scaler.scale(17).clamp(17.0, 26.0).toDouble() + 4,
                      child: widget.selected
                          ? Icon(
                              Icons.check_rounded,
                              size: scaler.scale(17).clamp(17.0, 26.0),
                              color: dark
                                  ? AppPalette.azure200
                                  : AppPalette.azure700,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            option.label,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 15,
                              height: 1.25,
                              letterSpacing: -0.15,
                              fontWeight: AppTypography.medium,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (option.detail != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              option.detail!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12.5,
                                height: 1.3,
                                color: scheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The menu's lift: a wide, soft shadow drawn only outside its outline.
///
/// A box shadow is painted under the whole box, and under translucent glass
/// that would show through as a grey stain in the middle of the menu. Clipping
/// the interior out keeps the glass clean and leaves the shadow where a
/// shadow would fall.
class _MenuShadow extends CustomPainter {
  const _MenuShadow({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(_PullDownMenu._radius),
    );
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect.inflate(80)),
        Path()..addRRect(shape.deflate(0.5)),
      ),
    );
    canvas.drawRRect(
      shape.shift(const Offset(0, 8)),
      Paint()
        ..color = AppPalette.navy900.withValues(alpha: dark ? 0.6 : 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawRRect(
      shape.shift(const Offset(0, 1)),
      Paint()
        ..color = AppPalette.navy900.withValues(alpha: dark ? 0.30 : 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MenuShadow old) => old.dark != dark;
}

/// A slightly under-damped spring, as a curve: the menu overshoots its size
/// by a hair and settles.
class _MenuSpring extends Curve {
  const _MenuSpring();

  @override
  double transformInternal(double t) {
    // Critically-damped-ish response with a small overshoot, closed-form so
    // it costs nothing per frame.
    const zeta = 0.72;
    const omega = 11.0;
    final wd = omega * math.sqrt(1 - zeta * zeta);
    final time = t * 0.36;
    final envelope = math.exp(-zeta * omega * time);
    final value =
        1 -
        envelope *
            (math.cos(wd * time) + zeta * omega / wd * math.sin(wd * time));
    return t == 1 ? 1 : value;
  }
}
