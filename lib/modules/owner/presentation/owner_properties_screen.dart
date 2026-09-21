import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/property.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../properties/application/property_controller.dart';
import 'widgets/owner_dashboard_widgets.dart';

import '../../../components/page_empty_state.dart';

/// The "Your portfolio" banner above the list is hidden for now. The card and
/// its badges stay wired up so it can come back by flipping one line.
const bool _showPortfolioHero = false;

/// Section 88. The owner's buildings.
class OwnerPropertiesScreen extends ConsumerWidget {
  const OwnerPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolio = ref.watch(propertyListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Properties'),
        backgroundColor: Colors.transparent,
      ),
      body: switch (portfolio) {
        AsyncLoading() when !portfolio.hasValue => const AppSkeletonMediaList(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.read(propertyListProvider.notifier).refresh(),
        ),
        _ => _Properties(
          properties: portfolio.requireValue,
          onRefresh: () => ref.read(propertyListProvider.notifier).refresh(),
        ),
      },
    );
  }
}

class _Properties extends StatefulWidget {
  const _Properties({required this.properties, required this.onRefresh});

  final List<Property> properties;
  final Future<void> Function() onRefresh;

  @override
  State<_Properties> createState() => _PropertiesState();
}

class _PropertiesState extends State<_Properties> {
  final _search = TextEditingController();
  PropertyType? _type;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _search.clear();
      _type = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final properties = widget.properties;
    final onRefresh = widget.onRefresh;
    if (properties.isEmpty) {
      return PageEmptyState(
        icon: Icons.apartment_outlined,
        caption: 'Your portfolio',
        title: 'No properties yet',
        message:
            'Properties assigned to you will appear here with their spaces and building details.',
        onRefresh: onRefresh,
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final types = properties.map((property) => property.propertyType).toSet();
    final selectedType = types.contains(_type) ? _type : null;
    final query = _search.text.trim().toLowerCase();
    final visible = properties.where((property) {
      return (selectedType == null || property.propertyType == selectedType) &&
          (query.isEmpty ||
              '${property.name} ${property.code} ${property.locationLabel}'
                  .toLowerCase()
                  .contains(query));
    }).toList();
    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = MediaQuery.textScalerOf(context).scale(14) > 20
              ? 1
              : constraints.maxWidth >= 1080
              ? 3
              : constraints.maxWidth >= 700
              ? 2
              : 1;
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (_showPortfolioHero)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: AppSurfaceCard(
                          padding: const EdgeInsets.all(24),
                          gradient: AppGradients.brandHero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'YOUR PORTFOLIO',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppPalette.brass200,
                                  letterSpacing: 1.6,
                                ),
                              ),
                              Gap.h12,
                              Text(
                                'Every property.\nA clearer picture.',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Gap.h8,
                              Text(
                                'Explore your buildings, find a space and manage the details.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                              Gap.h16,
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  _PortfolioBadge(
                                    icon: Icons.apartment_rounded,
                                    label:
                                        '${properties.length} ${properties.length == 1 ? 'property' : 'properties'}',
                                  ),
                                  _PortfolioBadge(
                                    icon: Icons.category_outlined,
                                    label:
                                        '${types.length} ${types.length == 1 ? 'property type' : 'property types'}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth > 1120
                      ? (constraints.maxWidth - 1080) / 2
                      : 20,
                  _showPortfolioHero ? 0 : 8,
                  constraints.maxWidth > 1120
                      ? (constraints.maxWidth - 1080) / 2
                      : 20,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search by name, code or location',
                          labelText: 'Find a property',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () => setState(_search.clear),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      if (types.length > 1) ...[
                        Gap.h12,
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('All properties'),
                              selected: selectedType == null,
                              onSelected: (_) => setState(() => _type = null),
                            ),
                            for (final type in types)
                              ChoiceChip(
                                label: Text(type.label),
                                selected: selectedType == type,
                                onSelected: (selected) => setState(
                                  () => _type = selected ? type : null,
                                ),
                              ),
                          ],
                        ),
                      ],
                      Gap.h24,
                      Text(
                        query.isNotEmpty || selectedType != null
                            ? '${visible.length} of ${properties.length} properties'
                            : 'Your properties',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Gap.h4,
                      Text(
                        'Select a property to view its spaces and details.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Gap.h16,
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 36,
                                  color: scheme.onSurfaceVariant,
                                ),
                                Gap.h12,
                                Text(
                                  'No matching properties',
                                  style: theme.textTheme.titleMedium,
                                ),
                                Gap.h8,
                                const Text(
                                  'Try another name, location or property type.',
                                  textAlign: TextAlign.center,
                                ),
                                Gap.h12,
                                OutlinedButton(
                                  onPressed: _resetFilters,
                                  child: const Text('Clear filters'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth > 1120
                      ? (constraints.maxWidth - 1080) / 2
                      : 20,
                  0,
                  constraints.maxWidth > 1120
                      ? (constraints.maxWidth - 1080) / 2
                      : 20,
                  32,
                ),
                sliver: SliverList.separated(
                  itemCount: (visible.length / columns).ceil(),
                  separatorBuilder: (_, _) => Gap.h16,
                  itemBuilder: (context, row) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0) Gap.w16,
                        Expanded(
                          child: row * columns + column < visible.length
                              ? AppReveal(
                                  index: row,
                                  child: OwnerPropertyTile(
                                    property: visible[row * columns + column],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PortfolioBadge extends StatelessWidget {
  const _PortfolioBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: .14)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppPalette.brass200),
        Gap.w8,
        Flexible(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
