import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(title: const Text('Find a space')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
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
                          ref
                              .read(propertyListProvider.notifier)
                              .search('');
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

    return Card(
      child: InkWell(
        onTap: () => context.pushNamed(
          Routes.propertyDetail,
          pathParameters: {'propertyId': property.id},
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A gradient stands in for a hero image. The API carries an
            // imageUrl; there is nothing behind it in the mock.
            Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primaryContainer,
                    scheme.tertiaryContainer.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  _iconFor(property),
                  size: 40,
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          property.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Chip(
                        label: Text(property.propertyType.label),
                        labelStyle: Theme.of(context).textTheme.bodySmall,
                        backgroundColor: scheme.surfaceContainerHighest,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  Gap.h4,
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      Gap.w4,
                      Expanded(
                        child: Text(
                          property.locationLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (property.description != null) ...[
                    Gap.h8,
                    Text(
                      property.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  Gap.h12,
                  Row(
                    children: [
                      Icon(
                        Icons.meeting_room_outlined,
                        size: 16,
                        color: property.hasAvailability
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      Gap.w4,
                      Text(
                        property.hasAvailability
                            ? '${property.availableUnits} available now'
                            : 'Fully let',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: property.hasAvailability
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${property.totalUnits ?? 0} units',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(Property property) =>
      switch (property.propertyType) {
        PropertyType.mall ||
        PropertyType.retailCenter => Icons.local_mall_outlined,
        PropertyType.office ||
        PropertyType.businessCenter => Icons.apartment_rounded,
        PropertyType.warehouse => Icons.warehouse_outlined,
        PropertyType.mixedUse => Icons.domain_outlined,
        PropertyType.other ||
        PropertyType.unknown => Icons.location_city_rounded,
      };
}
