import 'package:flutter/material.dart';

import '../../../../components/app_surface_card.dart';
import '../../../../components/collection_columns.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/owner.dart';

class PortfolioPositionCard extends StatelessWidget {
  const PortfolioPositionCard({required this.portfolio, super.key});
  final OwnerPortfolio portfolio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DUE TO YOU THIS MONTH',
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white70,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          portfolio.netPayout.format(),
          style: theme.textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${portfolio.collectedThisMonth.format()} collected · ${portfolio.platformFee.format()} platform fee',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 18,
          runSpacing: 6,
          children: [
            Text(
              '${(portfolio.collectionRate * 100).round()}% collected',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppPalette.brass300,
              ),
            ),
            Text(
              'Rent roll ${portfolio.monthlyContractedRent.format()}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ],
    );
    return AppSurfaceCard(
      gradient: AppGradients.brandHero,
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760 ||
              portfolio.history.isEmpty ||
              MediaQuery.textScalerOf(context).scale(14) > 20) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                summary,
                if (portfolio.history.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    textColor: Colors.white,
                    collapsedTextColor: Colors.white70,
                    iconColor: Colors.white,
                    collapsedIconColor: Colors.white70,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: const Text('Collection performance'),
                    children: [
                      CollectionColumns.monthly(
                        months: portfolio.history,
                        height: 100,
                        ink: Colors.white,
                      ),
                    ],
                  ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: summary),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BILLED AGAINST COLLECTED',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CollectionColumns.monthly(
                      months: portfolio.history,
                      height: 80,
                      ink: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
