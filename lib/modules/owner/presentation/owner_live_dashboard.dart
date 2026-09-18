import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/collection_columns.dart';
import '../../../components/state_views.dart';
import '../../../core/error/result.dart';
import '../../../domain/entities/owner.dart';
import '../../../domain/entities/property.dart';
import '../../../navigation/routes.dart';
import '../../../services/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../home/presentation/available_home.dart';
import 'widgets/owner_dashboard_widgets.dart';

// Home always describes the entire portfolio, regardless of Revenue's filter.
final ownerDashboardReportProvider = FutureProvider.autoDispose<OwnerReport>((
  ref,
) async {
  ref.watch(authControllerProvider.select((state) => state.user?.id));
  final result = await ref.watch(ownerRepositoryProvider).getReport();
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
}, retry: (_, _) => null);

// The property list can omit its units. Ask the availability engine for the
// bookable counts, and restrict its platform-wide answer to this portfolio.
final ownerDashboardAvailabilityProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
      final repository = ref.watch(unitRepositoryProvider);
      final properties = await ref.watch(homePropertiesProvider.future);
      final counts = {for (final property in properties) property.id: 0};
      if (counts.isEmpty) return counts;
      final result = await repository.listAvailability();
      switch (result) {
        case Err(:final failure):
          throw failure;
        case Ok(:final value):
          for (final block in value) {
            if (counts.containsKey(block.propertyId)) {
              counts[block.propertyId] =
                  counts[block.propertyId]! + block.count;
            }
          }
          return counts;
      }
    }, retry: (_, _) => null);

class OwnerLiveDashboard extends ConsumerWidget {
  const OwnerLiveDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(homePropertiesProvider);
    final report = ref.watch(ownerDashboardReportProvider);
    final availability = ref.watch(ownerDashboardAvailabilityProvider);
    final name = ref.watch(authControllerProvider).user?.firstName;
    Future<void> refresh() async {
      await Future.wait([
        ref
            .refresh(homePropertiesProvider.future)
            .then<void>((_) {}, onError: (Object _) {}),
        ref
            .refresh(ownerDashboardReportProvider.future)
            .then<void>((_) {}, onError: (Object _) {}),
      ]);
      await ref
          .read(ownerDashboardAvailabilityProvider.future)
          .then<void>((_) {}, onError: (Object _) {});
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppRefreshIndicator(
        onRefresh: refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 940 &&
                MediaQuery.textScalerOf(context).scale(14) < 20;
            final propertySection = properties.when(
              loading: () => const AppSkeletonList(itemCount: 2),
              error: (error, _) => _DashboardError(
                label: 'Properties could not be loaded.',
                onRetry: () => ref.invalidate(homePropertiesProvider),
              ),
              data: (items) => _PropertiesOverview(
                properties: items,
                availability: availability.value,
              ),
            );
            final trend = report.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (value) => _CollectionTrend(report: value, expanded: wide),
            );
            return OwnerDashboardScrollView(
              name: name,
              onRefresh: refresh,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  report.when(
                    loading: () => const LinearProgressIndicator(minHeight: 2),
                    error: (_, _) => _DashboardError(
                      label: 'Revenue summary is unavailable.',
                      onRetry: () =>
                          ref.invalidate(ownerDashboardReportProvider),
                    ),
                    data: (value) {
                      final month = value.sliceOver(
                        const CollectionWindow.month(),
                      );
                      return OwnerWidgetGrid(
                        minWidth: 155,
                        children: [
                          OwnerMetric(
                            label: 'Collected this month',
                            value: month.collected.format(),
                            icon: Icons.account_balance_wallet_outlined,
                            detail: '${month.paymentCount} M-Pesa payments',
                            featured: true,
                            onTap: () => context.goNamed(Routes.ownerMoney),
                          ),
                          OwnerMetric(
                            label: 'Outstanding',
                            value: value.outstanding.format(),
                            icon: Icons.receipt_long_outlined,
                            detail:
                                '${value.outstandingInvoices.length} unpaid invoices',
                            onTap: () => context.goNamed(Routes.ownerMoney),
                          ),
                          OwnerMetric(
                            label: 'Total properties',
                            value: properties.hasValue
                                ? '${properties.requireValue.length}'
                                : '—',
                            icon: Icons.apartment_rounded,
                            detail: 'In your portfolio',
                            onTap: () =>
                                context.goNamed(Routes.ownerProperties),
                          ),
                          OwnerMetric(
                            key: const ValueKey('owner-available-spaces'),
                            label: 'Available spaces',
                            value: availability.when(
                              data: (counts) =>
                                  '${counts.values.fold<int>(0, (total, count) => total + count)}',
                              loading: () => '…',
                              error: (_, _) => '—',
                            ),
                            icon: Icons.meeting_room_outlined,
                            detail: availability.hasError
                                ? 'Tap to retry availability'
                                : availability.isLoading
                                ? 'Checking available spaces'
                                : 'Ready for a new tenant',
                            onTap: availability.hasError
                                ? () => ref.invalidate(
                                    ownerDashboardAvailabilityProvider,
                                  )
                                : () => context.goNamed(Routes.ownerProperties),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: propertySection),
                        const SizedBox(width: 20),
                        Expanded(child: trend),
                      ],
                    )
                  else ...[
                    propertySection,
                    const SizedBox(height: 12),
                    trend,
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PropertiesOverview extends StatelessWidget {
  const _PropertiesOverview({required this.properties, this.availability});
  final List<Property> properties;
  final Map<String, int>? availability;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Your properties',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton(
            onPressed: () => context.goNamed(Routes.ownerProperties),
            child: const Text('View all'),
          ),
        ],
      ),
      if (properties.isEmpty)
        const EmptyState(
          icon: Icons.apartment_outlined,
          title: 'No properties yet',
          message:
              'Properties assigned to you will appear here once they are set up.',
        )
      else
        OwnerWidgetGrid(
          children: [
            for (final property in properties.take(4))
              OwnerPropertyTile(
                property: property,
                availableUnits: availability?[property.id],
              ),
          ],
        ),
    ],
  );
}

class _CollectionTrend extends StatelessWidget {
  const _CollectionTrend({required this.report, required this.expanded});
  final OwnerReport report;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final slice = report.sliceOver(const CollectionWindow.month());
    final chart = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Billed against collected',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (report.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Your collection history will appear here when payments or invoices are recorded.',
              ),
            )
          else
            CollectionColumns(points: slice.points, height: 116),
          const SizedBox(height: 12),
          Text(
            'M-Pesa receipts and invoices across your properties.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: expanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Collection performance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                chart,
              ],
            )
          : ExpansionTile(
              title: const Text('Collection performance'),
              leading: const Icon(Icons.bar_chart_rounded),
              shape: const Border(),
              collapsedShape: const Border(),
              children: [chart],
            ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.label, required this.onRetry});
  final String label;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
