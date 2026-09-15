import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../components/app_brand_mark.dart';
import '../../../../components/app_reveal.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';
import 'auth_stage.dart';

/// A single supporting claim, shown beside the form where there is room.
class AuthTrustPoint {
  const AuthTrustPoint({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// One page of the sign-in journey.
///
/// Every auth screen is the same two things arranged two ways: a heading that
/// says where you are, and a plate of frosted glass holding whatever you have
/// to do about it. Sharing the chrome here rather than per screen is what
/// keeps the journey from changing character when a tenant taps through from
/// the greeting to a verification code.
///
/// On a window with room the two stand side by side; otherwise they stack. See
/// [prefersSplitLayout] for why a short landscape window counts as having
/// room.
class AuthPage extends StatelessWidget {
  const AuthPage({
    required this.title,
    required this.console,
    this.eyebrow = 'Mall',
    this.subtitle,
    this.footer,
    this.trustPoints = const <AuthTrustPoint>[],
    this.failure,
    this.onDismissFailure,
    this.showBackButton = true,
    this.showBrandMark = true,
    super.key,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;

  /// The contents of the glass console.
  final Widget console;

  /// Anything that belongs outside the console, under it.
  final Widget? footer;

  /// Shown only where the split layout leaves the heading column with space
  /// it would otherwise spend on nothing.
  final List<AuthTrustPoint> trustPoints;

  final Failure? failure;
  final VoidCallback? onDismissFailure;
  final bool showBackButton;

  /// Whether the heading carries the brand mark above it.
  ///
  /// The greeting and the registration screen say the name in words already;
  /// the mark over the top of them is the same claim twice.
  final bool showBrandMark;

  /// The narrowest window that can carry the heading and the console abreast.
  static const double _splitMinWidth = 720;

  /// The height at or above which a single column still has room for the
  /// heading, the console and the footer.
  static const double _stackableHeight = 720;

  /// Above this, the split has width to spare and can be given air.
  static const double _roomyWidth = 1000;

  /// The order things arrive in: the heading, then the console it belongs to,
  /// then whatever sits outside.
  static const Duration _headingDelay = Duration(milliseconds: 120);
  static const Duration _consoleDelay = Duration(milliseconds: 300);
  static const Duration _footerDelay = Duration(milliseconds: 460);

  /// Whether the heading and the console stand side by side.
  ///
  /// Two windows want this. A genuinely wide one, where a 480pt form marooned
  /// in the middle of a desktop looks like a mistake; and a short landscape
  /// one, where the heading stacked above the console would push the primary
  /// button below the fold — which is the one thing these screens must never
  /// do.
  static bool prefersSplitLayout(Size window) {
    if (window.width >= AppLayout.mediumBreakpoint + 80) return true;
    return window.width >= _splitMinWidth && window.height < _stackableHeight;
  }

  @override
  Widget build(BuildContext context) {
    // Measured against the window rather than the layout constraints, so that
    // a keyboard opening — which only shrinks the constraints — can never
    // rearrange the screen out from under the field being typed into.
    final split = prefersSplitLayout(MediaQuery.sizeOf(context));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The stage is navy whatever the platform theme is, so the status bar
      // has to be told to draw itself light rather than inheriting from it.
      value: SystemUiOverlayStyle.light,
      child: Theme(
        data: authStageTheme,
        child: Scaffold(
          backgroundColor: AppPalette.navy950,
          body: Stack(
            children: [
              Positioned.fill(child: AuthBackdrop(shadeTrailingEdge: split)),
              Positioned.fill(
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        _viewport(context, constraints, split),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The single scrolling column everything lives in.
  ///
  /// One scroll view for both layouts rather than one per column: at an
  /// accessibility text size the split layout's two halves grow at different
  /// rates, and two independently scrolling halves of one form is a worse
  /// screen than a tall one.
  Widget _viewport(
    BuildContext context,
    BoxConstraints constraints,
    bool split,
  ) {
    final horizontalPadding = AppLayout.pagePaddingFor(constraints.maxWidth);
    final showBack = showBackButton && Navigator.canPop(context);
    // The back button floats over the scroll view, so the content has to start
    // below it on a screen too short to centre anything.
    final topPadding =
        AppSpace.xl + (showBack ? AppLayout.minTouchTarget + AppSpace.md : 0.0);
    final availableHeight = constraints.maxHeight - topPadding - AppSpace.xxl;

    final Widget scroller = SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        AppSpace.xxl,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: availableHeight < 0 ? 0 : availableHeight,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: split
                  ? AppLayout.maxContentWidth
                  : AppLayout.maxFormWidth,
            ),
            child: split ? _split(context) : _stacked(context),
          ),
        ),
      ),
    );

    if (!showBack) return scroller;

    return Stack(
      children: [
        scroller,
        PositionedDirectional(
          top: 0,
          start: horizontalPadding,
          child: _BackButton(onPressed: () => Navigator.of(context).pop()),
        ),
      ],
    );
  }

  Widget _stacked(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppReveal(
          delay: _headingDelay,
          offset: 16,
          child: _heading(context, roomy: false),
        ),
        Gap.h32,
        AppReveal(
          delay: _consoleDelay,
          // Further than the app's usual arrival. The console is the heaviest
          // object on the screen and it should look like it has travelled.
          offset: 28,
          child: _console(),
        ),
        if (footer != null) ...[
          Gap.h24,
          AppReveal(delay: _footerDelay, child: footer!),
        ],
      ],
    );
  }

  Widget _split(BuildContext context) {
    final window = MediaQuery.sizeOf(context);
    // The gap is generous once there is room for it. On a landscape phone it
    // would be width the console needs more.
    final columnGap = window.width >= _roomyWidth
        ? AppSpace.display
        : AppSpace.xxl;
    final roomy = window.height >= _stackableHeight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 6,
          child: AppReveal(
            delay: _headingDelay,
            offset: 16,
            child: _heading(context, roomy: roomy),
          ),
        ),
        SizedBox(width: columnGap),
        Expanded(
          flex: 5,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppReveal(
                    delay: _consoleDelay,
                    offset: 28,
                    child: _console(),
                  ),
                  if (footer != null) ...[
                    Gap.h24,
                    AppReveal(delay: _footerDelay, child: footer!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _console() => AuthConsole(
    failure: failure,
    onDismissFailure: onDismissFailure,
    child: console,
  );

  Widget _heading(BuildContext context, {required bool roomy}) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showBrandMark) ...[
          AppBrandMark(size: roomy ? 68 : 56, withShadow: true),
          Gap.h24,
        ],
        if (eyebrow != null) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: AppTypography.bold,
              letterSpacing: 1.6,
            ),
          ),
          Gap.h12,
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            style: _titleStyle(context, roomy: roomy)?.copyWith(
              color: kAuthOnDark,
              fontWeight: AppTypography.extraBold,
              // The heading sits over the brightest part of the photograph on
              // a short screen; the shadow is what keeps it off the building.
              shadows: const [
                Shadow(color: AppPalette.navy950, blurRadius: 24),
              ],
            ),
          ),
        ),
        if (subtitle != null) ...[
          Gap.h12,
          Text(
            subtitle!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: kAuthOnDark.withValues(alpha: 0.74),
            ),
          ),
        ],
        if (roomy && trustPoints.isNotEmpty) ...[
          Gap.h32,
          for (final point in trustPoints) ...[
            if (point != trustPoints.first) Gap.h16,
            _TrustPointRow(point: point),
          ],
        ],
      ],
    );
  }

  /// The heading's size.
  ///
  /// Steps down a rank once the platform text size passes the point where a
  /// display face stops fitting the longest word of a greeting on one line of
  /// a small phone. Clamping the scale instead would be the usual fix and the
  /// wrong one — someone who asked for larger text should get larger text,
  /// just not "Welcom / e back".
  TextStyle? _titleStyle(BuildContext context, {required bool roomy}) {
    final textTheme = Theme.of(context).textTheme;
    if (MediaQuery.textScalerOf(context).scale(14) >= 20) {
      return textTheme.headlineMedium;
    }
    return roomy ? textTheme.displayMedium : textTheme.displaySmall;
  }
}

class _TrustPointRow extends StatelessWidget {
  const _TrustPointRow({required this.point});

  final AuthTrustPoint point;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(point.icon, size: 20, color: theme.colorScheme.primary),
        Gap.w12,
        Expanded(
          child: Text(
            point.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: kAuthOnDark.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}

/// The way back, as a plate of the same glass as everything else.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_rounded),
      style: IconButton.styleFrom(
        foregroundColor: kAuthOnDark,
        backgroundColor: kAuthOnDark.withValues(alpha: 0.08),
        minimumSize: const Size.square(AppLayout.minTouchTarget),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.small,
          side: BorderSide(color: kAuthOnDark.withValues(alpha: 0.18)),
        ),
      ),
    );
  }
}
