import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/property.dart';
import '../../../navigation/routes.dart';
import '../../properties/application/property_controller.dart';
import '../../../components/app_media.dart';
import '../../../components/page_empty_state.dart';

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
        actions: [
          IconButton(
            tooltip: 'Add a property',
            onPressed: () => context.pushNamed(Routes.ownerAddProperty),
            icon: const Icon(Icons.add_rounded),
          ),
          Gap.w8,
        ],
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

class _Properties extends StatelessWidget {
  const _Properties({required this.properties, required this.onRefresh});

  final List<Property> properties;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) {
      return PageEmptyState(
        icon: Icons.apartment_outlined,
        caption: 'Build your portfolio',
        title: 'Your first property starts here',
        message:
            'Add a property to organise your spaces and keep building details in one place.',
        onRefresh: onRefresh,
        action: FilledButton.icon(
          onPressed: () => context.pushNamed(Routes.ownerAddProperty),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add a property'),
        ),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 760 ? 2 : 1;
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YOUR PORTFOLIO',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onPrimaryContainer,
                                letterSpacing: 1.6,
                              ),
                            ),
                            Gap.h12,
                            Text(
                              '${properties.length} ${properties.length == 1 ? 'property' : 'properties'}, one place',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Gap.h8,
                            Text(
                              'View your buildings, explore units and manage the details.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onPrimaryContainer,
                              ),
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
                  0,
                  constraints.maxWidth > 1120
                      ? (constraints.maxWidth - 1080) / 2
                      : 20,
                  32,
                ),
                sliver: SliverList.separated(
                  itemCount: (properties.length / columns).ceil(),
                  separatorBuilder: (_, _) => Gap.h16,
                  itemBuilder: (context, row) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0) Gap.w16,
                        Expanded(
                          child: row * columns + column < properties.length
                              ? AppReveal(
                                  index: row,
                                  child: _PropertyCard(
                                    property:
                                        properties[row * columns + column],
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

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property});
  final Property property;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: () => context.pushNamed(
          Routes.ownerProperty,
          pathParameters: {'propertyId': property.id},
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppMedia(
              source: property.imageUrl,
              aspectRatio: 2,
              semanticLabel: property.name,
              fallbackIcon: Icons.apartment_rounded,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.propertyType.label.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Gap.h8,
                  Text(
                    property.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Gap.h8,
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
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Gap.h16,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (property.totalUnits != null)
                        _Fact(label: '${property.totalUnits} units'),
                      if (property.availableUnits != null)
                        _Fact(label: '${property.availableUnits} available'),
                      if (property.rateLabel != null)
                        _Fact(label: property.rateLabel!),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Manage property',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 19,
                        color: scheme.primary,
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
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelMedium),
  );
}
