import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Consistent answer-first heading for feature pages and major sections.
class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.leading,
    this.trailing,
    this.compact = false,
    super.key,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: AppTypography.bold,
              letterSpacing: 1.2,
            ),
          ),
          Gap.h8,
        ],
        Text(
          title,
          style:
              (compact
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.headlineMedium)
                  ?.copyWith(fontWeight: AppTypography.bold),
        ),
        if (subtitle != null) ...[
          Gap.h8,
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[leading!, Gap.w12],
        Expanded(child: copy),
        if (trailing != null) ...[Gap.w12, trailing!],
      ],
    );
  }
}
