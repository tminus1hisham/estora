import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_media.dart';
import '../../../components/even_grid.dart';
import '../../../components/occupancy_meter.dart';
import 'widgets/premium_home.dart';
import 'widgets/tenant_welcome.dart';
import '../../../components/app_reveal.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/property.dart';
import '../../../navigation/routes.dart';
import '../../auth/application/auth_controller.dart';
import '../../properties/application/property_controller.dart';
import '../../invoices/application/invoice_controller.dart';
import 'widgets/recent_invoices.dart';

// Home and the directory share the same unfiltered, session-lived list.
final homePropertiesProvider = propertyListProvider;

/// Home content supported by the published property and invoice operations.
/// A section failure leaves the greeting and navigation usable.
class AvailableHome extends ConsumerWidget {
  const AvailableHome({required this.manager, super.key});

  final bool manager;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authControllerProvider).user?.firstName;
    return AppRefreshIndicator(
      onRefresh: () async {
        if (manager) {
          await ref
              .refresh(homePropertiesProvider.future)
              .then<void>((_) {}, onError: (Object _) {});
        } else {
          await ref.read(invoiceListProvider.notifier).refresh();
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (manager)
            PremiumHomeHero(manager: true, name: name)
          else
            TenantWelcome(name: name),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: manager ? AppLayout.maxReadingWidth : 1080,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Owners reach properties from the shell; the tenant
                    // panel overlaps the hero, so keep its lift.
                    if (manager)
                      Gap.h24
                    else
                      Transform.translate(
                        offset: const Offset(0, -28),
                        child: const AppReveal(
                          index: 3,
                          child: TenantActionPanel(),
                        ),
                      ),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        Text(
                          manager ? 'Your properties' : 'Recent invoices',
                          style: manager
                              ? Theme.of(context).textTheme.titleLarge
                              : Theme.of(context).textTheme.titleMedium,
                        ),
                        if (!manager)
                          TextButton.icon(
                            onPressed: () => context.goNamed(Routes.invoices),
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                            ),
                            iconAlignment: IconAlignment.end,
                            label: const Text('View all'),
                          ),
                      ],
                    ),
                    Gap.h4,
                    Text(
                      manager
                          ? 'A place for every part of your portfolio.'
                          : 'Your latest bills, with payment details at a glance.',
                      style:
                          (manager
                                  ? Theme.of(context).textTheme.bodyMedium
                                  : Theme.of(context).textTheme.bodySmall)
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                    ),
                    Gap.h16,
                    if (manager)
                      ref
                          .watch(homePropertiesProvider)
                          .when(
                            loading: () => const HomeLoadingCard(),
                            error: (error, _) => _sectionError(
                              error,
                              () => ref.invalidate(homePropertiesProvider),
                            ),
                            // One column on a phone, more as the window
                            // allows, and every card the size of its
                            // neighbours whether or not it carries a meter.
                            data: (properties) => properties.isEmpty
                                ? HomeWelcomeCard(manager: true)
                                : EvenGrid(
                                    minTileWidth: 300,
                                    spacing: Gap.lg,
                                    children: [
                                      for (final property in properties)
                                        _PropertyCard(property: property),
                                    ],
                                  ),
                          )
                    else
                      ref
                          .watch(invoiceListProvider)
                          .when(
                            loading: () => const HomeLoadingCard(),
                            error: (error, _) => _sectionError(
                              error,
                              () => ref
                                  .read(invoiceListProvider.notifier)
                                  .refresh(),
                            ),
                            data: (invoices) => AppReveal(
                              index: 4,
                              child: RecentInvoices(invoices: invoices),
                            ),
                          ),
                    Gap.h24,
                    const HomeFooter(),
                    Gap.h24,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionError(Object error, VoidCallback onRetry) => HomeSectionError(
    failure: error is Failure ? error : UnknownFailure(error.toString()),
    onRetry: onRetry,
  );
}

/// One property in the manager's home grid.
///
/// The photograph is a fixed height so that a row of cards agrees on where
/// its titles start; everything under it is content-sized, and the grid
/// squares up the rest.
class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
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
            height: 150,
            semanticLabel: property.name,
          ),
          ListTile(
            title: Text(property.name),
            subtitle: Text(property.city),
            trailing: const Icon(Icons.arrow_forward_rounded),
          ),
          if (property.mix != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
              child: OccupancyMeter(mix: property.mix!, dense: true),
            ),
        ],
      ),
    ),
  );
}
