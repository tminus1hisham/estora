import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_bottom_action_bar.dart';
import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/page_header.dart';
import '../../../components/record_group.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/unit.dart';
import '../../../navigation/routes.dart';
import '../application/unit_controller.dart';

/// One property's spaces, as the availability engine lists them.
///
/// This is the second page of Browse and it reads the same one route as the
/// first — `GET /properties/available/units/to/book` — and nothing else. The
/// engine answers in blocks and sizes, not unit records, so that is what is
/// listed: each block the property has stock in, and under it each size with
/// how many are left. The tenant's next step is an enquiry, not a booking:
/// the one action here tells the landlord what they are after. The unit
/// routes are never asked, because a tenant's token cannot read them and
/// because the engine has already said what can be had.
class PropertySpacesScreen extends ConsumerWidget {
  const PropertySpacesScreen({required this.propertyId, super.key});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(availabilityProvider);
    final blocks = availability.whenData(
      (all) => all
          .where((block) => block.propertyId == propertyId)
          .toList(growable: false),
    );
    final name = blocks.value?.firstOrNull?.propertyName;

    return Scaffold(
      appBar: AppBar(title: Text(name ?? 'Available spaces')),
      body: switch (availability) {
        AsyncLoading() when !availability.hasValue => const AppSkeletonList(
          header: true,
        ),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.read(availabilityProvider.notifier).refresh(),
        ),
        _ => _SpacesList(blocks: blocks.requireValue),
      },
      // Offered whenever the engine has answered, even with nothing listed:
      // an enquiry is how a tenant asks about space that is not in stock yet.
      bottomNavigationBar: availability.hasValue
          ? AppBottomActionBar(
              child: FilledButton.icon(
                onPressed: () => context.pushNamed(
                  Routes.enquiry,
                  pathParameters: {'propertyId': propertyId},
                ),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Send enquiry'),
              ),
            )
          : null,
    );
  }
}

class _SpacesList extends ConsumerWidget {
  const _SpacesList({required this.blocks});

  final List<UnitAvailability> blocks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (blocks.isEmpty) {
      // The engine no longer names this property: everything was taken
      // between the list and the tap, or the link was stale.
      return EmptyState(
        onRefresh: () async {
          await ref.read(availabilityProvider.notifier).refresh();
        },
        icon: Icons.storefront_outlined,
        title: 'Nothing listed here right now',
        message:
            'Every space in this property has been taken. Pull down to check '
            'again, send an enquiry, or browse other properties.',
        action: FilledButton.tonal(
          // Browse is the page directly beneath this one, so going back to it
          // is a pop rather than another copy of it on the stack. The
          // fallback covers arriving here from a link, with nothing beneath.
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.pushNamed(Routes.browse);
            }
          },
          child: const Text('Back to browse'),
        ),
      );
    }

    final count = blocks.fold(0, (sum, block) => sum + block.count);

    return AppRefreshIndicator(
      onRefresh: () => ref.read(availabilityProvider.notifier).refresh(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            children: [
              PageHeader(
                eyebrow: 'Available now',
                title: blocks.first.propertyName,
                subtitle:
                    '$count ${count == 1 ? 'space is' : 'spaces are'} '
                    'available today. Send an enquiry and the landlord will '
                    'get back to you.',
                compact: true,
              ),
              Gap.h16,
              for (final block in blocks) ...[
                RecordGroup(
                  heading: block.blockName.isEmpty
                      ? 'Unnamed block'
                      : block.blockName,
                  trailing: Text(
                    '${block.count} available',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  children: [
                    for (final size in block.bySize)
                      if (size.count > 0) _SizeRow(size: size),
                  ],
                ),
                if (block != blocks.last) Gap.h16,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One size in a block, and how many of it are left.
class _SizeRow extends StatelessWidget {
  const _SizeRow({required this.size});

  final UnitAvailabilitySize size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return RecordRow(
      icon: Icons.storefront_outlined,
      iconColor: scheme.primary,
      title: size.label,
      subtitle: '${size.count} ${size.count == 1 ? 'unit' : 'units'} left',
    );
  }
}
