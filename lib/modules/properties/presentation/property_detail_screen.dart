import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_bottom_action_bar.dart';
import '../../../components/app_media.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/amount_text.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/occupancy_meter.dart';
import '../../../components/record_group.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../domain/entities/owner.dart';
import '../../../domain/entities/unit.dart';
import '../../../navigation/routes.dart';
import '../../structure/application/structure_controller.dart';
import '../../structure/presentation/block_screen.dart';
import '../../units/application/unit_controller.dart';
import '../application/property_controller.dart';

/// A photography-led overview of a property and its available inventory.
class PropertyDetailScreen extends ConsumerWidget {
  const PropertyDetailScreen({
    required this.propertyId,
    this.manager = false,
    super.key,
  });

  final String propertyId;
  final bool manager;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(propertyDetailProvider(propertyId));
    final availability = ref.watch(availabilityProvider);
    // The engine's count is what can be booked today; the property payload's
    // own figure stands in only until the engine has answered.
    final available =
        availability.value?.forProperty(propertyId).count ??
        detail.value?.property.availableUnits;

    return Scaffold(
      // Once loaded, the photograph is the app bar: see [_Body].
      appBar: detail.hasValue ? null : AppBar(title: const Text('Property')),
      body: AppRefreshIndicator(
        onRefresh: () async {
          if (manager) {
            ref
              ..invalidate(propertyUnitsProvider(propertyId))
              ..invalidate(propertyBlocksProvider(propertyId));
          }
          await Future.wait<void>([
            ref
                .refresh(propertyDetailProvider(propertyId).future)
                .then<void>((_) {}),
            ref.read(availabilityProvider.notifier).refresh(),
          ]);
        },
        child: switch (detail) {
          AsyncLoading() when !detail.hasValue => const LoadingView(),
          AsyncError(:final error) => ErrorView(
            failure: error is Failure
                ? error
                : UnknownFailure(error.toString()),
            onRetry: () async {
              await ref
                  .refresh(propertyDetailProvider(propertyId).future)
                  .then<void>((_) {});
            },
          ),
          _ => _Body(
            detail: detail.requireValue,
            manager: manager,
            available: available,
          ),
        },
      ),
      // The owner's blocks open in place, on this screen. A tenant's next
      // step is a conversation, not a transaction: they tell the landlord
      // what they are after and nothing is booked or paid on the way.
      bottomNavigationBar: detail.hasValue && !manager
          ? AppBottomActionBar(
              child: FilledButton.icon(
                onPressed: () => context.pushNamed(
                  Routes.enquiry,
                  pathParameters: {'propertyId': propertyId},
                ),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Send enquiry'),
              ),
            )
          : null,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.detail,
    required this.manager,
    required this.available,
  });

  final PropertyDetail detail;
  final bool manager;
  final int? available;

  @override
  Widget build(BuildContext context) {
    final property = detail.property;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Edge to edge and under the status bar, like the tenant home, with
        // the owner home's curved foot. It folds into a plain bar on scroll.
        SliverAppBar(
          pinned: true,
          expandedHeight: 200,
          automaticallyImplyLeading: false,
          leading: Navigator.canPop(context)
              ? Padding(
                  padding: const EdgeInsets.all(Gap.sm),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppPalette.navy950.withValues(alpha: 0.36),
                      shape: BoxShape.circle,
                    ),
                    child: const BackButton(color: Colors.white),
                  ),
                )
              : null,
          backgroundColor: theme.scaffoldBackgroundColor,
          flexibleSpace: LayoutBuilder(
            builder: (context, constraints) => AnnotatedRegion(
              // Light icons over the photograph, the theme's own once folded.
              value: constraints.maxHeight > kToolbarHeight + topInset + Gap.lg
                  ? SystemUiOverlayStyle.light
                  : theme.brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              child: FlexibleSpaceBar(
                background: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.elliptical(44, 36),
                  ),
                  child: AppMedia(
                    source: property.imageUrl,
                    aspectRatio: null,
                    heroTag: 'property-${property.id}',
                    semanticLabel: '${property.name} property',
                    fallbackIcon: Icons.location_city_rounded,
                    overlay: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppGradients.headerVeil,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xl),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      property.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Gap.w12,
                  StatusChip(
                    label: property.status.label,
                    tone: property.status.tone,
                    dense: true,
                  ),
                ],
              ),
              Gap.h4,
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  Gap.w8,
                  Expanded(
                    child: Text(
                      property.locationLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (property.description != null) ...[
                Gap.h8,
                Text(
                  property.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              Gap.h12,
              // Equal heights, so a label that wraps does not stagger the row.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.meeting_room_outlined,
                        value: property.totalUnits?.toString() ?? '—',
                        label: 'Total units',
                        highlighted: true,
                      ),
                    ),
                    Gap.w8,
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.domain_outlined,
                        value: available?.toString() ?? '—',
                        label: 'Available units',
                      ),
                    ),
                    if (property.totalArea != null) ...[
                      Gap.w8,
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.square_foot_rounded,
                          value: formatArea(
                            property.totalArea!.roundToDouble(),
                          ),
                          label: 'Square feet',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (manager) ...[
                Gap.h8,
                _OccupancySection(
                  propertyId: property.id,
                  fallback: property.mix,
                ),
              ],
              Gap.h8,
              _AvailabilitySection(propertyId: property.id, manager: manager),
              if (manager) ...[Gap.h16, _UnitsSection(propertyId: property.id)],
            ],
          ),
        ),
      ],
    );
  }
}

/// What can be booked here today, block by block, straight from the
/// availability engine — the same answer Browse gives, narrowed to this
/// property. The owner sees every block, open or full, and taps one for its
/// units.
class _AvailabilitySection extends ConsumerWidget {
  const _AvailabilitySection({required this.propertyId, required this.manager});

  final String propertyId;
  final bool manager;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(availabilityProvider);
    final structure = manager
        ? ref.watch(propertyBlocksProvider(propertyId))
        : null;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const padding = EdgeInsets.all(Gap.md);

    if ((availability.isLoading && !availability.hasValue) ||
        (structure != null && structure.isLoading && !structure.hasValue)) {
      return const SectionCard(
        title: 'Available',
        padding: padding,
        children: [
          AppSkeleton(height: 18),
          Gap.h12,
          AppSkeleton(height: 18, width: 160),
        ],
      );
    }

    if ((availability.hasError && !availability.hasValue) ||
        (structure != null && structure.hasError && !structure.hasValue)) {
      return SectionCard(
        title: 'Available',
        padding: padding,
        children: [
          Text(
            'Availability could not be checked just now.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Gap.h8,
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () {
                if (manager) ref.invalidate(propertyBlocksProvider(propertyId));
                ref.read(availabilityProvider.notifier).refresh();
              },
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    final open = availability.requireValue.forProperty(propertyId);
    final rows = <Widget>[
      if (structure != null)
        for (final block in structure.requireValue)
          _BlockRow(
            name: block.name,
            detail: switch (open.where((b) => b.blockId == block.id)) {
              final found when found.isNotEmpty => found.first.sizesLabel,
              _ => 'None available',
            },
            onTap: () => showBlockSheet(context, block.id),
          )
      else
        for (final block in open)
          _BlockRow(name: block.blockName, detail: block.sizesLabel),
    ];

    if (rows.isEmpty) {
      return SectionCard(
        title: 'Available',
        padding: padding,
        children: [
          Text(
            manager
                ? 'No blocks yet.'
                : 'Nothing is open for booking here right now.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return SectionCard(
      title: 'Available',
      padding: padding,
      trailing: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.xs,
        ),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          '${open.count} available',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
      children: rows,
    );
  }
}

/// Every unit in the property, owner only, narrowed by block name. The
/// same records [_OccupancySection] counts, so the list and the meter agree.
class _UnitsSection extends ConsumerStatefulWidget {
  const _UnitsSection({required this.propertyId});

  final String propertyId;

  @override
  ConsumerState<_UnitsSection> createState() => _UnitsSectionState();
}

class _UnitsSectionState extends ConsumerState<_UnitsSection> {
  /// Null is "All".
  String? _blockId;

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(propertyUnitsProvider(widget.propertyId));
    final blocks =
        ref.watch(propertyBlocksProvider(widget.propertyId)).value ?? const [];
    final theme = Theme.of(context);

    if (!units.hasValue) {
      if (units.hasError) {
        return SectionCard(
          title: 'Units',
          children: [
            Text(
              'The units could not be loaded just now.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Gap.h8,
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () =>
                    ref.invalidate(propertyUnitsProvider(widget.propertyId)),
                child: const Text('Try again'),
              ),
            ),
          ],
        );
      }
      return const SectionCard(
        title: 'Units',
        children: [AppSkeleton(height: 18), Gap.h12, AppSkeleton(height: 18)],
      );
    }

    // A block deleted since it was picked falls back to "All".
    final blockId = blocks.any((b) => b.id == _blockId) ? _blockId : null;
    final shown = [
      for (final unit in units.requireValue)
        if (blockId == null || unit.buildingId == blockId) unit,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (blocks.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: blockId == null,
                  onSelected: (_) => setState(() => _blockId = null),
                ),
                for (final block in blocks) ...[
                  Gap.w8,
                  ChoiceChip(
                    label: Text(
                      block.name.isEmpty ? 'Unnamed block' : block.name,
                    ),
                    selected: blockId == block.id,
                    onSelected: (selected) =>
                        setState(() => _blockId = selected ? block.id : null),
                  ),
                ],
              ],
            ),
          ),
          Gap.h12,
        ],
        if (shown.isEmpty)
          SectionCard(
            title: 'Units',
            children: [
              Text(
                blockId == null
                    ? 'No units yet.'
                    : 'No units in this block yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          )
        else
          RecordGroup(
            heading: '${shown.length} ${shown.length == 1 ? 'unit' : 'units'}',
            children: [
              for (final unit in shown)
                RecordRow(
                  icon: Icons.grid_view_rounded,
                  iconColor: context.statusColors.resolve(unit.status.tone),
                  title: unit.unitNumber,
                  subtitle: [
                    if (blockId == null && unit.buildingName != null)
                      unit.buildingName!,
                    unit.category.label,
                    if (unit.areaLabel != null) unit.areaLabel!,
                  ].join(' · '),
                  amount: AmountText(unit.baseRent, align: TextAlign.end),
                  caption: unit.status.label,
                ),
            ],
          ),
      ],
    );
  }
}

/// A block and the sizes it has to let — "North Wing · 480 sq ft × 10".
class _BlockRow extends StatelessWidget {
  const _BlockRow({required this.name, required this.detail, this.onTap});

  final String name;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.small,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(
          children: [
            Icon(Icons.domain_outlined, size: 17, color: scheme.primary),
            Gap.w8,
            Expanded(
              child: Text(
                name.isEmpty ? 'Unnamed block' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium,
              ),
            ),
            Gap.w8,
            Flexible(
              child: Text(
                detail,
                textAlign: TextAlign.end,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            if (onTap != null) ...[
              Gap.w4,
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension on UnitAvailability {
  /// "480 sq ft × 10, 1,200 sq ft × 2".
  String get sizesLabel => bySize
      .map((s) => s.size == 0 ? '× ${s.count}' : '${s.label} × ${s.count}')
      .join(', ');
}

extension on List<UnitAvailability> {
  /// The engine's rows for one property, in the server's order.
  List<UnitAvailability> forProperty(String propertyId) =>
      where((block) => block.propertyId == propertyId).toList(growable: false);

  int get count => fold(0, (sum, block) => sum + block.count);
}

/// Section 88. How much of the property is let, for the owner.
///
/// Counted from the property's unit records. If that count cannot be made,
/// the mix the property payload itself embedded stands in, so a hiccup on
/// one route does not blank a figure the list screen just showed.
class _OccupancySection extends ConsumerWidget {
  const _OccupancySection({required this.propertyId, this.fallback});

  final String propertyId;
  final UnitMix? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occupancy = ref.watch(propertyOccupancyProvider(propertyId));
    final mix = occupancy.value?.mix ?? fallback;

    if (mix == null) {
      if (occupancy.isLoading) {
        return const SectionCard(
          title: 'Occupancy',
          children: [
            AppSkeleton(height: 28, width: 96),
            Gap.h12,
            AppSkeleton(height: 5),
          ],
        );
      }
      final theme = Theme.of(context);
      return SectionCard(
        title: 'Occupancy',
        children: [
          Text(
            'The units could not be counted just now.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Gap.h8,
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () =>
                  ref.invalidate(propertyUnitsProvider(propertyId)),
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    if (mix.isEmpty) {
      final theme = Theme.of(context);
      return SectionCard(
        title: 'Occupancy',
        children: [
          Text(
            'No units yet. Units set up in the blocks will appear here.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return SectionCard(
      title: 'Occupancy',
      padding: const EdgeInsets.all(Gap.md),
      trailing: Text(
        mix.occupancyLabel,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      children: [OccupancyMeter(mix: mix, dense: true)],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = highlighted
        ? scheme.onPrimaryContainer.withValues(alpha: 0.72)
        : scheme.onSurfaceVariant;
    return AppSurfaceCard(
      padding: const EdgeInsets.all(Gap.md),
      color: highlighted ? scheme.primaryContainer : null,
      borderColor: highlighted ? Colors.transparent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: highlighted ? scheme.onPrimaryContainer : scheme.primary,
          ),
          Gap.h8,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: AppTypography.medium,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Gap.h4,
          // Wraps rather than clips: "Available" over "units" on a phone.
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
