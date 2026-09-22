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

/// Section 45's "My Lease" screen: the Lease tab.
///
/// A tenant usually has one live lease, but section 54 requires a renewal to
/// create a new lease rather than overwrite the old one, so a tenant of any
/// standing accumulates them. Every lease is drawn the same way here — one
/// card each, the live or unsigned one leading — rather than one tall hero
/// with the rest demoted to list rows. A lease from two years ago is still an
/// agreement the tenant signed, and it states its own rent and term instead of
/// making them tap to find out.
class LeasesScreen extends ConsumerWidget {
  const LeasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leases = ref.watch(leaseListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My lease')),
      body: switch (leases) {
        AsyncLoading() when !leases.hasValue => const AppSkeletonDetail(
          heroHeight: 250,
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

    final ordered = _ordered(leases);

    return AppRefreshIndicator(
      onRefresh: refresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.xxl),
            itemCount: ordered.length,
            separatorBuilder: (_, _) => Gap.h16,
            itemBuilder: (context, index) {
              final lease = ordered[index];
              return AppReveal(
                index: index,
                child: LeaseHeroCard(
                  lease: lease,
                  // Renewals of the same unit are otherwise identical down to
                  // the unit number, so each card is headed by its own
                  // reference once there is a column of them.
                  showLeaseNumber: true,
                  actions: _actionsFor(context, lease),
                  // "Review and sign" carries a glyph and three words, so that
                  // pair needs more than half a phone and stacks; "Lease
                  // details" and "Agreement" fit across one and stay a row.
                  actionMinWidth: lease.status.needsTenantSignature ? 172 : 140,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The leases, in the order a tenant reads them.
  ///
  /// A signature that is being waited on outranks a live tenancy — it is the
  /// one thing on this screen the tenant can actually do something about — and
  /// a live tenancy outranks the record of one that has ended. Within a rank
  /// the most recent term leads.
  static List<Lease> _ordered(List<Lease> leases) {
    int rank(Lease lease) {
      if (lease.status.needsTenantSignature) return 0;
      if (lease.status.isCurrent) return 1;
      return 2;
    }

    return [...leases]..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : b.startDate.compareTo(a.startDate);
    });
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
