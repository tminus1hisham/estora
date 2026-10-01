import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/page_header.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/unit.dart';
import '../../../navigation/routes.dart';
import '../../units/application/unit_controller.dart';

/// Section 77's Browse screen — the root of the browsing journey.
///
/// Reached from Profile's 'Browse more properties' and from the home screen,
/// pushed over the tab bar rather than replacing it. A link that lands here
/// directly has nothing to go back to, so the app bar offers home instead.
///
/// Lists what the availability engine says can be booked right now
/// (`GET /properties/available/units/to/book`): every block with stock and
/// the sizes on offer in it, grouped here by property. It deliberately does
/// not start from the properties route, which a tenant's token cannot read
/// and which would list places with nothing to let.
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
    final availability = ref.watch(availabilityProvider);
    // Search belongs to this screen. The shared list remains complete for a
    // fresh visit to Browse.
    final query = _searchController.text.trim().toLowerCase();
    final visible = availability.whenData(
      (blocks) => _PropertyAvailability.group(
        blocks.where((block) {
          return query.isEmpty ||
              block.propertyName.toLowerCase().contains(query) ||
              block.blockName.toLowerCase().contains(query);
        }),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse spaces'),
        // Navigator's own answer rather than go_router's: this screen is also
        // built directly in widget tests, where there is no router to ask.
        leading: Navigator.of(context).canPop()
            ? null
            : IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: 'Home',
                onPressed: () => context.goNamed(Routes.home),
              ),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.lg),
            child: PageHeader(
              eyebrow: 'Curated commercial spaces',
              title: 'Find a space to grow',
              subtitle: 'Spaces you can book today, across every property.',
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
                          setState(() {});
                        },
                      ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: switch (availability) {
              AsyncLoading() when !availability.hasValue =>
                const AppSkeletonList(),
              AsyncError(:final error) => ErrorView(
                failure: error is Failure
                    ? error
                    : UnknownFailure(error.toString()),
                onRetry: () =>
                    ref.read(availabilityProvider.notifier).refresh(),
              ),
              _ => _AvailabilityList(
                properties: visible.requireValue,
                searching: query.isNotEmpty,
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// One property's worth of the engine's answer: its blocks with stock.
class _PropertyAvailability {
  const _PropertyAvailability({
    required this.id,
    required this.name,
    required this.blocks,
  });

  final String id;
  final String name;
  final List<UnitAvailability> blocks;

  int get count => blocks.fold(0, (sum, block) => sum + block.count);

  /// Groups the engine's block rows by property, keeping the server's order.
  static List<_PropertyAvailability> group(Iterable<UnitAvailability> blocks) {
    final byProperty = <String, List<UnitAvailability>>{};
    for (final block in blocks) {
      byProperty.putIfAbsent(block.propertyId, () => []).add(block);
    }
    return [
      for (final MapEntry(key: id, value: rows) in byProperty.entries)
        _PropertyAvailability(
          id: id,
          name: rows.first.propertyName,
          blocks: rows,
        ),
    ];
  }
}

class _AvailabilityList extends ConsumerWidget {
  const _AvailabilityList({required this.properties, required this.searching});

  final List<_PropertyAvailability> properties;
  final bool searching;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (properties.isEmpty) {
      return EmptyState(
        onRefresh: () async {
          await ref.read(availabilityProvider.notifier).refresh();
        },
        icon: Icons.location_city_outlined,
        title: searching ? 'No matching properties' : 'No spaces available',
        message: searching
            ? 'Try a different search term or clear your search.'
            : 'Nothing is open for booking right now. Pull down to check again.',
      );
    }

    return AppRefreshIndicator(
      onRefresh: () => ref.read(availabilityProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
        itemCount: properties.length,
        separatorBuilder: (_, _) => Gap.h12,
        itemBuilder: (context, index) => AppReveal(
          index: index,
          child: _PropertyCard(property: properties[index]),
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property});

  final _PropertyAvailability property;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final count = property.count;

    return AppSurfaceCard(
      elevation: AppElevation.low,
      semanticLabel: '${property.name}, $count available',
      onTap: () => context.pushNamed(
        Routes.availableUnits,
        pathParameters: {'propertyId': property.id},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(property.name, style: text.titleLarge)),
              Gap.w12,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: Gap.xs,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$count available',
                  style: text.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          Gap.h12,
          for (final block in property.blocks) ...[
            _BlockRow(block: block),
            if (block != property.blocks.last) Gap.h8,
          ],
          Gap.h16,
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'View spaces',
                style: text.labelLarge?.copyWith(color: scheme.primary),
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
    return '${size.label} × ${size.count}';
  }
}
