import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/state_views.dart';
import '../../../components/page_empty_state.dart';
import '../../../components/surface_atoms.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/lease.dart';
import '../../../navigation/routes.dart';
import '../application/lease_controller.dart';
import 'widgets/lease_hero_card.dart';
import 'widgets/lease_list.dart';

/// Section 45's "My Lease" tab.
///
/// A tenant usually has one live lease, but section 54 requires a renewal to
/// create a new lease rather than overwrite the old one, so the history has to
/// remain reachable. That shape — one agreement that matters and a record
/// behind it — is now what the screen looks like: the live lease as a single
/// tall surface, and everything else as a quiet list under it.
class LeasesScreen extends ConsumerWidget {
  const LeasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leases = ref.watch(leaseListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My lease')),
      body: switch (leases) {
        AsyncLoading() when !leases.hasValue => const AppSkeletonDetail(
          heroHeight: 300,
        ),
        AsyncError(error: UnsupportedFeatureFailure()) => PageEmptyState(
          onRefresh: () async {
            await ref.read(leaseListProvider.notifier).refresh();
          },
          icon: Icons.key_outlined,
          caption: 'Your next chapter',
          title: 'Your lease belongs here',
          message:
              'Lease management is on its way. This will be your place to review agreements and keep your lease details together.',
        ),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.read(leaseListProvider.notifier).refresh(),
        ),
        _ => _LeaseBody(leases: leases.requireValue),
      },
    );
  }
}

class _LeaseBody extends ConsumerWidget {
  const _LeaseBody({required this.leases});

  final List<Lease> leases;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() => ref.read(leaseListProvider.notifier).refresh();

    if (leases.isEmpty) {
      return PageEmptyState(
        icon: Icons.key_outlined,
        caption: 'Your next chapter',
        title: 'No lease yet',
        message:
            'Find a space for your business. Once your booking is ready, your lease will appear here to review and sign.',
        onRefresh: refresh,
        action: FilledButton.icon(
          onPressed: () => context.goNamed(Routes.browse),
          icon: const Icon(Icons.search_rounded),
          label: const Text('Browse available units'),
        ),
      );
    }

    final primary = _primaryOf(leases);
    final rest = leases.where((lease) => lease.id != primary.id).toList();

    final sections = <Widget>[
      LeaseHeroCard(lease: primary, actions: _actionsFor(context, primary)),
      if (rest.isNotEmpty)
        LeaseHistorySection(
          title:
              rest.any(
                (lease) =>
                    lease.status.isCurrent || lease.status.needsTenantSignature,
              )
              ? 'Other leases'
              : 'Previous leases',
          leases: rest,
        ),
    ];

    return AppRefreshIndicator(
      onRefresh: refresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.xxl),
            itemCount: sections.length,
            separatorBuilder: (_, _) => Gap.h32,
            itemBuilder: (context, index) =>
                AppReveal(index: index, child: sections[index]),
          ),
        ),
      ),
    );
  }

  /// The lease the screen is about.
  ///
  /// A signature that is being waited on outranks a live tenancy: it is the one
  /// thing on this screen the tenant can actually do something about.
  static Lease _primaryOf(List<Lease> leases) {
    final ordered = [...leases]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return ordered.firstWhere(
      (lease) => lease.status.needsTenantSignature,
      orElse: () => ordered.firstWhere(
        (lease) => lease.status.isCurrent,
        orElse: () => ordered.first,
      ),
    );
  }

  static List<Widget> _actionsFor(BuildContext context, Lease lease) {
    void openDetail() => context.pushNamed(
      Routes.leaseDetail,
      pathParameters: {'leaseId': lease.id},
    );

    if (lease.status.needsTenantSignature) {
      return [
        OnDarkAction(
          label: 'Review and sign',
          icon: Icons.draw_outlined,
          style: OnDarkActionStyle.primary,
          onPressed: () => context.pushNamed(
            Routes.signAgreement,
            pathParameters: {'leaseId': lease.id},
          ),
        ),
        OnDarkAction(label: 'Lease details', onPressed: openDetail),
      ];
    }

    return [
      OnDarkAction(
        label: 'Lease details',
        style: OnDarkActionStyle.tonal,
        onPressed: openDetail,
      ),
      OnDarkAction(
        label: 'Agreement',
        onPressed: () => context.pushNamed(
          Routes.leaseAgreement,
          pathParameters: {'leaseId': lease.id},
        ),
      ),
    ];
  }
}
