import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/amount_text.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/record_group.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../domain/entities/property.dart';
import '../../../domain/entities/unit.dart';
import '../../../navigation/routes.dart';
import '../application/structure_controller.dart';

/// One block, and the units inside it.
class BlockScreen extends ConsumerWidget {
  const BlockScreen({required this.blockId, super.key});

  final String blockId;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Building block,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${block.name}?'),
        content: const Text(
          'The block is removed from the property. Units inside it have to be '
          'moved or removed first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(structureActionsProvider)
        .deleteBlock(blockId: block.id, propertyId: block.propertyId);
    if (!context.mounted) return;

    switch (result) {
      case Ok():
        Navigator.of(context).pop();
      case Err(:final failure):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final block = ref.watch(blockProvider(blockId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(block.hasValue ? block.requireValue.name : 'Block'),
        backgroundColor: Colors.transparent,
        actions: [
          if (block.hasValue)
            PopupMenuButton<String>(
              onSelected: (action) => switch (action) {
                'edit' => context.pushNamed(
                  Routes.blockEdit,
                  pathParameters: {'blockId': blockId},
                ),
                _ => _confirmDelete(context, ref, block.requireValue),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit block')),
                PopupMenuItem(value: 'delete', child: Text('Remove block')),
              ],
            ),
        ],
      ),
      floatingActionButton: block.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => context.pushNamed(
                Routes.unitCreate,
                pathParameters: {'propertyId': block.requireValue.propertyId},
                queryParameters: {'blockId': blockId},
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add unit'),
            )
          : null,
      body: switch (block) {
        AsyncLoading() when !block.hasValue => const AppSkeletonList(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(blockProvider(blockId)),
        ),
        _ => _BlockBody(block: block.requireValue),
      },
    );
  }
}

class _BlockBody extends ConsumerWidget {
  const _BlockBody({required this.block});

  final Building block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(blockUnitsProvider(block.id));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(blockProvider(block.id));
        ref.invalidate(blockUnitsProvider(block.id));
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 96),
            children: [
              SectionCard(
                title: 'The block',
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
                      value: '${_trim(block.totalArea!)} sq ft',
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
                  onRetry: () => ref.invalidate(blockUnitsProvider(block.id)),
                ),
                _ => _UnitList(units: units.requireValue),
              },
            ],
          ),
        ),
      ),
    );
  }

  static String _trim(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

class _UnitList extends StatelessWidget {
  const _UnitList({required this.units});

  final List<Unit> units;

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) {
      return const SectionCard(
        title: 'Units',
        children: [
          Text(
            'No units in this block yet. Add one to start letting space here.',
          ),
        ],
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
            onTap: () => context.pushNamed(
              Routes.unitEdit,
              pathParameters: {'unitId': unit.id},
            ),
          ),
      ],
    );
  }
}
