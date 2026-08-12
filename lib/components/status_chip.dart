import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/status_palette.dart';

/// A status badge.
///
/// Every status the spec defines (section 81) renders through this one widget,
/// so a lease that is PENDING_SIGNATURE and an invoice that is OVERDUE are
/// styled by the same rules. Callers pass a label and a [StatusTone]; the
/// domain enums know their own tone.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.tone,
    this.icon,
    this.dense = false,
    super.key,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = context.statusColors.resolve(tone);
    final textScaler = MediaQuery.textScalerOf(context);
    final largeText = textScaler.scale(dense ? 11 : 12) >= 18;
    final iconSize = dense ? 12.0 : 14.0;

    final labelText = Text(
      label,
      softWrap: true,
      style: TextStyle(
        color: color,
        fontSize: dense ? 11 : 12,
        height: 1.15,
        fontWeight: AppTypography.bold,
        letterSpacing: 0.15,
      ),
    );

    return Semantics(
      label: 'Status: $label',
      container: true,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 9 : 11,
          vertical: dense ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: icon == null
            ? labelText
            : largeText
            ? Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpace.xs,
                runSpacing: AppSpace.xs,
                children: [
                  Icon(icon, size: iconSize, color: color),
                  labelText,
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: iconSize, color: color),
                  Gap.w4,
                  Flexible(child: labelText),
                ],
              ),
      ),
    );
  }
}
