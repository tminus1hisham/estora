import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A ring that draws itself and a tick that strokes on after it.
///
/// This is the app's one celebratory moment. It is used where the server has
/// confirmed something irreversible — a settled payment, an issued receipt —
/// and nowhere else, so that it keeps meaning something.
///
/// Restraint is the point: a ring and a tick, about half a second, no bounce
/// and no confetti. The tenant has just parted with money and wants
/// reassurance, not a party.
class AppSuccessMark extends StatefulWidget {
  const AppSuccessMark({
    required this.color,
    this.size = 88,
    this.icon,
    super.key,
  });

  final Color color;
  final double size;

  /// Replaces the drawn tick. Used for terminal states that are settled but
  /// not successful, where a tick would be a lie.
  final IconData? icon;

  @override
  State<AppSuccessMark> createState() => _AppSuccessMarkState();
}

class _AppSuccessMarkState extends State<AppSuccessMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );

  late final Animation<double> _ring = CurvedAnimation(
    parent: _controller,
    // The ring owns the first two thirds; the tick follows in the last.
    curve: const Interval(0, 0.62, curve: AppMotion.enter),
  );

  late final Animation<double> _tick = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.55, 1, curve: AppMotion.enter),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _SuccessPainter(
                color: widget.color,
                ringProgress: _ring.value,
                haloProgress: _controller.value,
              ),
              child: widget.icon == null
                  ? null
                  : Center(
                      child: Opacity(
                        opacity: _tick.value,
                        child: Icon(
                          widget.icon,
                          size: widget.size * 0.38,
                          color: widget.color,
                        ),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _SuccessPainter extends CustomPainter {
  const _SuccessPainter({
    required this.color,
    required this.ringProgress,
    required this.haloProgress,
  });

  final Color color;
  final double ringProgress;
  final double haloProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    // A soft disc behind the ring, so the mark reads as lit rather than drawn.
    canvas.drawCircle(
      centre,
      radius * (0.82 + 0.18 * haloProgress),
      Paint()..color = color.withValues(alpha: 0.12 * haloProgress),
    );

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      2 * math.pi * ringProgress,
      false,
      ring,
    );
  }

  @override
  bool shouldRepaint(_SuccessPainter old) =>
      old.ringProgress != ringProgress ||
      old.haloProgress != haloProgress ||
      old.color != color;
}
