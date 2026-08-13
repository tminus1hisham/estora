import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/money.dart';
import 'money_text.dart';

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
    this.style,
    this.color,
    this.duration = const Duration(milliseconds: 900),
    this.delay = Duration.zero,
    super.key,
  });

  final Money amount;
  final TextStyle? style;
  final Color? color;
  final Duration duration;

  /// Held on the starting value for this long before counting. Used to let the
  /// surface the figure sits on arrive first.
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final settled = MoneyText(amount, style: style, color: color);

    // Nothing to count from, or nothing that should move.
    if (amount.minorUnits <= 0 || MediaQuery.disableAnimationsOf(context)) {
      return settled;
    }

    // The digits change width as the count runs, which would make the figure
    // visibly grow — and, once the amount is wide enough for [MoneyText] to
    // scale it down, visibly shrink as well. A zeroed copy of the final string
    // holds the final width from the first frame. It is a different string, so
    // it is not mistaken for the amount itself; under tabular figures it is
    // exactly as wide.
    final placeholder = amount.format().replaceAll(RegExp(r'\d'), '0');

    return Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        ExcludeSemantics(
          child: Opacity(
            opacity: 0,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                placeholder,
                maxLines: 1,
                style: (style ?? _defaultStyle(context))?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: amount.minorUnits),
          duration: duration + delay,
          // Fast off the mark and a long tail into the real figure, so the last
          // digits settle rather than snap.
          curve: Interval(_delayFraction, 1, curve: Curves.easeOutExpo),
          builder: (context, value, _) => MoneyText(
            Money(value, amount.currency),
            style: style,
            color: color,
          ),
        ),
      ],
    );
  }

  double get _delayFraction {
    final total = (duration + delay).inMicroseconds;
    if (total <= 0) return 0;
    return (delay.inMicroseconds / total).clamp(0.0, 0.9);
  }

  TextStyle? _defaultStyle(BuildContext context) => Theme.of(
    context,
  ).textTheme.bodyLarge?.copyWith(fontWeight: AppTypography.bold);
}
