import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/app_surface_card.dart';
import '../../../../components/surface_atoms.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/lease.dart';
import '../../../../navigation/routes.dart';

/// The leases that are not the one being shown above.
///
/// Section 54 requires a renewal to create a new lease rather than overwrite
/// the old one, so this list is the tenant's record of every agreement they
/// have held — and it has to stay reachable without competing with the live
/// one.
class LeaseHistorySection extends StatelessWidget {
  const LeaseHistorySection({
    required this.title,
    required this.leases,
    super.key,
  });

  final String title;
  final List<Lease> leases;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xs, 0, Gap.xs, Gap.sm),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ),
        AppSurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (index, lease) in leases.indexed) ...[
                if (index > 0)
                  const Padding(
                    padding: EdgeInsets.only(left: 68),
                    child: Hairline(),
                  ),
                LeaseRow(lease: lease),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One lease, as a line of the record.
class LeaseRow extends StatelessWidget {
  const LeaseRow({required this.lease, super.key});

  final Lease lease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = context.statusColors.resolve(lease.status.tone);
    final stacked = prefersStacked(context);

    final leading = ToneIconTile(icon: _icon, color: tone, size: 40);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unit ${lease.unitNumber ?? '—'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: AppTypography.semibold,
          ),
        ),
        Gap.h4,
        Text(
          '${AppDate.short(lease.startDate)} – '
          '${AppDate.short(lease.endDate)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final trailing = Column(
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        AmountText(
          lease.monthlyRent,
          align: stacked ? TextAlign.start : TextAlign.end,
        ),
        Gap.h4,
        Text(
          lease.status.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: lease.status.isCurrent || lease.status.needsTenantSignature
                ? tone
                : scheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return InkWell(
      onTap: () => context.pushNamed(
        Routes.leaseDetail,
        pathParameters: {'leaseId': lease.id},
      ),
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leading,
                      Gap.w12,
                      Expanded(child: title),
                    ],
                  ),
                  Gap.h12,
                  trailing,
                ],
              )
            : Row(
                children: [
                  leading,
                  Gap.w12,
                  Expanded(flex: 5, child: title),
                  Gap.w12,
                  Expanded(flex: 4, child: trailing),
                ],
              ),
      ),
    );
  }

  IconData get _icon {
    if (lease.status.needsTenantSignature) return Icons.draw_outlined;
    if (lease.status.isCurrent) return Icons.vpn_key_outlined;
    return Icons.history_rounded;
  }
}
