import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_media.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/page_header.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/property.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../navigation/routes.dart';
import '../application/property_controller.dart';

/// Section 77's Properties screen — the root of the Browse tab.
class PropertiesScreen extends ConsumerStatefulWidget {
  const PropertiesScreen({super.key});

  @override
  ConsumerState<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends ConsumerState<PropertiesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(propertyListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Browse spaces')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.lg),
            child: PageHeader(
              eyebrow: 'Curated commercial spaces',
              title: 'Find a space to grow',
              subtitle:
                  'Explore verified retail and office spaces across Nairobi.',
              compact: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search properties',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(propertyListProvider.notifier).search('');
                          setState(() {});
                        },
                      ),
              ),
              onChanged: (value) {
                setState(() {});
                ref.read(propertyListProvider.notifier).search(value);
              },
            ),
          ),
          Expanded(
            child: switch (properties) {
              AsyncLoading() when !properties.hasValue => const LoadingView(),
              AsyncError(:final error) => ErrorView(
                failure: error is Failure
                    ? error
                    : UnknownFailure(error.toString()),
                onRetry: () =>
                    ref.read(propertyListProvider.notifier).refresh(),
              ),
              _ => _PropertyList(properties: properties.requireValue),
            },
          ),
        ],
      ),
    );
  }
}

class _PropertyList extends ConsumerWidget {
  const _PropertyList({required this.properties});

  final List<Property> properties;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (properties.isEmpty) {
      return const EmptyState(
        icon: Icons.location_city_outlined,
        title: 'No properties found',
        message: 'Try a different search term.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(propertyListProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
        itemCount: properties.length,
        separatorBuilder: (_, _) => Gap.h12,
        itemBuilder: (context, index) =>
            _PropertyCard(property: properties[index]),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      elevation: AppElevation.low,
      semanticLabel: '${property.name}, ${property.locationLabel}',
      onTap: () => context.pushNamed(
        Routes.propertyDetail,
        pathParameters: {'propertyId': property.id},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppMedia(
            source: property.imageUrl,
            aspectRatio: 16 / 8.5,
            heroTag: 'property-${property.id}',
            semanticLabel: '${property.name} property',
            fallbackIcon: _iconFor(property),
            overlay: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xA6000000)],
                        stops: [0.48, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: Gap.md,
                  bottom: Gap.md,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.md,
                      vertical: Gap.sm,
                    ),
                    decoration: BoxDecoration(
                      color: property.hasAvailability
                          ? const Color(0xE6122522)
                          : const Color(0xD94B4B4B),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          property.hasAvailability
                              ? Icons.check_circle_rounded
                              : Icons.schedule_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        Gap.w8,
                        Text(
                          property.hasAvailability
                              ? '${property.availableUnits} available'
                              : 'Fully let',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        property.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Gap.w12,
                    Chip(
                      label: Text(property.propertyType.label),
                      visualDensity: VisualDensity.compact,
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
                    Gap.w4,
                    Expanded(
                      child: Text(
                        property.locationLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (property.description != null) ...[
                  Gap.h12,
                  Text(
                    property.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                Gap.h16,
                Row(
                  children: [
                    Icon(
                      Icons.domain_outlined,
                      size: 17,
                      color: scheme.primary,
                    ),
                    Gap.w8,
                    Expanded(
                      child: Text(
                        '${property.totalUnits ?? 0} commercial units',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    Gap.w8,
                    Text(
                      'Explore',
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: scheme.primary),
                    ),
                    Gap.w4,
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(
    Property property,
  ) => switch (property.propertyType) {
    PropertyType.mall || PropertyType.retailCenter => Icons.local_mall_outlined,
    PropertyType.office ||
    PropertyType.businessCenter => Icons.apartment_rounded,
    PropertyType.warehouse => Icons.warehouse_outlined,
    PropertyType.mixedUse => Icons.domain_outlined,
    PropertyType.other || PropertyType.unknown => Icons.location_city_rounded,
  };
}
