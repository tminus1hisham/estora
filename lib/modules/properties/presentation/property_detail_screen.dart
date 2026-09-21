import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_bottom_action_bar.dart';
import '../../../components/app_media.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/occupancy_meter.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../components/unit_status_strip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/owner.dart';
import '../../../domain/entities/unit.dart';
import '../../../navigation/routes.dart';
import '../../structure/application/structure_controller.dart';
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
      appBar: AppBar(
        title: Text(detail.value?.property.name ?? 'Property'),
        actions: [
          if (manager)
            PopupMenuButton<String>(
              tooltip: 'Manage property',
              onSelected: (route) => context.pushNamed(
                route,
                pathParameters: {'propertyId': propertyId},
              ),
              itemBuilder: (_) => const [
                PopupMenuItem(value: Routes.blocks, child: Text('Blocks')),
              ],
            ),
        ],
      ),
      body: AppRefreshIndicator(
        onRefresh: () async {
          if (manager) ref.invalidate(propertyOccupancyProvider(propertyId));
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
      // The owner goes on to the structure. A tenant's next step is a
      // conversation, not a transaction: they tell the landlord what they
      // are after and nothing is booked or paid on the way.
      bottomNavigationBar: detail.hasValue
          ? AppBottomActionBar(
              child: manager
                  ? FilledButton.icon(
                      onPressed: () => context.pushNamed(
                        Routes.blocks,
                        pathParameters: {'propertyId': propertyId},
                      ),
                      icon: const Icon(Icons.meeting_room_outlined),
                      label: const Text('View blocks and units'),
                    )
                  : FilledButton.icon(
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
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
      children: [
        AppMedia(
          source: property.imageUrl,
          aspectRatio: 16 / 10,
          heroTag: 'property-${property.id}',
          borderRadius: AppRadius.large,
          semanticLabel: '${property.name} property',
          fallbackIcon: Icons.location_city_rounded,
        ),
        Gap.h24,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                property.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Gap.w12,
            StatusChip(
              label: property.status.label,
              tone: property.status.tone,
            ),
          ],
        ),
        Gap.h8,
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            Gap.w8,
            Expanded(
              child: Text(
                property.locationLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        if (property.description != null) ...[
          Gap.h16,
          Text(
            property.description!,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        Gap.h24,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.meeting_room_outlined,
                value: available?.toString() ?? '—',
                label: 'Available',
                highlighted: true,
              ),
            ),
            Gap.w12,
            Expanded(
              child: _MetricTile(
                icon: Icons.domain_outlined,
                value: property.totalUnits?.toString() ?? '—',
                label: 'Blocks',
              ),
            ),
            if (property.totalArea != null) ...[
              Gap.w12,
              Expanded(
                child: _MetricTile(
                  icon: Icons.square_foot_rounded,
                  value: property.totalArea!.toStringAsFixed(0),
                  label: 'Square feet',
                ),
              ),
            ],
          ],
        ),
        if (manager) ...[
          Gap.h12,
          _OccupancySection(propertyId: property.id, fallback: property.mix),
        ],
        Gap.h12,
        _AvailabilitySection(propertyId: property.id),
      ],
    );
  }
}

/// What can be booked here today, block by block, straight from the
/// availability engine — the same answer Browse gives, narrowed to this
/// property.
class _AvailabilitySection extends ConsumerWidget {
  const _AvailabilitySection({required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(availabilityProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (availability.isLoading && !availability.hasValue) {
      return const SectionCard(
        title: 'Available',
        children: [
          AppSkeleton(height: 18),
          Gap.h12,
          AppSkeleton(height: 18),
          Gap.h12,
          AppSkeleton(height: 18, width: 160),
        ],
      );
    }

    if (availability.hasError && !availability.hasValue) {
      return SectionCard(
        title: 'Available',
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
              onPressed: () =>
                  ref.read(availabilityProvider.notifier).refresh(),
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    final blocks = availability.requireValue.forProperty(propertyId);

    if (blocks.isEmpty) {
      return SectionCard(
        title: 'Available',
        children: [
          Text(
            'Nothing is open for booking here right now.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return SectionCard(
      title: 'Available',
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
          '${blocks.count} available',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
      children: [
        for (final block in blocks) ...[
          _BlockRow(block: block),
          if (block != blocks.last) Gap.h8,
        ],
      ],
    );
  }
}

/// A block and the sizes it has to let — "North Wing · 480 sq ft × 10".
class _BlockRow extends StatelessWidget {
  const _BlockRow({required this.block});

  final UnitAvailability block;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.domain_outlined, size: 17, color: scheme.primary),
        Gap.w8,
        Expanded(
          child: Text(
            block.blockName.isEmpty ? 'Unnamed block' : block.blockName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelMedium,
          ),
        ),
        Gap.w8,
        Flexible(
          child: Text(
            block.bySize.map(_sizeLabel).join(', '),
            textAlign: TextAlign.end,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  static String _sizeLabel(UnitAvailabilitySize size) {
    if (size.size == 0) return '× ${size.count}';
    final area = size.size == size.size.roundToDouble()
        ? size.size.toInt().toString()
        : size.size.toString();
    return '$area sq ft × ${size.count}';
  }
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
                  ref.invalidate(propertyOccupancyProvider(propertyId)),
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
      children: [
        OccupancyMeter(mix: mix, label: 'Units let'),
        Gap.h16,
        UnitStatusStrip(mix: mix),
      ],
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
    return AppSurfaceCard(
      padding: const EdgeInsets.all(Gap.md),
      color: highlighted ? scheme.primaryContainer : null,
      borderColor: highlighted ? Colors.transparent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: highlighted ? scheme.onPrimaryContainer : scheme.primary,
          ),
          Gap.h12,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: Theme.of(context).textTheme.titleLarge),
          ),
          Gap.h4,
          Text(
            label,
            maxLines: 2,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: highlighted
                  ? scheme.onPrimaryContainer.withValues(alpha: 0.72)
                  : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
