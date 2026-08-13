import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_bottom_action_bar.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/lease.dart';
import '../../../navigation/routes.dart';
import '../application/lease_controller.dart';
import 'widgets/lease_hero_card.dart';
import 'widgets/lease_sections.dart';

/// Section 77's Lease Details screen.
///
/// The tenancy on the brand surface, then what it costs, then what is still
/// outstanding, then the terms as written and the signatures against them —
/// in that order, because that is the order the questions arrive in.
class LeaseDetailScreen extends ConsumerWidget {
  const LeaseDetailScreen({required this.leaseId, super.key});

  final String leaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lease = ref.watch(leaseDetailProvider(leaseId));

    return Scaffold(
      appBar: AppBar(title: Text(lease.value?.leaseNumber ?? 'Lease')),
      body: switch (lease) {
        AsyncLoading() when !lease.hasValue => const AppSkeletonDetail(
          heroHeight: 300,
        ),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(leaseDetailProvider(leaseId)),
        ),
        _ => _Body(lease: lease.requireValue),
      },
      bottomNavigationBar: lease.hasValue
          ? AppBottomActionBar(
              child: lease.requireValue.status.needsTenantSignature
                  ? FilledButton.icon(
                      onPressed: () => context.pushNamed(
                        Routes.signAgreement,
                        pathParameters: {'leaseId': leaseId},
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          AppLayout.controlHeight,
                        ),
                      ),
                      icon: const Icon(Icons.draw_outlined),
                      label: const Text('Review and sign'),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => context.pushNamed(
                        Routes.leaseAgreement,
                        pathParameters: {'leaseId': leaseId},
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          AppLayout.controlHeight,
                        ),
                      ),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('View the agreement'),
                    ),
            )
          : null,
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.lease});

  final Lease lease;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Section 27's terms, grouped by their heading.
    final grouped = <String, List<LeaseTerm>>{};
    for (final term in lease.terms) {
      grouped.putIfAbsent(term.group ?? 'Terms', () => []).add(term);
    }

    final sections = <Widget>[
      LeaseHeroCard(lease: lease, showLeaseNumber: true),
      if (lease.status.needsTenantSignature) const LeaseSignatureNotice(),
      LeaseMoneyCard(lease: lease),
      if (lease.activationConditions.isNotEmpty)
        LeaseActivationCard(lease: lease),
      for (final entry in grouped.entries)
        LeaseTermsCard(title: entry.key, terms: entry.value),
      if (lease.signatures.isNotEmpty)
        LeaseSignaturesCard(signatures: lease.signatures),
      LeaseRecordCard(lease: lease),
    ];

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(leaseDetailProvider(lease.id)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.xxl),
            itemCount: sections.length,
            separatorBuilder: (_, _) => Gap.h16,
            itemBuilder: (context, index) =>
                AppReveal(index: index, child: sections[index]),
          ),
        ),
      ),
    );
  }
}
