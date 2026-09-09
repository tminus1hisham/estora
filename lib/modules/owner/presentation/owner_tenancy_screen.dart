import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/amount_text.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/page_header.dart';
import '../../../components/record_group.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../components/surface_atoms.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/owner.dart';
import '../../../navigation/routes.dart';
import '../application/owner_controller.dart';

/// Section 88. One tenancy, from the owner's side.
class OwnerTenancyScreen extends ConsumerWidget {
  const OwnerTenancyScreen({required this.leaseId, super.key});

  final String leaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenancy = ref.watch(ownerTenancyProvider(leaseId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(tenancy.value?.unitNumber ?? 'Tenancy'),
        backgroundColor: Colors.transparent,
      ),
      body: switch (tenancy) {
        AsyncLoading() when !tenancy.hasValue => const AppSkeletonDetail(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(ownerTenancyProvider(leaseId)),
        ),
        _ => _Tenancy(
          tenancy: tenancy.requireValue,
          onRefresh: () async => ref.invalidate(ownerTenancyProvider(leaseId)),
        ),
      },
    );
  }
}

class _Tenancy extends StatelessWidget {
  const _Tenancy({required this.tenancy, required this.onRefresh});

  final OwnerTenancy tenancy;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final statuses = context.statusColors;

    final sections = <Widget>[
      PageHeader(
        eyebrow: '${tenancy.unitNumber} · ${tenancy.propertyName}',
        title: tenancy.tenantName,
        subtitle: 'Lease ${tenancy.leaseNumber}',
        trailing: StatusChip(
          label: tenancy.status.label,
          tone: tenancy.status.tone,
        ),
      ),
      SectionCard(
        title: 'Term',
        children: [
          DetailRow(
            label: 'Runs',
            value:
                '${AppDate.short(tenancy.startDate)} – '
                '${AppDate.short(tenancy.endDate)}',
          ),
          Gap.h12,
          LinearMeter(
            value: tenancy.termProgress,
            color: tenancy.isExpiringSoon
                ? statuses.warning
                : statuses.positive,
          ),
          Gap.h12,
          Text(
            tenancy.daysUntilExpiry < 0
                ? 'Ended ${AppDate.relativeDays(tenancy.endDate)}'
                : 'Ends ${AppDate.relativeDays(tenancy.endDate)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      SectionCard(
        title: 'Money',
        children: [
          DetailRow(
            label: 'Monthly rent',
            valueWidget: AmountText(tenancy.monthlyRent, align: TextAlign.end),
            emphasise: true,
          ),
          DetailRow(
            label: 'Deposit held',
            valueWidget: AmountText(
              tenancy.depositAmount,
              align: TextAlign.end,
            ),
          ),
          DetailRow(
            label: 'Outstanding',
            valueWidget: AmountText(
              tenancy.outstanding,
              align: TextAlign.end,
              color: tenancy.isInArrears ? statuses.danger : null,
            ),
          ),
          if (tenancy.lastPaymentAt != null)
            DetailRow(
              label: 'Last payment',
              value: AppDate.short(tenancy.lastPaymentAt!),
            ),
          Gap.h12,
          Text(
            // Worth stating on the screen where an owner might expect the rent
            // to have followed a repricing.
            'The rent on a signed lease is fixed for its term. Changing the '
            'property rate affects what unlet units ask, not this agreement.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      RecordGroup(
        heading: 'Records',
        rowInset: 56,
        children: [
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Invoices'),
            subtitle: Text(
              tenancy.outstanding.isPositive
                  ? '${tenancy.outstanding.format()} outstanding.'
                  : 'Everything billed so far is settled.',
            ),
            onTap: () => context.pushNamed(
              Routes.tenantInvoices,
              pathParameters: {'tenantId': tenancy.tenantId},
              queryParameters: {'name': tenancy.tenantName},
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Lease agreement'),
            subtitle: const Text('The signed wording, read-only.'),
            onTap: () => context.pushNamed(
              Routes.ownerAgreement,
              pathParameters: {'leaseId': tenancy.leaseId},
            ),
          ),
        ],
      ),
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
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
