import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/money_text.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/unit.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../navigation/routes.dart';
import '../application/unit_controller.dart';

/// Section 77's Unit Details screen.
class UnitDetailScreen extends ConsumerWidget {
  const UnitDetailScreen({required this.unitId, super.key});

  final String unitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitAsync = ref.watch(unitDetailProvider(unitId));

    return Scaffold(
      appBar: AppBar(title: Text(unitAsync.value?.unitNumber ?? 'Unit')),
      body: switch (unitAsync) {
        AsyncLoading() when !unitAsync.hasValue => const LoadingView(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(unitDetailProvider(unitId)),
        ),
        _ => _Body(unit: unitAsync.requireValue),
      },
      bottomNavigationBar: unitAsync.hasValue
          ? _BookingBar(unit: unitAsync.requireValue)
          : null,
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.unit});

  final Unit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final pricing = ref.watch(unitPricingProvider(unit.id)).value ?? const [];
    final futurePricing = pricing.where((p) => !p.isActive).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
      children: [
        Container(
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: scheme.surfaceContainerHighest,
          ),
          child: Center(
            child: Icon(
              Icons.storefront_outlined,
              size: 52,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Gap.h16,
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit.name ?? unit.unitNumber,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    unit.locationLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            StatusChip(label: unit.status.label, tone: unit.status.tone),
          ],
        ),
        if (unit.description != null) ...[Gap.h16, Text(unit.description!)],
        Gap.h16,

        SectionCard(
          title: 'The space',
          children: [
            DetailRow(label: 'Unit number', value: unit.unitNumber),
            DetailRow(label: 'Reference', value: unit.unitCode),
            if (unit.dimensionsLabel != null)
              DetailRow(label: 'Dimensions', value: unit.dimensionsLabel!),
            if (unit.areaLabel != null)
              DetailRow(label: 'Area', value: unit.areaLabel!),
          ],
        ),

        Gap.h12,
        SectionCard(
          title: 'Cost',
          children: [
            DetailRow(
              label: 'Rent ${unit.billingFrequency.perPeriod}',
              valueWidget: MoneyText(unit.baseRent),
              emphasise: true,
            ),
            if (unit.depositMonths != null)
              DetailRow(
                label: 'Deposit',
                value: '${unit.depositMonths} months of rent',
              ),
            if (unit.bookingFee != null)
              DetailRow(
                label: 'Booking fee',
                valueWidget: MoneyText(unit.bookingFee!),
              ),
            Gap.h8,
            Text(
              // Section 65: the listed figures are indicative. The payable
              // amount is quoted by the server on the booking screen, and this
              // sets that expectation rather than implying the app added them
              // up.
              'These are the current listed terms. The exact amount payable is '
              'confirmed when you start a booking.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),

        // Section 19: effective-dated pricing. Worth showing before someone
        // commits to a lease that will renew into a higher rent.
        if (futurePricing.isNotEmpty) ...[
          Gap.h12,
          SectionCard(
            title: 'Scheduled rent changes',
            children: [
              for (final price in futurePricing)
                DetailRow(
                  label: 'From ${AppDate.short(price.effectiveFrom)}',
                  valueWidget: MoneyText(price.amount),
                ),
              Gap.h8,
              Text(
                'A change here does not affect an existing lease — your rent is '
                'fixed for the term you sign.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],

        // Section 18.
        if (unit.requirements.isNotEmpty) ...[
          Gap.h12,
          SectionCard(
            title: 'What you will need',
            children: [
              for (final requirement in unit.requirements)
                _RequirementRow(requirement: requirement),
            ],
          ),
        ],
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.requirement});

  final UnitRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            switch (requirement.requirementType) {
              RequirementType.document => Icons.description_outlined,
              RequirementType.payment => Icons.payments_outlined,
              RequirementType.approval => Icons.verified_outlined,
              RequirementType.custom ||
              RequirementType.unknown => Icons.check_circle_outline_rounded,
            },
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        requirement.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (!requirement.isMandatory) ...[
                      Gap.w8,
                      Text(
                        'optional',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                if (requirement.description != null)
                  Text(
                    requirement.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The book action, and the explanation when it is unavailable.
class _BookingBar extends StatelessWidget {
  const _BookingBar({required this.unit});

  final Unit unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!unit.isBookable) ...[
              Text(
                switch (unit.status) {
                  UnitStatus.leased => 'This unit is currently let.',
                  UnitStatus.reserved ||
                  UnitStatus.booked =>
                    'Someone is holding this unit. It may become available '
                        'again if their booking lapses.',
                  UnitStatus.underMaintenance =>
                    'This unit is under maintenance.',
                  _ => 'This unit is not available to book.',
                },
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              Gap.h8,
            ],
            FilledButton.icon(
              // A disabled button is only an affordance. Section 48 puts the
              // real check inside a locking transaction on the server, so a
              // booking attempt can still come back with a conflict if the
              // unit went while this screen was open.
              onPressed: unit.isBookable
                  ? () => context.pushNamed(
                      Routes.booking,
                      pathParameters: {'unitId': unit.id},
                    )
                  : null,
              icon: const Icon(Icons.event_available_outlined),
              label: Text(
                unit.isBookable ? 'Book this unit' : 'Not available',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
