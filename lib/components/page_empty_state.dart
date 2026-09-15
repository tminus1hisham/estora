import 'package:flutter/material.dart';

import 'app_refresh_indicator.dart';

/// A spacious, refreshable introduction for pages awaiting their first record.
class PageEmptyState extends StatelessWidget {
  const PageEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.caption,
    this.action,
    this.onRefresh,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String caption;
  final Widget? action;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final content = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 40,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: scheme.outlineVariant),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [scheme.primaryContainer, scheme.surface],
                        ),
                      ),
                      child: Icon(icon, size: 48, color: scheme.primary),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      caption.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(height: 28),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return onRefresh == null
        ? content
        : AppRefreshIndicator(onRefresh: onRefresh!, child: content);
  }
}
