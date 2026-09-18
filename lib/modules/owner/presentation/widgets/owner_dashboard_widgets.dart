import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../components/app_media.dart';
import '../../../../components/app_reveal.dart';
import '../../../../components/app_surface_card.dart';
import '../../../../components/occupancy_meter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/property.dart';
import '../../../../navigation/routes.dart';

/// Content-sized rows keep large text readable without fixed card heights.
class OwnerWidgetGrid extends StatelessWidget {
  const OwnerWidgetGrid({
    required this.children,
    this.minWidth = 260,
    super.key,
  });
  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = ((constraints.maxWidth + 12) / (minWidth * scale + 12))
          .floor()
          .clamp(1, 4);
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (index, child) in children.indexed)
            SizedBox(
              width: width,
              child: AppReveal(index: index, child: child),
            ),
        ],
      );
    },
  );
}

/// Full-width photo header; only the content below it receives page gutters.
class OwnerDashboardScrollView extends StatelessWidget {
  const OwnerDashboardScrollView({
    required this.child,
    this.name,
    this.onRefresh,
    super.key,
  });
  final Widget child;
  final String? name;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OwnerDashboardHeading(name: name, onRefresh: onRefresh),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: child,
            ),
          ),
        ),
      ],
    ),
  );
}

class OwnerDashboardHeading extends StatelessWidget {
  const OwnerDashboardHeading({this.name, this.onRefresh, super.key});
  final String? name;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.elliptical(44, 36),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: AppMedia(
                  source: 'assets/images/property_sarit_mall.jpg',
                  aspectRatio: null,
                  backgroundColor: AppPalette.navy950,
                  overlay: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          AppPalette.navy950.withValues(alpha: .28),
                          AppPalette.navy950.withValues(alpha: .85),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1352),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Home',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refresh dashboard',
                              onPressed: onRefresh,
                              color: Colors.white,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat(
                            'EEEE, d MMMM',
                          ).format(DateTime.now()).toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.5,
                            color: AppPalette.brass200,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          name == null
                              ? 'Your portfolio, at a glance.'
                              : 'Welcome back, $name.',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your spaces. Your performance. One clear view.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OwnerMetric extends StatelessWidget {
  const OwnerMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.featured = false,
    this.onTap,
    super.key,
  });
  final String label;
  final String value;
  final String? detail;
  final IconData icon;
  final bool featured;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = featured ? Colors.white : theme.colorScheme.onSurface;
    final muted = featured
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;
    return AppSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      gradient: featured ? AppGradients.brandHero : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: featured
                    ? AppPalette.brass300
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(color: muted),
                ),
              ),
              if (onTap != null)
                Icon(Icons.north_east_rounded, size: 14, color: muted),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 5),
            Text(
              detail!,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared by the dashboard and property directory. Only known facts are shown.
class OwnerPropertyTile extends StatefulWidget {
  const OwnerPropertyTile({
    required this.property,
    this.availableUnits,
    super.key,
  });
  final Property property;
  final int? availableUnits;

  @override
  State<OwnerPropertyTile> createState() => _OwnerPropertyTileState();
}

class _OwnerPropertyTileState extends State<OwnerPropertyTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final property = widget.property;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
        child: AppSurfaceCard(
          padding: EdgeInsets.zero,
          borderColor: _hovered ? scheme.primary : null,
          onTap: () => context.pushNamed(
            Routes.ownerProperty,
            pathParameters: {'propertyId': property.id},
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppMedia(
                source: property.imageUrl,
                height: 104,
                semanticLabel: property.name,
                overlay: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.navy950.withValues(alpha: .85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      property.propertyType.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            property.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_outward_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property.locationLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        if (property.totalUnits != null)
                          Text(
                            '${property.totalUnits} units',
                            style: theme.textTheme.labelMedium,
                          ),
                        if ((widget.availableUnits ??
                                property.availableUnits) !=
                            null)
                          Text(
                            '${widget.availableUnits ?? property.availableUnits} available',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                        if (property.rateLabel != null)
                          Text(
                            property.rateLabel!,
                            style: theme.textTheme.labelMedium,
                          ),
                      ],
                    ),
                    if (property.mix != null) ...[
                      const SizedBox(height: 12),
                      OccupancyMeter(mix: property.mix!, dense: true),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
