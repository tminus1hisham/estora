import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/app_brand_mark.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../navigation/routes.dart';
import 'home_atoms.dart';

/// The bar that floats over the home screen's full-bleed header.
///
/// It is not a [SliverAppBar]. The header photograph runs to the very top of
/// the screen and the balance card overlaps its foot, and a pinned sliver
/// paints above everything that scrolls under it — which would bury the card.
/// So the bar sits in a [Stack] over the scroll view instead, and earns its
/// background as the header leaves: transparent over the photograph, the
/// page's own surface once there is text underneath it.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({required this.collapse, required this.unread, super.key});

  /// 0 while the header is fully open, 1 once it has scrolled away.
  final ValueListenable<double> collapse;

  final int unread;

  /// The bar's own height, below the status bar.
  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;

    return ValueListenableBuilder<double>(
      valueListenable: collapse,
      builder: (context, t, _) {
        // Over the photograph the icons have to be light whatever the theme is;
        // once the surface has arrived they belong to it again.
        final foreground = Color.lerp(kHomeOnDark, scheme.onSurface, t)!;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: t < 0.5
              ? SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                )
              : (theme.brightness == Brightness.dark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark),
          child: SizedBox(
            height: topInset + height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: t),
                border: Border(
                  bottom: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.7 * t),
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  top: topInset,
                  left: Gap.lg,
                  right: Gap.sm,
                ),
                child: Row(
                  children: [
                    const AppBrandMark(size: 36),
                    Gap.w12,
                    Text(
                      'Mall',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: foreground,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    _NotificationBell(
                      unread: unread,
                      blend: t,
                      foreground: foreground,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The notifications action, drawn as a disc so it reads as a control rather
/// than as a loose glyph floating over a photograph.
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({
    required this.unread,
    required this.blend,
    required this.foreground,
  });

  final int unread;
  final double blend;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Smoked glass over the photograph, a tonal disc once the surface arrives.
    final background = Color.lerp(
      AppPalette.navy950.withValues(alpha: 0.34),
      scheme.surfaceContainer,
      blend,
    )!;
    final border = Color.lerp(
      kHomeOnDark.withValues(alpha: 0.32),
      scheme.outlineVariant.withValues(alpha: 0.6),
      blend,
    )!;

    return IconButton(
      onPressed: () => context.pushNamed(Routes.notifications),
      tooltip: 'Notifications',
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        shape: const CircleBorder(),
        side: BorderSide(color: border),
      ),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}
