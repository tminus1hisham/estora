import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A primary button that shows a spinner while its action runs and refuses to
/// fire again until that action settles.
///
/// This is the client-side half of section 66: an idempotency key stops the
/// *server* from double-charging, and this stops the app from firing a second
/// request in the first place when an impatient tenant taps "Pay" twice.
class AsyncButton extends StatefulWidget {
  const AsyncButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
    this.tonal = false,
    this.expand = false,
    this.loadingLabel,
    super.key,
  });

  final String label;
  final IconData? icon;

  /// Null disables the button — used when a precondition is not met, e.g. a
  /// unit that is not AVAILABLE cannot be booked.
  final Future<void> Function()? onPressed;

  final bool enabled;
  final bool tonal;
  final bool expand;
  final String? loadingLabel;

  @override
  State<AsyncButton> createState() => _AsyncButtonState();
}

class _AsyncButtonState extends State<AsyncButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy || widget.onPressed == null) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled || widget.onPressed == null || _busy;

    final child = AnimatedSwitcher(
      duration: AppMotion.fast,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      child: _busy
          ? const SizedBox(
              key: ValueKey('busy'),
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 19),
                  Gap.w8,
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
    );

    final Widget button;
    if (widget.tonal) {
      button = FilledButton.tonal(
        onPressed: disabled ? null : _run,
        child: child,
      );
    } else {
      button = FilledButton(onPressed: disabled ? null : _run, child: child);
    }

    return Semantics(
      button: true,
      enabled: !disabled,
      label: _busy
          ? (widget.loadingLabel ?? '${widget.label}, in progress')
          : null,
      child: SizedBox(
        width: widget.expand ? double.infinity : null,
        child: button,
      ),
    );
  }
}
