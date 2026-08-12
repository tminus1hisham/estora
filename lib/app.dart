import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'navigation/app_router.dart';

/// The tenant application root.
class MallApp extends ConsumerWidget {
  const MallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Tenant Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) {
        // Android and iOS are the targets, but the app is developed and
        // demonstrated on desktop and web where there is no such constraint.
        // Capping the width keeps the layout honest to the phone it is designed
        // for instead of stretching a mobile layout across a wide window.
        final content = child ?? const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < AppLayout.compactBreakpoint) {
              return content;
            }

            final scheme = Theme.of(context).colorScheme;
            return ColoredBox(
              color: scheme.surfaceContainerHigh,
              child: SafeArea(
                minimum: const EdgeInsets.all(AppSpace.xl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: AppRadius.extraLarge,
                        border: Border.all(color: scheme.outlineVariant),
                        boxShadow: AppElevation.soft(scheme.shadow),
                      ),
                      child: ClipRRect(
                        borderRadius: AppRadius.extraLarge,
                        child: content,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
