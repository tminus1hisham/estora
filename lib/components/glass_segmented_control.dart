import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';

/// One choice in a [GlassSegmentedControl].
@immutable
class GlassSegment<T> {
  const GlassSegment({required this.value, required this.label, this.count});

  final T value;
  final String label;

  /// Shown after the label in a quieter figure, when the choice is a filter
  /// and "how many" is what decides whether it is worth a tap.
  final int? count;
}

/// The iOS segmented control, set in glass: a recessed track, and a lit thumb
/// that slides from one choice to the next.
///
/// The track is a tint, not a pane. It always sits on something frosted
/// already — a chrome bar, a card — and a blur inside a blur costs a layer to
/// say nothing new. The thumb is the one lit thing in it: white on the milk
/// glass, a lifted smoke on the navy, the way iOS draws its own.
///
/// The segments share the width equally while their labels fit, which is what
/// makes the control read as one object. When the platform's text size has
/// grown past that, the widths follow the labels instead, and past the width
/// available the track scrolls — a label is never shrunk or clipped to keep
/// the row tidy.
class GlassSegmentedControl<T> extends StatelessWidget {
  const GlassSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<GlassSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// The control's height at the current text size, for a caller that has to
  /// reserve room for it before it builds — a pinned sliver, say.
  static double heightOf(BuildContext context) =>
      _Metrics.of(context).trackHeight;

  @override
  Widget build(BuildContext context) {
    final metrics = _Metrics.of(context);
    final selectedIndex = math.max(
      0,
      segments.indexWhere((s) => s.value == selected),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - _Metrics.inset * 2;
        final natural = [for (final s in segments) metrics.naturalWidth(s)];
        final total = natural.fold<double>(0, (a, b) => a + b);
        final widest = natural.fold<double>(0, math.max);

        // Equal while every label fits its share; otherwise each segment
        // keeps its label's width, plus an even share of whatever is left.
        final List<double> widths;
        if (widest * segments.length <= available) {
          widths = List.filled(segments.length, available / segments.length);
        } else if (total <= available) {
          final spare = (available - total) / segments.length;
          widths = [for (final w in natural) w + spare];
        } else {
          widths = natural;
        }

        final track = _Track<T>(
          control: this,
          metrics: metrics,
          widths: widths,
          selectedIndex: selectedIndex,
        );

        if (total <= available) return track;
        // Too wide to fit: the track scrolls, and fades out at its trailing
        // edge so the cut reads as "more this way" rather than as a label
        // that has been clipped.
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.black, Colors.black, Colors.transparent],
            stops: [0, 0.86, 1],
          ).createShader(bounds),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: track,
          ),
        );
      },
    );
  }
}

/// The type sizes the control is drawn at, and what they measure to at the
/// current text size.
class _Metrics {
  _Metrics._(this.label, this.count, this.scaler, this.lineHeight);

  factory _Metrics.of(BuildContext context) {
    final theme = Theme.of(context);
    final label = (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
      fontSize: 13,
      height: 1.25,
      letterSpacing: -0.08,
      fontWeight: AppTypography.semibold,
    );
    final count = label.copyWith(
      fontSize: 12,
      fontWeight: AppTypography.medium,
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final scaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: label),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final line = painter.height;
    painter.dispose();
    return _Metrics._(label, count, scaler, line);
  }

  final TextStyle label;
  final TextStyle count;
  final TextScaler scaler;
  final double lineHeight;

  static const double inset = 2;
  static const double padH = 12;
  static const double labelGap = 5;

  double get segmentHeight => math.max(32, lineHeight + 14);
  double get trackHeight => segmentHeight + inset * 2;

  double naturalWidth(GlassSegment<Object?> segment) {
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    var width = measure(segment.label, label);
    if (segment.count != null) {
      width += labelGap + measure('${segment.count}', count);
    }
    // A pixel either side for rounding, so a measured label never wraps.
    return (width + padH * 2 + 2).ceilToDouble();
  }
}

class _Track<T> extends StatelessWidget {
  const _Track({
    required this.control,
    required this.metrics,
    required this.widths,
    required this.selectedIndex,
  });

  final GlassSegmentedControl<T> control;
  final _Metrics metrics;
  final List<double> widths;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final still = MediaQuery.disableAnimationsOf(context);
    final segmentHeight = metrics.segmentHeight;

    double leftOf(int index) {
      var x = _Metrics.inset;
      for (var i = 0; i < index; i++) {
        x += widths[i];
      }
      return x;
    }

    final width = leftOf(widths.length) + _Metrics.inset;

    return SizedBox(
      width: width,
      height: metrics.trackHeight,
      child: DecoratedBox(
        // The recess. iOS's own fill for a control track: a grey that takes
        // on whatever is behind it rather than a colour of its own.
        decoration: ShapeDecoration(
          shape: StadiumBorder(
            side: BorderSide(
              color: dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppPalette.navy900.withValues(alpha: 0.04),
            ),
          ),
          color: const Color(0xFF767680).withValues(alpha: dark ? 0.24 : 0.12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Hairlines between the segments the thumb is not beside, as iOS
            // draws them; they fade as the thumb arrives so it never sits on
            // a seam.
            for (var i = 1; i < widths.length; i++)
              Positioned(
                left: leftOf(i) - 0.5,
                top: segmentHeight * 0.3 + _Metrics.inset,
                height: segmentHeight * 0.4,
                width: 1,
                child: AnimatedOpacity(
                  opacity: i == selectedIndex || i == selectedIndex + 1 ? 0 : 1,
                  duration: still ? Duration.zero : AppMotion.fast,
                  child: ColoredBox(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.22),
                  ),
                ),
              ),
            AnimatedPositioned(
              left: leftOf(selectedIndex),
              top: _Metrics.inset,
              width: widths[selectedIndex],
              height: segmentHeight,
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 460),
              curve: const _SpringCurve(),
              child: _Thumb(dark: dark),
            ),
            Positioned.fill(
              left: _Metrics.inset,
              right: _Metrics.inset,
              top: _Metrics.inset,
              bottom: _Metrics.inset,
              child: Row(
                children: [
                  for (final (index, segment) in control.segments.indexed)
                    SizedBox(
                      width: widths[index],
                      child: _SegmentLabel(
                        segment: segment,
                        metrics: metrics,
                        selected: index == selectedIndex,
                        onTap: () {
                          if (index == selectedIndex) return;
                          HapticFeedback.selectionClick();
                          control.onChanged(segment.value);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The lit capsule under the chosen segment.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.16)
                : AppPalette.navy900.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [
                  Colors.white.withValues(alpha: 0.24),
                  Colors.white.withValues(alpha: 0.14),
                ]
              : const [AppPalette.stone0, AppPalette.stone0],
        ),
        shadows: [
          BoxShadow(
            color: AppPalette.navy900.withValues(alpha: dark ? 0.30 : 0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: AppPalette.navy900.withValues(alpha: dark ? 0.12 : 0.04),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({
    required this.segment,
    required this.metrics,
    required this.selected,
    required this.onTap,
  });

  final GlassSegment<Object?> segment;
  final _Metrics metrics;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = segment.count;

    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? segment.label : '${segment.label}, $count',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The weight does not change with selection: a label that
              // thickens as the thumb arrives shifts its neighbours, and the
              // thumb is signal enough.
              Text(
                segment.label,
                maxLines: 1,
                softWrap: false,
                style: metrics.label.copyWith(color: scheme.onSurface),
              ),
              if (count != null) ...[
                const SizedBox(width: _Metrics.labelGap),
                AnimatedDefaultTextStyle(
                  duration: AppMotion.fast,
                  style: metrics.count.copyWith(
                    color: scheme.onSurfaceVariant.withValues(
                      alpha: selected ? 0.9 : 0.7,
                    ),
                  ),
                  child: Text('$count', maxLines: 1, softWrap: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A slightly under-damped spring as a curve: the thumb overshoots by a hair
/// and settles, which is the motion iOS gives the same control.
class _SpringCurve extends Curve {
  const _SpringCurve();

  static final SpringSimulation _spring = SpringSimulation(
    const SpringDescription(mass: 1, stiffness: 320, damping: 28),
    0,
    1,
    0,
  );

  /// How much of the spring's time [AnimatedPositioned]'s duration covers.
  static const double _seconds = 0.46;

  @override
  double transformInternal(double t) => _spring.x(t * _seconds);
}
