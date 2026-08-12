import 'package:flutter/material.dart';

import '../core/error/failure.dart';
import '../core/theme/app_theme.dart';

/// Full-screen loading indicator.
class LoadingView extends StatelessWidget {
  const LoadingView({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            Gap.h16,
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
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
  final VoidCallback? onRetry;

  bool get _isRetryable => switch (failure) {
    NetworkFailure() || ServerFailure() || UnknownFailure() => true,
    _ => false,
  };

  IconData get _icon => switch (failure) {
    NetworkFailure() => Icons.wifi_off_rounded,
    UnauthorizedFailure() => Icons.lock_outline_rounded,
    ForbiddenFailure() => Icons.block_rounded,
    NotFoundFailure() => Icons.search_off_rounded,
    ValidationFailure() => Icons.error_outline_rounded,
    ConflictFailure() => Icons.sync_problem_rounded,
    ServerFailure() || UnknownFailure() => Icons.cloud_off_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 48, color: scheme.error),
            Gap.h16,
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null && _isRetryable) ...[
              Gap.h24,
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when a list has no items.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.onSurfaceVariant),
            Gap.h16,
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
  }
}
