import 'dart:async';

import 'package:flutter/material.dart';

/// Live countdown to [expiresAt].
///
/// Section 23 makes booking expiry automatic and server-driven: a background
/// worker flips the booking to EXPIRED. This widget only *displays* the time
/// remaining — reaching zero here does not change any state. It calls
/// [onExpired] so the screen can re-fetch and show whatever the server decided,
/// which is the only authority on whether the booking actually expired.
class CountdownTimer extends StatefulWidget {
  const CountdownTimer({
    required this.expiresAt,
    required this.builder,
    this.onExpired,
    this.tick = const Duration(seconds: 1),
    super.key,
  });

  final DateTime expiresAt;

  /// Receives the remaining duration, clamped at zero.
  final Widget Function(BuildContext context, Duration remaining) builder;

  /// Fired once, when the countdown first reaches zero.
  final VoidCallback? onExpired;

  final Duration tick;

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  Timer? _timer;
  late Duration _remaining;
  bool _notifiedExpiry = false;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    if (_remaining > Duration.zero) {
      _timer = Timer.periodic(widget.tick, (_) => _onTick());
    } else {
      _scheduleExpiryCallback();
    }
  }

  @override
  void didUpdateWidget(CountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _notifiedExpiry = false;
      _timer?.cancel();
      _remaining = _computeRemaining();
      if (_remaining > Duration.zero) {
        _timer = Timer.periodic(widget.tick, (_) => _onTick());
      } else {
        _scheduleExpiryCallback();
      }
    }
  }

  Duration _computeRemaining() {
    final remaining = widget.expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _onTick() {
    if (!mounted) return;
    final remaining = _computeRemaining();
    setState(() => _remaining = remaining);

    if (remaining == Duration.zero) {
      _timer?.cancel();
      _scheduleExpiryCallback();
    }
  }

  /// Deferred so [onExpired] never fires during a build, which would be illegal
  /// if the callback triggers a provider refresh.
  void _scheduleExpiryCallback() {
    if (_notifiedExpiry || widget.onExpired == null) return;
    _notifiedExpiry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onExpired!();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _remaining);
}
