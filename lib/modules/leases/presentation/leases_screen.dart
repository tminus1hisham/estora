import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/money_text.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/summary_banner.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/lease.dart';
import '../../../navigation/routes.dart';
import '../application/lease_controller.dart';

/// Section 45's "My Lease" tab.
///
/// A tenant usually has one live lease, but section 54 requires a renewal to
/// create a new lease rather than overwrite the old one, so this is a list —
/// the history has to remain reachable.
class LeasesScreen extends ConsumerWidget {
  const LeasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leases = ref.watch(leaseListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My lease')),
      body: switch (leases) {
        AsyncLoading() when !leases.hasValue => const AppSkeletonList(
          header: true,
        ),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.read(leaseListProvider.notifier).refresh(),
        ),
        _ => _LeaseList(leases: leases.requireValue),
      },
    );
  }
}

class _LeaseList extends ConsumerWidget {
  const _LeaseList({required this.leases});

  final List<Lease> leases;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (leases.isEmpty) {
      return EmptyState(
        icon: Icons.description_outlined,
        title: 'No lease yet',
        message:
            'Once you book a unit and complete the requirements, your lease '
            'will appear here to review and sign.',
        action: FilledButton.tonal(
          onPressed: () => context.goNamed(Routes.browse),
          child: const Text('Browse available units'),
        ),
      );
    }

    final currentCount = leases.where((item) => item.status.isCurrent).length;
    final signatureCount = leases
        .where((item) => item.status.needsTenantSignature)
        .length;

    return RefreshIndicator(
      onRefresh: () => ref.read(leaseListProvider.notifier).refresh(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            itemCount: leases.length + 1,
            separatorBuilder: (_, _) => Gap.h12,
            itemBuilder: (context, index) => index == 0
                ? _LeaseOverview(
                    total: leases.length,
                    current: currentCount,
                    awaitingSignature: signatureCount,
                  )
                : _LeaseCard(lease: leases[index - 1]),
          ),
        ),
      ),
    );
  }
}

class _LeaseOverview extends StatelessWidget {
  const _LeaseOverview({
    required this.total,
    required this.current,
    required this.awaitingSignature,
  });

  final int total;
  final int current;
  final int awaitingSignature;

  @override
  Widget build(BuildContext context) {
    return SummaryBanner(
      icon: Icons.description_outlined,
      headline: awaitingSignature > 0
          ? 'Your signature is needed'
          : current > 0
          ? 'Your tenancy is active'
          : 'Your lease records',
      caption: awaitingSignature > 0
          ? '$awaitingSignature ${awaitingSignature == 1 ? 'agreement is' : 'agreements are'} ready to review.'
          : '$current current · $total total',
      counts: [
        SummaryCount(label: 'Current', value: current),
        SummaryCount(
          label: 'To sign',
          value: awaitingSignature,
          tone: Theme.of(context).colorScheme.tertiary,
        ),
        SummaryCount(label: 'Total', value: total),
      ],
    );
  }
}

class _LeaseCard extends StatelessWidget {
  const _LeaseCard({required this.lease});

  final Lease lease;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: () => context.pushNamed(
          Routes.leaseDetail,
          pathParameters: {'leaseId': lease.id},
        ),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Gap.md,
                runSpacing: Gap.sm,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.6),
                          borderRadius: AppRadius.small,
                        ),
                        child: Icon(
                          Icons.key_outlined,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      Gap.w12,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unit ${lease.unitNumber ?? '—'}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: AppTypography.bold),
                          ),
                          Text(
                            lease.propertyName ?? '',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                  StatusChip(
                    label: lease.status.label,
                    tone: lease.status.tone,
                  ),
                ],
              ),
              Gap.h12,
              Divider(color: scheme.outlineVariant),
              Gap.h12,
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: Gap.md,
                runSpacing: Gap.md,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Term',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${AppDate.short(lease.startDate)} – '
                        '${AppDate.short(lease.endDate)}',
                        style: const TextStyle(
                          fontWeight: AppTypography.semibold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Monthly rent',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      MoneyText(lease.monthlyRent),
                    ],
                  ),
                ],
              ),
              if (lease.status.needsTenantSignature) ...[
                Gap.h12,
                FilledButton.icon(
                  onPressed: () => context.pushNamed(
                    Routes.signAgreement,
                    pathParameters: {'leaseId': lease.id},
                  ),
                  icon: const Icon(Icons.draw_outlined),
                  label: const Text('Review and sign'),
                ),
              ],
              if (lease.isExpiringSoon) ...[
                Gap.h8,
                Text(
                  'Expires in ${lease.daysUntilExpiry} days',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
