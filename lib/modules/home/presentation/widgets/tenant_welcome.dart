import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/app_media.dart';
import '../../../../components/app_reveal.dart';
import '../../../../components/even_grid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../navigation/routes.dart';

/// An editorial welcome with a finite camera entrance and accessible shortcuts.
class TenantWelcome extends StatelessWidget {
  const TenantWelcome({this.name, super.key});
  final String? name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget photograph = const AppMedia(
      source: 'assets/images/property_sarit_mall.jpg',
      aspectRatio: null,
      backgroundColor: AppPalette.navy900,
    );
    if (!MediaQuery.disableAnimationsOf(context)) {
      photograph = photograph.animate().scaleXY(
        begin: 1.08,
        end: 1,
        duration: const Duration(milliseconds: 1600),
        curve: Curves.easeOutCubic,
      );
    }
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(child: ExcludeSemantics(child: photograph)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    AppPalette.navy950.withValues(alpha: .38),
                    AppPalette.navy950.withValues(alpha: .85),
                    AppPalette.navy950,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.apartment_rounded,
                            color: AppPalette.brass200,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'MALL',
                            style: text.titleMedium?.copyWith(
                              color: Colors.white,
                              letterSpacing: 5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          IconButton.filledTonal(
                            tooltip: 'Your account',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: .14,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => context.goNamed(Routes.profile),
                            icon: const Icon(Icons.person_outline_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      AppReveal(
                        child: Text(
                          name == null || name!.isEmpty
                              ? 'Welcome'
                              : 'Welcome, $name',
                          style: text.titleSmall?.copyWith(
                            color: AppPalette.brass200,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppReveal(
                        index: 1,
                        child: Text(
                          'A little space.\nA lot of possibility.',
                          style: text.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 32,
                            height: 1.12,
                            letterSpacing: -1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppReveal(
                        index: 2,
                        child: Text(
                          'Your place, your plans. All in one place.',
                          style: text.bodySmall?.copyWith(
                            color: AppPalette.stone200,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppReveal(
                        index: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .22),
                            ),
                            borderRadius: BorderRadius.circular(30),
                            color: Colors.white.withValues(alpha: .08),
                          ),
                          child: Text(
                            'YOUR TENANT PORTAL',
                            style: text.labelSmall?.copyWith(
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
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
    );
  }
}

class TenantActionPanel extends StatelessWidget {
  const TenantActionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.navy950.withValues(alpha: .10),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR EVERYDAY, SIMPLIFIED',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text('Make yourself at home.', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          // Side by side where there is room, stacked where there is not, and
          // the same size as each other either way.
          EvenGrid(
            minTileWidth: 140,
            maxColumns: 2,
            children: [
              _DestinationCard(
                title: 'View invoices',
                subtitle: 'Keep everything up to date',
                icon: Icons.receipt_long_rounded,
                featured: true,
                onTap: () => context.goNamed(Routes.invoices),
              ),
              _DestinationCard(
                title: 'Browse properties',
                subtitle: 'Find your next possibility',
                icon: Icons.explore_outlined,
                onTap: () => context.goNamed(Routes.browse),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DestinationCard extends StatefulWidget {
  const _DestinationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.featured = false,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool featured;

  @override
  State<_DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<_DestinationCard> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = widget.featured
        ? Colors.white
        : theme.colorScheme.onSurface;
    return AnimatedScale(
      scale: _active ? .98 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Material(
        color: widget.featured
            ? AppPalette.navy900
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (value) => setState(() => _active = value),
          onHighlightChanged: (value) => setState(() => _active = value),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: 20,
                      color: widget.featured
                          ? AppPalette.brass200
                          : theme.colorScheme.primary,
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 18,
                      color: foreground,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 13,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: widget.featured
                        ? AppPalette.stone200
                        : theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
