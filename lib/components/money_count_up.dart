import 'package:flutter/material.dart';

import '../core/utils/money.dart';
import 'amount_text.dart';

/// A [Money] amount that counts up to its value once, on first build.
///
/// Reserved for the headline figure on a screen. The count is decoration, not
/// information: the widget always finishes on exactly the amount it was given,
/// and someone who has asked for reduced motion is shown that amount directly.
///
/// The animation is one-shot, like every other in this app — a repeating one
/// would never let the widget tree go idle and would hang `pumpAndSettle`.
class MoneyCountUp extends StatelessWidget {
  const MoneyCountUp(
    this.amount, {
    this.scale = AmountScale.hero,
    this.color,
    this.duration = const Duration(milliseconds: 900),
    this.delay = Duration.zero,
    super.key,
  });

  final Money amount;

  /// How large the figure is set. Passed straight to [AmountText], so a counted
  /// figure and a still one at the same scale are drawn identically.
  final AmountScale scale;

  final Color? color;
  final Duration duration;

  /// Held on the starting value for this long before counting. Used to let the
  /// surface the figure sits on arrive first.
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final settled = AmountText(amount, scale: scale, color: color);

    // Nothing to count from, or nothing that should move.
    if (amount.minorUnits <= 0 || MediaQuery.disableAnimationsOf(context)) {
      return settled;
    }

    return Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        // The digits change width as the count runs, which would make the
        // figure visibly grow — and, once the amount is wide enough for
        // [AmountText] to scale it down, visibly shrink as well. A same-width
        // stand-in holds the final width from the first frame.
        ExcludeSemantics(
          child: Opacity(
            opacity: 0,
            child: AmountText(_placeholder, scale: scale, color: color),
          ),
        ),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: amount.minorUnits),
          duration: duration + delay,
          // Fast off the mark and a long tail into the real figure, so the last
          // digits settle rather than snap.
          curve: Interval(_delayFraction, 1, curve: Curves.easeOutExpo),
          builder: (context, value, _) => AmountText(
            Money(value, amount.currency),
            scale: scale,
            color: color,
          ),
        ),
      ],
    );
  }

  /// The smallest amount with as many digits as this one.
  ///
  /// Under tabular figures that is exactly as wide as the real amount, and it
  /// is a different string — so it can never be mistaken for the figure itself,
  /// by a reader or by a test.
  Money get _placeholder {
    final digits = amount.minorUnits.toString().length;
    return Money(int.parse('1${'0' * (digits - 1)}'), amount.currency);
  }

  double get _delayFraction {
    final total = (duration + delay).inMicroseconds;
    if (total <= 0) return 0;
    return (delay.inMicroseconds / total).clamp(0.0, 0.9);
  }
}
