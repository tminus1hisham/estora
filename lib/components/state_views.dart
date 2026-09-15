import 'dart:async';

import 'package:flutter/material.dart';

import '../core/error/failure.dart';
import '../core/theme/app_theme.dart';
import 'app_brand_mark.dart';
import 'app_refresh_indicator.dart';

/// Full-screen loading indicator.
class LoadingView extends StatelessWidget {
  const LoadingView({this.message, this.compact = false, super.key});

  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: message ?? 'Loading',
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? AppSpace.lg : AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (compact)
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 68,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary.withValues(alpha: 0.72),
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                    const AppBrandMark(size: 44),
                  ],
                ),
              if (message != null) ...[
                Gap.h16,
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: AppTypography.medium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders a [Failure] with an optional retry.
///
/// The failure type drives the icon and whether retrying makes sense: a
/// [ValidationFailure] or [ForbiddenFailure] will not resolve itself by trying
/// again, so no retry button is offered.
class ErrorView extends StatelessWidget {
  const ErrorView({required this.failure, this.onRetry, super.key});

  final Failure failure;
  final FutureOr<void> Function()? onRetry;

  bool get _isRetryable => switch (failure) {
    NetworkFailure() || ServerFailure() || UnknownFailure() => true,
    _ => false,
  };

  IconData get _icon => switch (failure) {
    NetworkFailure() => Icons.wifi_off_rounded,
    UnauthorizedFailure() => Icons.lock_outline_rounded,
    ForbiddenFailure() => Icons.block_rounded,
    NotFoundFailure() => Icons.search_off_rounded,
    UnsupportedFeatureFailure() => Icons.info_outline_rounded,
    ValidationFailure() => Icons.error_outline_rounded,
    ConflictFailure() => Icons.sync_problem_rounded,
    ServerFailure() || UnknownFailure() => Icons.cloud_off_rounded,
  };

  String get _title => switch (failure) {
    NetworkFailure() => 'You are offline',
    UnauthorizedFailure() => 'Sign-in required',
    ForbiddenFailure() => 'Access unavailable',
    NotFoundFailure() => 'Nothing found here',
    UnsupportedFeatureFailure() => 'Feature unavailable',
    ValidationFailure() => 'Check the details',
    ConflictFailure() => 'Something changed',
    ServerFailure() || UnknownFailure() => 'We hit a snag',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: 28, color: scheme.onErrorContainer),
            ),
            Gap.h16,
            Text(
              _title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Gap.h8,
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (onRetry != null && _isRetryable) ...[
              Gap.h24,
              FilledButton.tonalIcon(
                onPressed: () => AppRefreshIndicator.refresh(context, onRetry!),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
    if (Scrollable.maybeOf(context) != null) return content;
    if (AppRefreshIndicator.contains(context)) {
      return RefreshPlaceholder(child: content);
    }
    if (onRetry != null) {
      return AppRefreshIndicator(
        onRefresh: onRetry!,
        child: RefreshPlaceholder(child: content),
      );
    }
    return content;
  }
}

/// Shown when a list has no items.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.onRefresh,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final FutureOr<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: scheme.onPrimaryContainer),
            ),
            Gap.h16,
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: AppTypography.bold),
            ),
            if (message != null) ...[
              Gap.h8,
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[Gap.h24, action!],
          ],
        ),
      ),
    );
    if (Scrollable.maybeOf(context) != null) return content;
    if (AppRefreshIndicator.contains(context)) {
      return RefreshPlaceholder(child: content);
    }
    if (onRefresh != null) {
      return AppRefreshIndicator(
        onRefresh: onRefresh!,
        child: RefreshPlaceholder(child: content),
      );
    }
    return content;
  }
}
