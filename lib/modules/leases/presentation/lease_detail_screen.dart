import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_bottom_action_bar.dart';
import '../../../components/money_text.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/lease.dart';
import '../../../navigation/routes.dart';
import '../application/lease_controller.dart';

/// Section 77's Lease Details screen.
class LeaseDetailScreen extends ConsumerWidget {
  const LeaseDetailScreen({required this.leaseId, super.key});

  final String leaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lease = ref.watch(leaseDetailProvider(leaseId));

    return Scaffold(
      appBar: AppBar(title: Text(lease.value?.leaseNumber ?? 'Lease')),
      body: switch (lease) {
        AsyncLoading() when !lease.hasValue => const LoadingView(),
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
                      icon: const Icon(Icons.draw_outlined),
                      label: const Text('Review and sign'),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => context.pushNamed(
                        Routes.leaseAgreement,
                        pathParameters: {'leaseId': leaseId},
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
    final scheme = Theme.of(context).colorScheme;

    // Section 27's terms, grouped by their heading.
    final grouped = <String, List<LeaseTerm>>{};
    for (final term in lease.terms) {
      grouped.putIfAbsent(term.group ?? 'Terms', () => []).add(term);
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(leaseDetailProvider(lease.id)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            children: [
              if (lease.status.needsTenantSignature) ...[
                Card(
                  color: scheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ready for your signature',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        Gap.h8,
                        Text(
                          'Read the agreement in full, then sign to send it to the '
                          'property manager for approval.',
                          style: TextStyle(color: scheme.onPrimaryContainer),
                        ),
                        Gap.h12,
                      ],
                    ),
                  ),
                ),
                Gap.h12,
              ],

              SectionCard(
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Gap.md,
                    runSpacing: Gap.sm,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unit ${lease.unitNumber ?? '—'}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            lease.propertyName ?? '',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
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
                  DetailRow(label: 'Lease number', value: lease.leaseNumber),
                  DetailRow(
                    label: 'Term',
                    value:
                        '${AppDate.full(lease.startDate)} – '
                        '${AppDate.full(lease.endDate)}',
                  ),
                  if (lease.activatedAt != null)
                    DetailRow(
                      label: 'Activated',
                      value: AppDate.full(lease.activatedAt!),
                    ),
                  if (lease.status.isCurrent)
                    DetailRow(
                      label: 'Time remaining',
                      value: '${lease.daysUntilExpiry} days',
                    ),
                ],
              ),

              Gap.h12,
              SectionCard(
                title: 'Financial',
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Gap.lg),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MONTHLY RENT',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.primary,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Gap.h4,
                        MoneyText(lease.monthlyRent, emphasise: true),
                      ],
                    ),
                  ),
                  Gap.h12,
                  DetailRow(
                    label: 'Security deposit',
                    valueWidget: MoneyText(lease.depositAmount),
                  ),
                  DetailRow(
                    label: 'Billing frequency',
                    value: lease.billingFrequency.label,
                  ),
                  DetailRow(
                    label: 'Rent due',
                    value: '${_ordinal(lease.paymentDueDay)} of each month',
                  ),
                  Gap.h8,
                  Text(
                    // Sections 54 and 55, said plainly.
                    'Your rent is fixed for this term. A renewal creates a new '
                    'lease, so this one stays on your record unchanged.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              // Section 30's checklist, read-only. The app never decides that a
              // lease may activate.
              if (lease.activationConditions.isNotEmpty) ...[
                Gap.h12,
                SectionCard(
                  title: 'Activation checklist',
                  children: [
                    for (final condition in lease.activationConditions)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              condition.isMet
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 20,
                              color: condition.isMet
                                  ? context.statusColors.positive
                                  : scheme.outline,
                            ),
                            Gap.w12,
                            Expanded(child: Text(condition.label)),
                            if (condition.detail != null) ...[
                              Gap.w8,
                              Flexible(
                                child: Text(
                                  condition.detail!,
                                  textAlign: TextAlign.right,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ],

              // Section 27.
              for (final entry in grouped.entries) ...[
                Gap.h12,
                SectionCard(
                  title: entry.key,
                  children: [
                    for (final term in entry.value)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              term.label,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            Gap.h4,
                            Text(term.value),
                          ],
                        ),
                      ),
                  ],
                ),
              ],

              // Section 29.
              if (lease.signatures.isNotEmpty) ...[
                Gap.h12,
                SectionCard(
                  title: 'Signatures',
                  children: [
                    for (final signature in lease.signatures)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.verified_outlined,
                                  size: 18,
                                  color: context.statusColors.positive,
                                ),
                                Gap.w8,
                                Expanded(
                                  child: Text(
                                    signature.signerName ?? 'Tenant',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  AppDate.short(signature.signedAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            Gap.h4,
                            Text(
                              signature.signatureType.label,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            if (signature.documentHash != null)
                              Text(
                                // Section 85: a dispute has to be answerable, and
                                // the hash is what ties a signature to one exact
                                // version of the agreement.
                                'Document ${signature.documentHash}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      // No monospace face is bundled, so naming
                                      // one silently fell back to Manrope.
                                      // Tabular figures and a little tracking
                                      // give the hash the even, technical look
                                      // the family was reaching for, using a
                                      // font the app actually ships.
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                      letterSpacing: 0.6,
                                    ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    return switch (day % 10) {
      1 => '${day}st',
      2 => '${day}nd',
      3 => '${day}rd',
      _ => '${day}th',
    };
  }
}
