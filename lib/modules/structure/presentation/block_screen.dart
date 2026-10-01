import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/amount_text.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/occupancy_meter.dart';
import '../../../components/record_group.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../components/unit_status_strip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../domain/entities/owner.dart';
import '../../../domain/entities/property.dart';
import '../../../domain/entities/unit.dart';
import '../application/structure_controller.dart';

/// One block, and the units inside it.
class BlockScreen extends ConsumerWidget {
  const BlockScreen({required this.blockId, super.key});

  final String blockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final block = ref.watch(blockProvider(blockId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(block.hasValue ? block.requireValue.name : 'Block'),
        backgroundColor: Colors.transparent,
      ),
      body: switch (block) {
        AsyncLoading() when !block.hasValue => const AppSkeletonList(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () async {
            await ref.refresh(blockProvider(blockId).future).then<void>((_) {});
          },
        ),
        _ => _BlockBody(block: block.requireValue),
      },
    );
  }
}

/// The same block and its units, raised over the property screen.
Future<void> showBlockSheet(BuildContext context, String blockId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 1,
        builder: (context, controller) => Consumer(
          builder: (context, ref, _) {
            final block = ref.watch(blockProvider(blockId));
            return switch (block) {
              AsyncLoading() when !block.hasValue => const AppSkeletonList(),
              AsyncError(:final error) => ErrorView(
                failure: error is Failure
                    ? error
                    : UnknownFailure(error.toString()),
                onRetry: () async {
                  await ref
                      .refresh(blockProvider(blockId).future)
                      .then<void>((_) {});
                },
              ),
              _ => _BlockBody(
                block: block.requireValue,
                controller: controller,
              ),
            };
          },
        ),
      ),
    );

class _BlockBody extends ConsumerWidget {
  const _BlockBody({required this.block, this.controller});

  final Building block;

  /// Set when the body sits in [showBlockSheet], which drags by it.
  final ScrollController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(blockUnitsProvider(block.id));

    return AppRefreshIndicator(
      onRefresh: () async {
        await ref.refresh(blockProvider(block.id).future).then<void>((_) {});
        await ref
            .refresh(blockUnitsProvider(block.id).future)
            .then<void>((_) {});
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              Gap.lg,
              controller == null ? Gap.sm : 0,
              Gap.lg,
              controller == null ? 96 : Gap.xl,
            ),
            children: [
              SectionCard(
                title: controller == null ? 'The block' : block.name,
                trailing: StatusChip(
                  label: block.status.label,
                  tone: block.status.tone,
                  dense: true,
                ),
                children: [
                  if (block.description != null &&
                      block.description!.isNotEmpty) ...[
                    Text(block.description!),
                    Gap.h12,
                  ],
                  if (block.numberOfFloors != null)
                    DetailRow(
                      label: 'Floors',
                      value: '${block.numberOfFloors}',
                    ),
                  if (block.totalArea != null)
                    DetailRow(
                      label: 'Total area',
                      value: '${formatArea(block.totalArea!)} sq ft',
                    ),
                  if (block.totalUnits != null)
                    DetailRow(label: 'Units', value: '${block.totalUnits}'),
                  if (block.leasableUnits != null)
                    DetailRow(
                      label: 'Leasable units',
                      value: '${block.leasableUnits}',
                    ),
                ],
              ),
              Gap.h12,
              switch (units) {
                AsyncLoading() when !units.hasValue => const AppSkeletonList(),
                AsyncError(:final error) => ErrorView(
                  failure: error is Failure
                      ? error
                      : UnknownFailure(error.toString()),
                  onRetry: () async {
                    await ref
                        .refresh(blockUnitsProvider(block.id).future)
                        .then<void>((_) {});
                  },
                ),
                _ => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (units.requireValue.isNotEmpty) ...[
                      _Occupancy(mix: UnitMix.of(units.requireValue)),
                      Gap.h12,
                    ],
                    _UnitList(units: units.requireValue),
                  ],
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

/// How much of the block is let, counted from the units listed beneath it —
/// the same records, so the figure and the list cannot disagree.
class _Occupancy extends StatelessWidget {
  const _Occupancy({required this.mix});

  final UnitMix mix;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Occupancy',
    children: [
      OccupancyMeter(mix: mix, label: 'Units let'),
      Gap.h16,
      UnitStatusStrip(mix: mix),
    ],
  );
}

class _UnitList extends StatelessWidget {
  const _UnitList({required this.units});

  final List<Unit> units;

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) {
      return const SectionCard(
        title: 'Units',
        children: [Text('No units in this block yet.')],
      );
    }

    return RecordGroup(
      heading: '${units.length} ${units.length == 1 ? 'unit' : 'units'}',
      children: [
        for (final unit in units)
          RecordRow(
            icon: Icons.grid_view_rounded,
            iconColor: context.statusColors.resolve(unit.status.tone),
            title: unit.unitNumber,
            subtitle: [
              unit.category.label,
              if (unit.areaLabel != null) unit.areaLabel!,
            ].join(' · '),
            amount: AmountText(unit.baseRent, align: TextAlign.end),
            caption: unit.status.label,
          ),
      ],
    );
  }
}
