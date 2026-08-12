import 'package:flutter/material.dart';

/// Semantic tone for a status badge.
///
/// The theme layer deliberately does not know about `BookingStatus`,
/// `LeaseStatus` and friends — that would couple presentation to the domain and
/// force this file to change every time the spec adds a state. Instead each
/// domain enum maps itself to a [StatusTone], and this palette decides what a
/// tone looks like. One place to restyle, no domain import.
enum StatusTone {
  /// Terminal and good: PAID, ACTIVE, SUCCESS.
  positive,

  /// In flight: PENDING, PROCESSING, PENDING_SIGNATURE.
  progress,

  /// Needs attention soon: EXPIRING, PARTIALLY_PAID, DRAFT.
  warning,

  /// Bad: OVERDUE, FAILED, REJECTED, TERMINATED.
  danger,

  /// Informational: CONVERTED_TO_LEASE, ISSUED.
  info,

  /// Inert: EXPIRED, CANCELLED, VOID, ARCHIVED.
  neutral,
}

/// Foreground/background pair for a status badge.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.positive,
    required this.progress,
    required this.warning,
    required this.danger,
    required this.info,
    required this.neutral,
  });

  final Color positive;
  final Color progress;
  final Color warning;
  final Color danger;
  final Color info;
  final Color neutral;

  static const StatusColors light = StatusColors(
    positive: Color(0xFF1B7A45),
    progress: Color(0xFF1F5FAE),
    warning: Color(0xFF9A6206),
    danger: Color(0xFFB3261E),
    info: Color(0xFF4A4FA8),
    neutral: Color(0xFF5A6070),
  );

  static const StatusColors dark = StatusColors(
    positive: Color(0xFF6FD79B),
    progress: Color(0xFF8FB9F5),
    warning: Color(0xFFE8B860),
    danger: Color(0xFFF2B8B5),
    info: Color(0xFFB4B7F0),
    neutral: Color(0xFFB2B8C6),
  );

  Color resolve(StatusTone tone) => switch (tone) {
    StatusTone.positive => positive,
    StatusTone.progress => progress,
    StatusTone.warning => warning,
    StatusTone.danger => danger,
    StatusTone.info => info,
    StatusTone.neutral => neutral,
  };

  @override
  StatusColors copyWith({
    Color? positive,
    Color? progress,
    Color? warning,
    Color? danger,
    Color? info,
    Color? neutral,
  }) {
    return StatusColors(
      positive: positive ?? this.positive,
      progress: progress ?? this.progress,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      positive: Color.lerp(positive, other.positive, t)!,
      progress: Color.lerp(progress, other.progress, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
    );
  }
}

extension StatusColorsContext on BuildContext {
  StatusColors get statusColors =>
      Theme.of(this).extension<StatusColors>() ?? StatusColors.light;
}
