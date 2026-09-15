import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_bottom_action_bar.dart';
import '../../../components/app_media.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/routes.dart';
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
                PopupMenuItem(
                  value: Routes.unitCreate,
                  child: Text('Add a unit'),
                ),
                PopupMenuItem(
                  value: Routes.propertyEdit,
                  child: Text('Edit this property'),
                ),
              ],
            ),
        ],
      ),
      body: AppRefreshIndicator(
        onRefresh: () async {
          await ref
              .refresh(propertyDetailProvider(propertyId).future)
              .then<void>((_) {});
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
          _ => _Body(detail: detail.requireValue),
        },
      ),
      bottomNavigationBar: detail.hasValue
          ? AppBottomActionBar(
              child: FilledButton.icon(
                onPressed: () => context.pushNamed(
                  manager ? Routes.blocks : Routes.availableUnits,
                  pathParameters: {'propertyId': propertyId},
                ),
                icon: const Icon(Icons.meeting_room_outlined),
                label: Text(
                  manager
                      ? 'View blocks and units'
                      : detail.requireValue.property.hasAvailability
                      ? 'View ${detail.requireValue.property.availableUnits} '
                            'available units'
                      : 'View all units',
                ),
              ),
            )
          : null,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.detail});

  final PropertyDetail detail;

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
                value: property.availableUnits?.toString() ?? '—',
                label: 'Available',
                highlighted: true,
              ),
            ),
            Gap.w12,
            Expanded(
              child: _MetricTile(
                icon: Icons.domain_outlined,
                value: property.totalUnits?.toString() ?? '—',
                label: 'Total units',
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
        Gap.h12,
        SectionCard(
          title: 'Property details',
          children: [
            DetailRow(label: 'Type', value: property.propertyType.label),
            if (property.code.isNotEmpty)
              DetailRow(label: 'Property code', value: property.code),
            if (property.county != null)
              DetailRow(label: 'County', value: property.county!),
          ],
        ),
        if (detail.buildings.isNotEmpty) ...[
          Gap.h12,
          SectionCard(
            title: 'Buildings and floors',
            children: [
              for (final building in detail.buildings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: AppRadius.small,
                            ),
                            child: Icon(
                              Icons.apartment_rounded,
                              size: 18,
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                          Gap.w12,
                          Expanded(
                            child: Text(
                              building.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 48, top: Gap.sm),
                        child: Wrap(
                          spacing: Gap.sm,
                          runSpacing: Gap.sm,
                          children: [
                            for (final floor
                                in detail.floorsByBuilding[building.id] ??
                                    const [])
                              Chip(label: Text(floor.name)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
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
