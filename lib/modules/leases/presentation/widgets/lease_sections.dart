import 'package:flutter/material.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/app_surface_card.dart';
import '../../../../components/surface_atoms.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/lease.dart';
import 'lease_facts.dart';

/// A titled block on the lease detail screen.
///
/// The screen is a document, so its parts are set as sections of one — a
/// heading, an optional figure beside it, and the content. Nothing is a card
/// merely to have a border.
class LeaseSection extends StatelessWidget {
  const LeaseSection({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSurfaceCard(
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: AppTypography.semibold,
                  ),
                ),
              ),
              if (trailing != null) ...[Gap.w12, trailing!],
            ],
          ),
          Gap.h16,
          child,
        ],
      ),
    );
  }
}

/// What the lease costs.
///
/// Section 55: these are the figures this lease was written at. A renewal
/// creates a new lease rather than editing this one, which is why the note at
/// the foot is worth the two lines it takes.
class LeaseMoneyCard extends StatelessWidget {
  const LeaseMoneyCard({required this.lease, super.key});

  final Lease lease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LeaseSection(
      title: 'Rent and deposit',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatRow(
            left: Stat(
              'Monthly rent',
              builder: (context, align) => AmountText(
                lease.monthlyRent,
                scale: AmountScale.title,
                align: align,
              ),
            ),
            right: Stat(
              'Security deposit',
              builder: (context, align) => AmountText(
                lease.depositAmount,
                scale: AmountScale.title,
                align: align,
              ),
            ),
          ),
          Gap.h16,
          const Hairline(),
          Gap.h16,
          StatRow(
            left: Stat('Billing', value: lease.billingFrequency.label),
            right: Stat(
              'Rent due',
              value: '${ordinalDay(lease.paymentDueDay)} of each month',
            ),
          ),
          Gap.h16,
          Text(
            'Your rent is fixed for this term. A renewal creates a new lease, '
            'so this one stays on your record unchanged.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section 30's checklist, read-only.
///
/// The app never decides that a lease may activate — the server owns that, and
/// the property manager still has to approve. This states where the tenant
/// stands, and how much of it is theirs to finish.
class LeaseActivationCard extends StatelessWidget {
  const LeaseActivationCard({required this.lease, super.key});

  final Lease lease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statuses = context.statusColors;
    final conditions = lease.activationConditions;
    if (conditions.isEmpty) return const SizedBox.shrink();

    final met = conditions.where((condition) => condition.isMet).length;
    final complete = met == conditions.length;
    final color = complete ? statuses.positive : statuses.progress;

    return LeaseSection(
      title: 'Activation checklist',
      trailing: Text(
        '$met of ${conditions.length}',
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: AppTypography.semibold,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearMeter(value: met / conditions.length, color: color),
          Gap.h16,
          for (final (index, condition) in conditions.indexed) ...[
            if (index > 0) Gap.h12,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  condition.isMet
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: condition.isMet ? statuses.positive : scheme.outline,
                ),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        condition.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: condition.isMet
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                          fontWeight: AppTypography.medium,
                        ),
                      ),
                      if (condition.detail != null ||
                          !condition.isMandatory) ...[
                        Gap.h4,
                        Text(
                          [
                            if (condition.detail != null) condition.detail!,
                            if (!condition.isMandatory) 'Optional',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The dates that make the lease a record rather than a page.
///
/// Section 85: a dispute is answerable only if the app can say when each step
/// happened, so what the server timestamps, this shows.
class LeaseRecordCard extends StatelessWidget {
  const LeaseRecordCard({required this.lease, super.key});

  final Lease lease;

  @override
  Widget build(BuildContext context) {
    final stats = <Stat>[
      if (lease.signedAt != null)
        Stat('Signed', value: AppDate.full(lease.signedAt!)),
      if (lease.activatedAt != null)
        Stat('Activated', value: AppDate.full(lease.activatedAt!)),
      if (lease.terminatedAt != null)
        Stat('Terminated', value: AppDate.full(lease.terminatedAt!)),
      Stat('Created', value: AppDate.full(lease.createdAt)),
    ];

    return LeaseSection(
      title: 'Record',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < stats.length; index += 2) ...[
            if (index > 0) Gap.h16,
            if (index + 1 < stats.length)
              StatRow(left: stats[index], right: stats[index + 1])
            else
              StatPair(
                label: stats[index].label,
                value: stats[index].value,
                valueWidget: stats[index].builder?.call(
                  context,
                  TextAlign.start,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Section 27's terms, as written.
class LeaseTermsCard extends StatelessWidget {
  const LeaseTermsCard({required this.title, required this.terms, super.key});

  final String title;
  final List<LeaseTerm> terms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LeaseSection(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, term) in terms.indexed) ...[
            if (index > 0) ...[Gap.h16, const Hairline(alpha: 0.5), Gap.h16],
            Text(
              term.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Gap.h4,
            Text(
              term.value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: AppTypography.medium,
              ),
            ),
            if (term.description != null) ...[
              Gap.h4,
              Text(
                term.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Section 29's signatures, and what they were made against.
class LeaseSignaturesCard extends StatelessWidget {
  const LeaseSignaturesCard({required this.signatures, super.key});

  final List<LeaseSignature> signatures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final positive = context.statusColors.positive;

    return LeaseSection(
      title: 'Signatures',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, signature) in signatures.indexed) ...[
            if (index > 0) ...[Gap.h16, const Hairline(alpha: 0.5), Gap.h16],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ToneIconTile(
                  icon: Icons.verified_outlined,
                  color: positive,
                  size: 36,
                ),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        signature.signerName ?? 'Tenant',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: AppTypography.medium,
                        ),
                      ),
                      Gap.h4,
                      Text(
                        '${signature.signatureType.label} · '
                        '${AppDate.dateTime(signature.signedAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (signature.documentHash != null) ...[
                        Gap.h8,
                        Text(
                          // Section 85: a dispute has to be answerable, and the
                          // hash is what ties a signature to one exact version
                          // of the agreement.
                          'Document ${signature.documentHash}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            // No monospace face is bundled, so naming one
                            // silently fell back to Manrope. Tabular figures and
                            // a little tracking give the hash the even,
                            // technical look the family was reaching for, using
                            // a font the app actually ships.
                            fontFeatures: const [FontFeature.tabularFigures()],
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// What signing will and will not do.
///
/// Shown while a signature is outstanding. Section 30 also requires the
/// deposit, the documents and the property manager's approval, so this is
/// careful not to promise that signing activates anything.
class LeaseSignatureNotice extends StatelessWidget {
  const LeaseSignatureNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = context.statusColors.progress;

    return AppSurfaceCard(
      color: progress.withValues(alpha: 0.06),
      borderColor: progress.withValues(alpha: 0.28),
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ToneIconTile(icon: Icons.draw_outlined, color: progress, size: 36),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready for your signature',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: progress,
                    fontWeight: AppTypography.semibold,
                  ),
                ),
                Gap.h4,
                Text(
                  'Read the agreement in full, then sign to send it to the '
                  'property manager for approval.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
