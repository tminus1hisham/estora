import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Gives a surface a physical response to being touched: it sinks slightly
/// under the finger and springs back on release.
///
/// Wraps a card rather than replacing its tap handling. The press is driven
/// from raw pointer events rather than a second [GestureDetector] so it never
/// competes with the [InkWell] inside for the gesture arena — the ripple and
/// the navigation stay where they were, and this only adds the depth.
class AppPressable extends StatefulWidget {
  const AppPressable({
    required this.child,
    this.scale = 0.977,
    this.enabled = true,
    super.key,
  });

  final Widget child;

  /// How far the surface sinks. Deliberately shallow — a card is heavy, and a
  /// large card that shrinks by a tenth reads as a button, not as a panel.
  final double scale;

  final bool enabled;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        // Down quickly, back slowly: a slow press feels unresponsive, and a
        // fast release feels brittle.
        duration: _pressed ? AppMotion.instant : AppMotion.standard,
        curve: _pressed ? AppMotion.exit : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
