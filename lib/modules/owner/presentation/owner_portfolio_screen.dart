import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/record_group.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../domain/entities/owner.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../navigation/routes.dart';
import '../application/owner_controller.dart';
import 'widgets/owner_property_card.dart';
import 'widgets/portfolio_position_card.dart';

/// Section 88. What the owner opens the app to see.
///
/// Three movements, the same shape the tenant's screens settled on. The figure
/// the screen exists for is lifted out and set on the brand surface; what needs
/// acting on is a short record beneath it; the portfolio itself is last,
/// because it is the thing you browse rather than the thing you check.
class OwnerPortfolioScreen extends ConsumerWidget {
  const OwnerPortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolio = ref.watch(ownerPortfolioProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Manager'),
        backgroundColor: Colors.transparent,
      ),
      body: switch (portfolio) {
        AsyncLoading() when !portfolio.hasValue => const AppSkeletonList(
          header: true,
        ),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.read(ownerPortfolioProvider.notifier).refresh(),
        ),
        _ => _Portfolio(
          portfolio: portfolio.requireValue,
          onRefresh: () => ref.read(ownerPortfolioProvider.notifier).refresh(),
        ),
      },
    );
  }
}

class _Portfolio extends StatelessWidget {
  const _Portfolio({required this.portfolio, required this.onRefresh});

  final OwnerPortfolio portfolio;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (!portfolio.hasProperties) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.apartment_outlined,
                title: 'No properties yet',
                message:
                    'Add a property and set its rate per square metre to start '
                    'letting space.',
              ),
            ),
          ],
        ),
      );
    }

    final sections = <Widget>[
      PortfolioPositionCard(portfolio: portfolio),
      if (portfolio.hasAlerts) _AlertRail(alerts: portfolio.alerts),
      _PropertyList(properties: portfolio.properties),
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
            separatorBuilder: (_, _) => Gap.h24,
            itemBuilder: (context, index) =>
                AppReveal(index: index, child: sections[index]),
          ),
        ),
      ),
    );
  }
}

/// What is asking to be dealt with, as a record rather than a stack of cards.
class _AlertRail extends StatelessWidget {
  const _AlertRail({required this.alerts});

  final List<OwnerAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final statuses = context.statusColors;

    return RecordGroup(
      heading: 'Needs attention',
      children: [
        for (final alert in alerts)
          RecordRow(
            icon: switch (alert.type) {
              OwnerAlertType.arrears => Icons.error_outline_rounded,
              OwnerAlertType.leaseExpiring => Icons.event_busy_outlined,
              OwnerAlertType.vacancy => Icons.meeting_room_outlined,
              OwnerAlertType.awaitingSignature => Icons.draw_outlined,
              OwnerAlertType.unknown => Icons.info_outline_rounded,
            },
            iconColor: statuses.resolve(alert.type.tone),
            title: alert.title,
            subtitle: alert.detail,
            onTap:
                alert.type == OwnerAlertType.vacancy && alert.targetId != null
                ? () => context.pushNamed(
                    Routes.ownerProperty,
                    pathParameters: {'propertyId': alert.targetId!},
                  )
                : null,
          ),
      ],
    );
  }
}

class _PropertyList extends StatelessWidget {
  const _PropertyList({required this.properties});

  final List<PropertyPerformance> properties;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xs, 0, Gap.xs, Gap.sm),
          child: Text(
            'YOUR PROPERTIES',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ),
        for (final (index, performance) in properties.indexed) ...[
          if (index > 0) Gap.h16,
          OwnerPropertyCard(
            performance: performance,
            onTap: () => context.pushNamed(
              Routes.ownerProperty,
              pathParameters: {'propertyId': performance.propertyId},
            ),
          ),
        ],
      ],
    );
  }
}
