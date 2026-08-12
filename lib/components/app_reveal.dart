import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/app_theme.dart';

/// Fades and lifts its child into place once, on first build.
///
/// Used to give a screen's contents an order of arrival instead of having
/// everything appear at once. [index] staggers an item against its siblings;
/// see [AppMotion.stagger] for why the delay is capped.
///
/// The animation is deliberately one-shot. A repeating animation would never
/// let the widget tree go idle, which would hang `pumpAndSettle` in the widget
/// tests.
class AppReveal extends StatelessWidget {
  const AppReveal({
    required this.child,
    this.index = 0,
    this.delay,
    this.offset = AppMotion.enterOffset,
    super.key,
  });

  /// Position in a group, used to stagger arrival. Ignored when [delay] is set.
  final int index;

  /// An explicit delay, overriding the one derived from [index].
  final Duration? delay;

  /// How far the child rises while fading in. Pass 0 for a pure fade.
  final double offset;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Someone who has asked the platform for reduced motion gets the finished
    // state directly — not a faster version of the animation.
    if (MediaQuery.disableAnimationsOf(context)) return child;

    // moveY, not slideY: slide works in fractions of the child's own height,
    // which would make a tall card travel further than a short one. The
    // distance should be the same for everything arriving together.
    return child
        .animate(delay: delay ?? AppMotion.stagger(index))
        .fadeIn(duration: AppMotion.standard, curve: AppMotion.enter)
        .moveY(
          begin: offset,
          end: 0,
          duration: AppMotion.standard,
          curve: AppMotion.enter,
        );
  }
}

/// Applies [AppReveal] to each child in order.
///
/// Saves threading an index through a column by hand, which is where the
/// stagger usually goes wrong.
List<Widget> revealAll(List<Widget> children, {int startIndex = 0}) {
  return List<Widget>.generate(
    children.length,
    (i) => AppReveal(index: startIndex + i, child: children[i]),
  );
}
