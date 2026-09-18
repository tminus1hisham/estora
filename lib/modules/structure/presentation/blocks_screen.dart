import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/record_group.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../domain/entities/owner.dart';
import '../../../domain/entities/property.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../navigation/routes.dart';
import '../application/structure_controller.dart';

/// The wings a property is divided into.
///
/// A block is not decoration: it is what a unit number means. "SHOP-12" is
/// ambiguous across a mall and unambiguous inside East Wing, and the contract
/// models it that way — a block has its own lifecycle, its own floor count and
/// its own unit tally. Until this screen existed the app could read blocks but
/// never show or change them.
class BlocksScreen extends ConsumerWidget {
  const BlocksScreen({required this.propertyId, super.key});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(propertyBlocksProvider(propertyId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Blocks'),
        backgroundColor: Colors.transparent,
      ),
      body: switch (blocks) {
        AsyncLoading() when !blocks.hasValue => const AppSkeletonList(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () async {
            await ref
                .refresh(propertyBlocksProvider(propertyId).future)
                .then<void>((_) {});
          },
        ),
        _ => _BlockList(
          blocks: blocks.requireValue,
          propertyId: propertyId,
          onRefresh: () async {
            ref.invalidate(propertyOccupancyProvider(propertyId));
            await ref
                .refresh(propertyBlocksProvider(propertyId).future)
                .then<void>((_) {});
          },
        ),
      },
    );
  }
}

class _BlockList extends ConsumerWidget {
  const _BlockList({
    required this.blocks,
    required this.propertyId,
    required this.onRefresh,
  });

  final List<Building> blocks;
  final String propertyId;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One count of the property's units, split by block. While it is on its
    // way, or if it fails, the rows simply carry no figure — a block list
    // without percentages is still a block list.
    final occupancy = ref.watch(propertyOccupancyProvider(propertyId)).value;

    if (blocks.isEmpty) {
      return AppRefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.dashboard_outlined,
                title: 'No blocks yet',
                message:
                    'Wings or blocks set up for this property will appear '
                    'here, with their units inside them.',
              ),
            ),
          ],
        ),
      );
    }

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 96),
            children: [
              RecordGroup(
                heading:
                    '${blocks.length} '
                    '${blocks.length == 1 ? 'block' : 'blocks'}',
                children: [
                  for (final block in blocks)
                    RecordRow(
                      icon: Icons.dashboard_outlined,
                      iconColor: context.statusColors.resolve(
                        block.status.tone,
                      ),
                      title: block.name,
                      subtitle: block.shapeLabel.isEmpty
                          ? block.description
                          : block.shapeLabel,
                      amount: switch (occupancy?.forBlock(block.id)) {
                        final UnitMix mix when !mix.isEmpty => _Percent(
                          mix: mix,
                        ),
                        _ => null,
                      },
                      caption: switch (occupancy?.forBlock(block.id)) {
                        final UnitMix mix when !mix.isEmpty =>
                          mix.occupancyLabel,
                        _ => null,
                      },
                      footnote: block.status == BlockStatus.active
                          ? null
                          : StatusChip(
                              label: block.status.label,
                              tone: block.status.tone,
                              dense: true,
                            ),
                      onTap: () => context.pushNamed(
                        Routes.blockDetail,
                        pathParameters: {'blockId': block.id},
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The block's occupancy figure, in the row's amount slot.
///
/// Medium weight and tabular, the way [AmountText] sets money: a percentage
/// beside a percentage should line up, and neither should shout.
class _Percent extends StatelessWidget {
  const _Percent({required this.mix});

  final UnitMix mix;

  @override
  Widget build(BuildContext context) => Text(
    '${mix.occupancyPercent}% let',
    textAlign: TextAlign.end,
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: AppTypography.medium,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}
