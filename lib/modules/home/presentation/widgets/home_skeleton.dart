import 'package:flutter/material.dart';

import '../../../../components/app_skeleton.dart';
import '../../../../core/theme/app_theme.dart';
import 'home_top_bar.dart';

/// The home screen's shape before its data arrives.
///
/// Matches the real layout — a full-bleed header, the balance card overlapping
/// it, the action row, the pair of tiles — so nothing jumps when the summary
/// lands. A spinner would say "wait"; this says what is coming.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final headerHeight = topInset + HomeTopBar.height + 132;

    return Semantics(
      label: 'Loading your home screen',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSkeleton(height: headerHeight, borderRadius: 0),
          Transform.translate(
            offset: const Offset(0, -_overlap),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: Gap.lg),
              child: AppSkeleton(height: 232, borderRadius: AppRadius.lg),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.lg),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) Gap.w16,
                  const Expanded(
                    child: AppSkeleton(height: 52, borderRadius: AppRadius.md),
                  ),
                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Gap.lg),
            child: Row(
              children: [
                Expanded(
                  child: AppSkeleton(height: 148, borderRadius: AppRadius.lg),
                ),
                Gap.w12,
                Expanded(
                  child: AppSkeleton(height: 148, borderRadius: AppRadius.lg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Matches the overlap the real balance card is drawn with.
  static const double _overlap = 28;
}
