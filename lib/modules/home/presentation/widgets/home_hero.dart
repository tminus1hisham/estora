import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/app_media.dart';
import '../../../../components/app_reveal.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/dashboard_summary.dart';
import '../../../../navigation/routes.dart';
import 'home_atoms.dart';
import 'home_top_bar.dart';

/// The full-bleed header the home screen opens on.
///
/// The tenant's own building, edge to edge and running under the status bar,
/// with their name on it. This is the first thing anyone sees of the app, and
/// a photograph of the place they actually rent does more for that first
/// second than any amount of typography on a blank page.
///
/// Everything here is one-shot or scroll-driven. The image settles from a
/// slight overscale as it arrives, then answers the scroll with a parallax
/// drift; neither leaves an animation running once the screen is at rest.
class HomeHero extends StatelessWidget {
  const HomeHero({
    required this.summary,
    required this.scrollOffset,
    required this.collapse,
    this.firstName,
    super.key,
  });

  final DashboardSummary summary;
  final String? firstName;

  /// Raw pixels scrolled, driving the parallax.
  final ValueListenable<double> scrollOffset;

  /// 0 while the header is fully open, 1 once it has scrolled away. Fades the
  /// greeting out as it leaves rather than letting it slide off mid-word.
  final ValueListenable<double> collapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: _HeroBackdrop(
              imageUrl: summary.propertyImageUrl,
              semanticLabel: '${summary.propertyName ?? 'Current'} property',
              scrollOffset: scrollOffset,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppGradients.headerVeil),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppGradients.headerScrim),
              ),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: collapse,
            builder: (context, t, child) =>
                Opacity(opacity: (1 - t * 1.15).clamp(0.0, 1.0), child: child),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                Gap.lg,
                topInset + HomeTopBar.height + Gap.xl,
                Gap.lg,
                // The balance card rides up onto this by 28. Enough room left
                // under the tenancy strip that the card's shadow lands on the
                // photograph rather than on the strip's own border.
                AppSpace.xxxl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppReveal(
                    delay: const Duration(milliseconds: 90),
                    child: Text(
                      _greeting(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: kHomeOnDark.withValues(alpha: 0.76),
                        fontWeight: AppTypography.semibold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  Gap.h4,
                  AppReveal(
                    delay: const Duration(milliseconds: 150),
                    offset: 18,
                    child: Text(
                      firstName ?? 'Welcome',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: kHomeOnDark,
                        fontWeight: AppTypography.extraBold,
                        shadows: const [
                          Shadow(color: AppPalette.navy950, blurRadius: 18),
                        ],
                      ),
                    ),
                  ),
                  Gap.h24,
                  AppReveal(
                    delay: const Duration(milliseconds: 230),
                    child: summary.hasTenancy
                        ? _TenancyStrip(summary: summary)
                        : const _BrowseStrip(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

/// The photograph behind the header, or the brand surface when there is none.
class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({
    required this.imageUrl,
    required this.semanticLabel,
    required this.scrollOffset,
  });

  final String? imageUrl;
  final String semanticLabel;
  final ValueListenable<double> scrollOffset;

  /// How much the image is oversized. Everything above the parallax range, so
  /// drifting the image up never exposes the surface underneath it.
  static const double _overscan = 1.22;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(gradient: AppGradients.brandHero),
        child: SizedBox.expand(),
      );
    }

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget image = AppMedia(
      source: imageUrl,
      height: double.infinity,
      semanticLabel: semanticLabel,
      fallbackIcon: Icons.storefront_rounded,
      // The tenant's name is white on this. It has to be dark from the first
      // frame, not from the frame the photograph decodes on.
      backgroundColor: AppPalette.navy900,
    );

    // The opening shot: the building settles out of a slight push-in as the
    // screen arrives, then holds. One-shot, so the tree still goes idle.
    if (!reduceMotion) {
      image = image
          .animate()
          .fadeIn(duration: AppMotion.slow, curve: AppMotion.enter)
          .scaleXY(
            begin: 1.06,
            end: 1,
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOutCubic,
          );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrift = constraints.maxHeight * (_overscan - 1) * 0.8;

        return ValueListenableBuilder<double>(
          valueListenable: scrollOffset,
          builder: (context, offset, child) {
            // The header leaves at roughly a third of the page's speed, which
            // is what puts the building visibly behind the cards rather than
            // on the same plane as them.
            final drift = (offset * 0.34).clamp(0.0, maxDrift);
            return Transform.translate(offset: Offset(0, -drift), child: child);
          },
          child: Transform.scale(
            scale: _overscan,
            alignment: Alignment.topCenter,
            child: image,
          ),
        );
      },
    );
  }
}

/// Property, unit and lease status, on smoked glass over the photograph.
///
/// The tenancy is identity, not data — it belongs on the header with the
/// tenant's name rather than in a card competing with the money below.
class _TenancyStrip extends StatelessWidget {
  const _TenancyStrip({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = summary.leaseStatus;
    final stacked = homePrefersStacked(context);

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          summary.propertyName ?? 'Your property',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(
            color: kHomeOnDark,
            fontWeight: AppTypography.bold,
          ),
        ),
        Text(
          'Unit ${summary.unitNumber ?? '—'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(
            color: kHomeOnDark.withValues(alpha: 0.74),
          ),
        ),
      ],
    );

    final chip = status == null
        ? null
        : HomeGlassChip(label: status.label, tone: status.tone);

    return _GlassPanel(
      onTap: () => context.pushNamed(
        Routes.currentProperty,
        pathParameters: {'leaseId': summary.leaseId!},
      ),
      child: Row(
        children: [
          const ToneIconTile(
            icon: Icons.storefront_rounded,
            color: kHomeOnDark,
            onDark: true,
          ),
          Gap.w12,
          Expanded(
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      identity,
                      if (chip != null) ...[
                        Gap.h8,
                        Align(alignment: Alignment.centerLeft, child: chip),
                      ],
                    ],
                  )
                : identity,
          ),
          if (chip != null && !stacked) ...[Gap.w8, chip],
          Gap.w4,
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: kHomeOnDark.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}

/// The header's strip before there is a tenancy to name.
class _BrowseStrip extends StatelessWidget {
  const _BrowseStrip();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return _GlassPanel(
      onTap: () => context.goNamed(Routes.browse),
      child: Row(
        children: [
          const ToneIconTile(
            icon: Icons.search_rounded,
            color: kHomeOnDark,
            onDark: true,
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Find your space',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: kHomeOnDark,
                    fontWeight: AppTypography.bold,
                  ),
                ),
                Text(
                  'Browse retail units, kiosks and suites',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: kHomeOnDark.withValues(alpha: 0.74),
                  ),
                ),
              ],
            ),
          ),
          Gap.w4,
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: kHomeOnDark.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}

/// A tappable plate of smoked glass, for content that sits on the header.
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.navy950.withValues(alpha: 0.46),
        borderRadius: AppRadius.medium,
        border: Border.all(color: kHomeOnDark.withValues(alpha: 0.16)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.medium,
          splashColor: kHomeOnDark.withValues(alpha: 0.08),
          highlightColor: kHomeOnDark.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.md,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
