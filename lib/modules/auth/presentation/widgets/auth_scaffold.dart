import 'package:flutter/material.dart';

import '../../../../components/app_brand_mark.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';

/// Shared responsive chrome for every authentication journey.
///
/// On compact screens the form is a calm, scrollable single column. On wider
/// screens it becomes a presentation-ready split layout with a dedicated brand
/// canvas. Both forms remain keyboard-safe and can grow with accessibility text
/// scaling without a fixed-height viewport.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.failure,
    this.onDismissFailure,
    this.showBackButton = true,
    this.eyebrow = 'Tenant Portal',
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Failure? failure;
  final VoidCallback? onDismissFailure;
  final bool showBackButton;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: _backgroundDecoration(context),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showBrandPanel = constraints.maxWidth >= 920;
              if (showBrandPanel) {
                return Row(
                  children: [
                    Flexible(
                      flex: 5,
                      child: _BrandPanel(maxWidth: constraints.maxWidth),
                    ),
                    Expanded(
                      flex: 6,
                      child: _FormViewport(
                        title: title,
                        subtitle: subtitle,
                        eyebrow: eyebrow,
                        failure: failure,
                        onDismissFailure: onDismissFailure,
                        showBackButton: showBackButton,
                        showBrandMark: false,
                        child: child,
                      ),
                    ),
                  ],
                );
              }

              return _FormViewport(
                title: title,
                subtitle: subtitle,
                eyebrow: eyebrow,
                failure: failure,
                onDismissFailure: onDismissFailure,
                showBackButton: showBackButton,
                showBrandMark: true,
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }

  BoxDecoration _backgroundDecoration(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: scheme.surface,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.primaryContainer.withValues(alpha: 0.22),
          scheme.surface,
          scheme.tertiaryContainer.withValues(alpha: 0.12),
        ],
        stops: const [0, 0.52, 1],
      ),
    );
  }
}

class _FormViewport extends StatelessWidget {
  const _FormViewport({
    required this.title,
    required this.child,
    required this.showBackButton,
    required this.showBrandMark,
    this.subtitle,
    this.eyebrow,
    this.failure,
    this.onDismissFailure,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget child;
  final Failure? failure;
  final VoidCallback? onDismissFailure;
  final bool showBackButton;
  final bool showBrandMark;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = AppLayout.pagePaddingFor(
          constraints.maxWidth,
        );
        const verticalPadding = AppSpace.xl;
        final availableHeight =
            constraints.maxHeight - verticalPadding - AppSpace.xxl;

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            verticalPadding,
            horizontalPadding,
            AppSpace.xxl,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: availableHeight < 0 ? 0.0 : availableHeight,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.maxFormWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showBackButton && canPop) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _BackButton(
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Gap.h24,
                    ],
                    if (showBrandMark) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: AppBrandMark(size: 56, withShadow: true),
                      ),
                      Gap.h24,
                    ],
                    if (eyebrow != null) ...[
                      Text(
                        eyebrow!.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: AppTypography.bold,
                          letterSpacing: 1.4,
                        ),
                      ),
                      Gap.h8,
                    ],
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: AppTypography.extraBold,
                            letterSpacing: -0.7,
                          ),
                    ),
                    if (subtitle != null) ...[
                      Gap.h8,
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        );
      },
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.maxWidth});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: ClipRRect(
        borderRadius: AppRadius.extraLarge,
        child: ColoredBox(
          color: isDark ? AppPalette.ink800 : AppPalette.ink950,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned(
                top: -110,
                right: -90,
                child: _AmbientOrb(size: 340, color: AppPalette.emerald700),
              ),
              const Positioned(
                bottom: -130,
                left: -100,
                child: _AmbientOrb(size: 380, color: AppPalette.brass500),
              ),
              Padding(
                padding: EdgeInsets.all(maxWidth >= 1200 ? 56 : 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppBrandMark(size: 64),
                    const Spacer(),
                    Text(
                      'Your space, managed with clarity.',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppPalette.stone0,
                        fontWeight: AppTypography.extraBold,
                      ),
                    ),
                    Gap.h16,
                    Text(
                      'Bookings, leases and payments in one secure place.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppPalette.stone200,
                      ),
                    ),
                    Gap.h32,
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: scheme.inversePrimary,
                          size: 20,
                        ),
                        Gap.w8,
                        Flexible(
                          child: Text(
                            'Secure tenant access',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: AppPalette.stone100),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0)],
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

    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Error: ${failure.message}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.md,
          AppSpace.sm,
          AppSpace.md,
        ),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: AppRadius.small,
          border: Border.all(color: scheme.error.withValues(alpha: 0.24)),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                  fontWeight: AppTypography.medium,
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: 'Dismiss error',
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                color: scheme.onErrorContainer,
              ),
          ],
        ),
      ),
    );
  }
}
