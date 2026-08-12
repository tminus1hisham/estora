import 'package:flutter/material.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';

/// Shared chrome for the five auth screens in section 77.
///
/// Constrains its width so the forms stay readable when the app is run on a
/// tablet, desktop or a browser window, rather than stretching a phone layout
/// across 1400 pixels.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.failure,
    this.onDismissFailure,
    this.showBackButton = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Failure? failure;
  final VoidCallback? onDismissFailure;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: showBackButton && Navigator.canPop(context),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.storefront_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  Gap.h24,
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    Gap.h8,
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (failure != null) ...[
                    Gap.h16,
                    _FailureBanner(
                      failure: failure!,
                      onDismiss: onDismissFailure,
                    ),
                  ],
                  Gap.h24,
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failure, this.onDismiss});

  final Failure failure;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: scheme.onErrorContainer,
          ),
          Gap.w12,
          Expanded(
            child: Text(
              failure.message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
              visualDensity: VisualDensity.compact,
              color: scheme.onErrorContainer,
            ),
        ],
      ),
    );
  }
}
