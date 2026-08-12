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
///
/// Prefer this over a centred spinner. A spinner says "wait"; a skeleton says
/// what is about to arrive, so the screen does not visibly jump when it does.
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({this.itemCount = 4, this.header = false, super.key});

  final int itemCount;

  /// Reserves space for a summary banner above the list, matching the list
  /// screens that open with one.
  final bool header;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpace.lg),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount + (header ? 1 : 0),
      separatorBuilder: (_, _) => Gap.h12,
      itemBuilder: (context, index) {
        if (header && index == 0) return const _SkeletonBanner();
        return const _SkeletonListItem();
      },
    );
  }
}

/// Placeholder for a media-led card: image, then a title and two lines.
///
/// Used by the browse screens, where the real card leads with a photograph and
/// a spinner would give no hint of that shape.
class AppSkeletonMediaList extends StatelessWidget {
  const AppSkeletonMediaList({this.itemCount = 3, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpace.lg),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, _) => Gap.h16,
      itemBuilder: (context, index) => const _SkeletonMediaItem(),
    );
  }
}

/// Placeholder for a detail screen: a hero block, then grouped rows.
class AppSkeletonDetail extends StatelessWidget {
  const AppSkeletonDetail({this.heroHeight = 132, super.key});

  final double heroHeight;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        AppSkeleton(height: heroHeight, borderRadius: AppRadius.lg),
        Gap.h24,
        const _SkeletonRows(count: 4),
        Gap.h24,
        const _SkeletonRows(count: 3),
      ],
    );
  }
}

class _SkeletonBanner extends StatelessWidget {
  const _SkeletonBanner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading summary',
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
          children: [
            AppSkeleton(width: 44, height: 44, borderRadius: AppRadius.md),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeleton(height: 16),
                  Gap.h8,
                  FractionallySizedBox(
                    widthFactor: 0.55,
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

class _SkeletonMediaItem extends StatelessWidget {
  const _SkeletonMediaItem();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading item',
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: AppRadius.large,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AspectRatio(
              aspectRatio: 16 / 7.5,
              child: AppSkeleton(height: double.infinity, borderRadius: 0),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FractionallySizedBox(
                    widthFactor: 0.62,
                    child: AppSkeleton(height: 16),
                  ),
                  Gap.h12,
                  const FractionallySizedBox(
                    widthFactor: 0.4,
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

class _SkeletonRows extends StatelessWidget {
  const _SkeletonRows({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: AppRadius.large,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) Gap.h16,
            Row(
              children: [
                const Expanded(flex: 4, child: AppSkeleton(height: 12)),
                Gap.w24,
                const Expanded(flex: 3, child: AppSkeleton(height: 12)),
              ],
            ),
          ],
        ],
      ),
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
