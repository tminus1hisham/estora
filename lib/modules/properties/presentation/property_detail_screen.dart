import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/routes.dart';
import '../../units/application/unit_controller.dart';
import '../application/property_controller.dart';

/// Section 77's Property Details screen.
class PropertyDetailScreen extends ConsumerWidget {
  const PropertyDetailScreen({required this.propertyId, super.key});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(propertyDetailProvider(propertyId));

    return Scaffold(
      appBar: AppBar(title: Text(detail.value?.property.name ?? 'Property')),
      body: switch (detail) {
        AsyncLoading() when !detail.hasValue => const LoadingView(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(propertyDetailProvider(propertyId)),
        ),
        _ => _Body(detail: detail.requireValue),
      },
      bottomNavigationBar: detail.hasValue
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: FilledButton.icon(
                  onPressed: () {
                    // Scope the browse filter to this property before opening
                    // the list, so the two screens agree on what is shown.
                    ref
                        .read(unitFilterProvider.notifier)
                        .setProperty(propertyId);
                    context.pushNamed(
                      Routes.availableUnits,
                      pathParameters: {'propertyId': propertyId},
                    );
                  },
                  icon: const Icon(Icons.meeting_room_outlined),
                  label: Text(
                    detail.requireValue.property.hasAvailability
                        ? 'View ${detail.requireValue.property.availableUnits} '
                              'available units'
                        : 'View all units',
                  ),
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
        Container(
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
              Icons.location_city_rounded,
              size: 48,
              color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
            ),
          ),
        ),
        Gap.h16,
        Row(
          children: [
            Expanded(
              child: Text(
                property.name,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            StatusChip(
              label: property.status.label,
              tone: property.status.tone,
            ),
          ],
        ),
        Gap.h4,
        Text(
          property.locationLabel,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (property.description != null) ...[
          Gap.h16,
          Text(property.description!),
        ],
        Gap.h16,
        SectionCard(
          title: 'At a glance',
          children: [
            DetailRow(label: 'Type', value: property.propertyType.label),
            DetailRow(label: 'Code', value: property.code),
            if (property.totalArea != null)
              DetailRow(
                label: 'Total area',
                value: '${property.totalArea!.toStringAsFixed(0)} m²',
              ),
            DetailRow(
              label: 'Total units',
              value: '${property.totalUnits ?? 0}',
            ),
            DetailRow(
              label: 'Available now',
              value: '${property.availableUnits ?? 0}',
              emphasise: true,
            ),
          ],
        ),
        if (detail.buildings.isNotEmpty) ...[
          Gap.h12,
          SectionCard(
            title: 'Buildings and floors',
            children: [
              for (final building in detail.buildings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.apartment_rounded,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          ),
                          Gap.w8,
                          Text(
                            building.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 26, top: 4),
                        child: Wrap(
                          spacing: Gap.sm,
                          runSpacing: Gap.xs,
                          children: [
                            for (final floor
                                in detail.floorsByBuilding[building.id] ??
                                    const [])
                              Chip(
                                label: Text(floor.name),
                                labelStyle: Theme.of(
                                  context,
                                ).textTheme.bodySmall,
                                backgroundColor: scheme.surfaceContainerHighest,
                                visualDensity: VisualDensity.compact,
                              ),
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
