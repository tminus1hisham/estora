import 'package:flutter/material.dart';

import 'app_palette.dart';

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
    positive: AppPalette.green700,
    progress: AppPalette.blue700,
    warning: AppPalette.brass700,
    danger: AppPalette.red700,
    info: AppPalette.violet700,
    neutral: AppPalette.stone600,
  );

  static const StatusColors dark = StatusColors(
    positive: AppPalette.green300,
    progress: AppPalette.blue300,
    warning: AppPalette.brass200,
    danger: AppPalette.red300,
    info: AppPalette.violet300,
    neutral: AppPalette.stone300,
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
