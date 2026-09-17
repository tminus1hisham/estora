import 'package:flutter/material.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/app_glass.dart';
import '../../../../components/app_surface_card.dart';
import '../../../../components/collection_columns.dart';
import '../../../../components/money_count_up.dart';
import '../../../../components/surface_atoms.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../domain/entities/owner.dart';

/// The figure the owner opens the app to find: what is coming to them this
/// month, after the platform's cut.
///
/// Set in the quiet money style the rest of the app uses — medium weight at
/// hero scale, emphasis carried by size and the line beneath rather than by
/// shouting the number. An owner reading a good month and an owner reading a
/// bad one should not be met with the same alarm.
class PortfolioPositionCard extends StatelessWidget {
  const PortfolioPositionCard({required this.portfolio, super.key});

  final OwnerPortfolio portfolio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statuses = context.statusColors;

    return AppSurfaceCard(
      gradient: AppGradients.brandHero,
      borderColor: Colors.transparent,
      padding: EdgeInsets.zero,
      shadows: AppElevation.lifted(
        AppPalette.navy950,
        level: 3,
        brightness: theme.brightness,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: SoftGlow(
              color: AppPalette.brass500.withValues(alpha: 0.34),
              size: 220,
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: SoftGlow(
              color: AppPalette.azure500.withValues(alpha: 0.12),
              size: 240,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BadgedHeader(
                  badge: TonePill(
                    label:
                        '${(portfolio.collectionRate * 100).round()}% collected',
                    tone: portfolio.collectionRate >= 0.9
                        ? StatusTone.positive
                        : StatusTone.warning,
                  ),
                  child: Text(
                    'DUE TO YOU THIS MONTH',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: kOnDark.withValues(alpha: 0.62),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Gap.h12,
                MoneyCountUp(portfolio.netPayout, scale: AmountScale.hero),
                Gap.h8,
                Text(
                  portfolio.platformFee.isZero
                      ? 'Collected across ${portfolio.propertyCount} '
                            'propert${portfolio.propertyCount == 1 ? 'y' : 'ies'}'
                      : '${portfolio.collectedThisMonth.format()} collected, '
                            'less ${portfolio.platformFee.format()} platform fee',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kOnDark.withValues(alpha: 0.62),
                  ),
                ),

                Gap.h16,
                // Glass is honest here: the ambient glows above genuinely pass
                // behind this pane.
                GlassSurface(
                  onDark: true,
                  padding: const EdgeInsets.all(Gap.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatRow(
                        onDark: true,
                        left: Stat(
                          'Rent roll',
                          builder: (context, align) => AmountText(
                            portfolio.monthlyContractedRent,
                            color: kOnDark,
                            align: align,
                          ),
                        ),
                        right: Stat(
                          'Outstanding',
                          builder: (context, align) => AmountText(
                            portfolio.outstanding,
                            color: portfolio.overdue.isPositive
                                ? statuses.danger
                                : kOnDark,
                            align: align,
                          ),
                        ),
                      ),
                      Gap.h16,
                      LinearMeter(
                        value: portfolio.collectionRate,
                        color: portfolio.collectionRate >= 0.9
                            ? statuses.positive
                            : statuses.warning,
                        trackColor: kOnDark.withValues(alpha: 0.16),
                      ),
                    ],
                  ),
                ),

                if (portfolio.history.isNotEmpty) ...[
                  Gap.h24,
                  Text(
                    'BILLED AGAINST COLLECTED',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: kOnDark.withValues(alpha: 0.62),
                      letterSpacing: 1.2,
                    ),
                  ),
                  Gap.h12,
                  CollectionColumns.monthly(
                    months: portfolio.history,
                    height: 108,
                    ink: kOnDark,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
