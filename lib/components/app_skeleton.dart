import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A subtle loading placeholder that respects the platform's reduced-motion
/// preference.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    required this.height,
    this.width = double.infinity,
    this.borderRadius = AppRadius.sm,
    this.shape = BoxShape.rectangle,
    super.key,
  });

  const AppSkeleton.circle({required double diameter, Key? key})
    : this(
        key: key,
        width: diameter,
        height: diameter,
        borderRadius: AppRadius.pill,
        shape: BoxShape.circle,
      );

  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.35;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final color = Color.lerp(
              scheme.surfaceContainerHigh,
              scheme.surfaceContainerHighest,
              _controller.value,
            );
            return SizedBox(
              width: widget.width,
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  shape: widget.shape,
                  borderRadius: widget.shape == BoxShape.rectangle
                      ? BorderRadius.circular(widget.borderRadius)
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A useful default skeleton for list-based screens.
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({this.itemCount = 4, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpace.lg),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, _) => Gap.h12,
      itemBuilder: (context, index) => const _SkeletonListItem(),
    );
  }
}

class _SkeletonListItem extends StatelessWidget {
  const _SkeletonListItem();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading item',
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: AppRadius.large,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeleton(width: 72, height: 72, borderRadius: AppRadius.md),
            Gap.w16,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeleton(height: 16),
                  Gap.h12,
                  FractionallySizedBox(
                    widthFactor: 0.68,
                    child: AppSkeleton(height: 12),
                  ),
                  Gap.h12,
                  FractionallySizedBox(
                    widthFactor: 0.42,
                    child: AppSkeleton(height: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
