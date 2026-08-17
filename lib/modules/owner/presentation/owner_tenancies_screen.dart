import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/amount_text.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/record_group.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/owner.dart';
import '../../../navigation/routes.dart';
import '../application/owner_controller.dart';

/// Section 88. Who is in the buildings.
///
/// Ordered by what needs doing rather than by date: anyone behind on rent
/// first, then leases running out, then everything that is simply fine. A list
/// sorted by start date would bury both.
class OwnerTenanciesScreen extends ConsumerWidget {
  const OwnerTenanciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenancies = ref.watch(ownerTenanciesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Tenancies'),
        backgroundColor: Colors.transparent,
      ),
      body: switch (tenancies) {
        AsyncLoading() when !tenancies.hasValue => const AppSkeletonList(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(ownerTenanciesProvider),
        ),
        _ => _Tenancies(
          tenancies: tenancies.requireValue,
          onRefresh: () async => ref.invalidate(ownerTenanciesProvider),
        ),
      },
    );
  }
}

class _Tenancies extends StatelessWidget {
  const _Tenancies({required this.tenancies, required this.onRefresh});

  final List<OwnerTenancy> tenancies;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (tenancies.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.handshake_outlined,
                title: 'No tenancies yet',
                message:
                    'Leases appear here once a tenant has signed for a unit.',
              ),
            ),
          ],
        ),
      );
    }

    final arrears = tenancies.where((t) => t.isInArrears).toList();
    final expiring = tenancies
        .where((t) => !t.isInArrears && t.isExpiringSoon)
        .toList();
    final active = tenancies
        .where(
          (t) => !t.isInArrears && !t.isExpiringSoon && t.status.isCurrent,
        )
        .toList();
    final ended = tenancies.where((t) => !t.status.isCurrent).toList();

    final groups = <Widget>[
      if (arrears.isNotEmpty) _Group(heading: 'In arrears', tenancies: arrears),
      if (expiring.isNotEmpty)
        _Group(heading: 'Expiring soon', tenancies: expiring),
      if (active.isNotEmpty) _Group(heading: 'Active', tenancies: active),
      if (ended.isNotEmpty) _Group(heading: 'Ended', tenancies: ended),
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxReadingWidth),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            itemCount: groups.length,
            separatorBuilder: (_, _) => Gap.h24,
            itemBuilder: (context, index) =>
                AppReveal(index: index, child: groups[index]),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.heading, required this.tenancies});

  final String heading;
  final List<OwnerTenancy> tenancies;

  @override
  Widget build(BuildContext context) {
    final statuses = context.statusColors;

    return RecordGroup(
      heading: heading,
      children: [
        for (final tenancy in tenancies)
          RecordRow(
            icon: tenancy.isInArrears
                ? Icons.error_outline_rounded
                : Icons.storefront_outlined,
            iconColor: statuses.resolve(
              tenancy.isInArrears
                  ? StatusTone.danger
                  : tenancy.isExpiringSoon
                  ? StatusTone.warning
                  : tenancy.status.tone,
            ),
            title: tenancy.tenantName,
            subtitle: '${tenancy.unitNumber} · ${tenancy.propertyName}',
            amount: AmountText(tenancy.monthlyRent),
            caption: tenancy.isInArrears
                ? '${tenancy.overdue.format()} overdue'
                : 'Ends ${AppDate.short(tenancy.endDate)}',
            captionColor: tenancy.isInArrears ? statuses.danger : null,
            onTap: () => context.pushNamed(
              Routes.ownerTenancy,
              pathParameters: {'leaseId': tenancy.leaseId},
            ),
          ),
      ],
    );
  }
}
