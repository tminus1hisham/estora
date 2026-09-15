import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/property.dart';
import '../../../navigation/routes.dart';
import '../../properties/application/property_controller.dart';
import '../../../components/app_media.dart';

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
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.apartment_outlined,
                title: 'No properties yet',
                message:
                    'Properties available to your account will be listed here.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            itemCount: properties.length,
            separatorBuilder: (_, _) => Gap.h16,
            itemBuilder: (context, index) => AppReveal(
              index: index,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.pushNamed(
                    Routes.ownerProperty,
                    pathParameters: {'propertyId': properties[index].id},
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppMedia(source: properties[index].imageUrl),
                      ListTile(
                        title: Text(properties[index].name),
                        subtitle: Text(properties[index].city),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
