import 'dart:ui' as ui;

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
/// material as the header leaves: nothing at all over the photograph, and
/// once the header is on its way out, the frosted chrome iOS puts under a
/// navigation bar — the page blurred and lifted in saturation behind a thin
/// veil, closed off by a hairline.
///
/// The chrome arrives as a short fade once the header has travelled past a
/// point, rather than tracking the scroll pixel for pixel. Tracked, every
/// resting position in between was a half-veiled bar with half-changed ink on
/// it — light-on-grey turning into dark-on-grey — and somewhere in the middle
/// the title matched the bar and vanished. iOS makes the same choice for a bar
/// over a photograph: either it is not there, or it is.
///
/// The blur is real because something genuinely passes behind it: the
/// photograph, then the cards and the lit ground of the page. It is a plain
/// [BackdropFilter], not a grouped one, because the bar sits outside the
/// page's [BackdropGroup] and has to read the page as it is on this frame.
class HomeTopBar extends StatefulWidget {
  const HomeTopBar({required this.collapse, required this.unread, super.key});

  /// 0 while the header is fully open, 1 once it has scrolled away.
  final ValueListenable<double> collapse;

  final int unread;

  /// The bar's own height, below the status bar.
  static const double height = 56;

  @override
  State<HomeTopBar> createState() => _HomeTopBarState();
}

class _HomeTopBarState extends State<HomeTopBar> {
  /// The chrome blur at full strength, matching a chrome-depth pane.
  static const double _blur = 30;

  /// Where the chrome comes in on the way up, and goes on the way back down.
  /// Two points rather than one, so a finger resting near the line does not
  /// make the bar flicker.
  static const double _on = 0.55;
  static const double _off = 0.4;

  late bool _chrome = widget.collapse.value >= _on;

  @override
  void initState() {
    super.initState();
    widget.collapse.addListener(_onCollapse);
  }

  @override
  void didUpdateWidget(HomeTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collapse != widget.collapse) {
      oldWidget.collapse.removeListener(_onCollapse);
      widget.collapse.addListener(_onCollapse);
      _onCollapse();
    }
  }

  @override
  void dispose() {
    widget.collapse.removeListener(_onCollapse);
    super.dispose();
  }

  void _onCollapse() {
    final t = widget.collapse.value;
    final chrome = _chrome ? t > _off : t >= _on;
    if (chrome != _chrome) setState(() => _chrome = chrome);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top;
    final still = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _chrome ? 1 : 0),
      duration: still ? Duration.zero : AppMotion.standard,
      curve: Curves.easeOut,
      builder: (context, c, _) {
        // Over the photograph the ink has to be light whatever the theme is;
        // once the chrome has arrived it belongs to the page again.
        final foreground = Color.lerp(kHomeOnDark, scheme.onSurface, c)!;
        final fill = dark
            ? AppPalette.navy900.withValues(alpha: 0.62 * c)
            : AppPalette.stone0.withValues(alpha: 0.72 * c);
        final hairline = dark
            ? Colors.white.withValues(alpha: 0.10 * c)
            : AppPalette.navy900.withValues(alpha: 0.12 * c);

        Widget bar = DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            border: Border(
              // Half a point: one device pixel on a phone, which is the
              // weight iOS draws the edge of its chrome at.
              bottom: BorderSide(color: hairline, width: 0.5),
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
                // Expanded, not a Spacer: at large text sizes on a small phone
                // the wordmark would otherwise push the bell off the edge.
                Expanded(
                  child: Text(
                    'Estora',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: foreground,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                _NotificationBell(
                  unread: widget.unread,
                  blend: c,
                  foreground: foreground,
                ),
              ],
            ),
          ),
        );

        // No filter at all while the header is open: even a zero blur costs
        // a backdrop read on every frame of the parallax.
        if (c > 0) {
          bar = ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.compose(
                outer: ui.ImageFilter.blur(
                  sigmaX: _blur * c,
                  sigmaY: _blur * c,
                  tileMode: TileMode.mirror,
                ),
                // Saturation rises with the blur, as it does on the panes
                // below, so the page's lights come through the bar as colour
                // rather than as grey.
                inner: ColorFilter.matrix(_saturation(1 + 0.7 * c)),
              ),
              child: bar,
            ),
          );
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: c < 0.5
              ? SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                )
              : (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark),
          child: SizedBox(height: topInset + HomeTopBar.height, child: bar),
        );
      },
    );
  }

  /// A saturation matrix for [s] (1 is unchanged), on Rec. 709 luma weights.
  static List<double> _saturation(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final i = 1 - s;
    return [
      r * i + s, g * i, b * i, 0, 0, //
      r * i, g * i + s, b * i, 0, 0, //
      r * i, g * i, b * i + s, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }
}

/// The notifications action, drawn as a disc so it reads as a control rather
/// than as a loose glyph floating over a photograph.
///
/// Over the photograph it is a disc of smoked glass; as the chrome arrives the
/// disc thins to a faint well in it, because on a frosted bar a second plate
/// under the glyph is one surface too many.
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
    final dark = Theme.of(context).brightness == Brightness.dark;

    final background = Color.lerp(
      AppPalette.navy950.withValues(alpha: 0.34),
      dark
          ? Colors.white.withValues(alpha: 0.08)
          : AppPalette.navy900.withValues(alpha: 0.05),
      blend,
    )!;
    final border = Color.lerp(
      kHomeOnDark.withValues(alpha: 0.32),
      dark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.7),
      blend,
    )!;

    return IconButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        context.pushNamed(Routes.notifications);
      },
      tooltip: 'Notifications',
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        shape: const CircleBorder(),
        side: BorderSide(color: border),
        // No ripple on the chrome. A grey disc spreading over the photograph
        // or the frosted bar reads as a smudge; the route opening answers the
        // tap.
        splashFactory: NoSplash.splashFactory,
        overlayColor: foreground.withValues(alpha: 0.06),
      ),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}
