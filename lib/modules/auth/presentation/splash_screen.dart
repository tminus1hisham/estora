import 'package:flutter/material.dart';

import '../../../components/app_brand_mark.dart';
import '../../../core/theme/app_theme.dart';

/// Branded launch surface shown while the stored session is resolved.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Semantics(
        label: 'Estora is starting',
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primaryContainer.withValues(alpha: 0.42),
                scheme.surface,
                scheme.tertiaryContainer.withValues(alpha: 0.18),
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
          child: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: -120,
                  right: -100,
                  child: _Orb(
                    size: 320,
                    color: scheme.primary.withValues(alpha: 0.12),
                  ),
                ),
                Positioned(
                  bottom: -100,
                  left: -120,
                  child: _Orb(
                    size: 340,
                    color: scheme.tertiary.withValues(alpha: 0.08),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpace.xxl),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppBrandMark(size: 88, withShadow: true),
                          Gap.h24,
                          Text(
                            'Estora',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: AppTypography.extraBold,
                                  letterSpacing: -0.7,
                                ),
                          ),
                          Gap.h8,
                          Text(
                            'Your commercial space, all in one place.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          Gap.h32,
                          SizedBox(
                            width: 112,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              child: const LinearProgressIndicator(
                                minHeight: 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpace.xl,
                  right: AppSpace.xl,
                  bottom: AppSpace.xl,
                  child: Text(
                    'SECURE TENANT ACCESS',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
