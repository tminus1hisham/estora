import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../components/ambient_glow.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';

/// The foreground colour every control on the stage is drawn in.
///
/// The stage is dark in both themes — the way the balance card is, and the way
/// a bank's own sign-in screen is — so its text cannot come from the colour
/// scheme. `onSurface` is navy while the app is in light mode and would
/// disappear here.
const Color kAuthOnDark = AppPalette.stone0;

/// The photograph the stage opens on.
///
/// A commercial frontage at dusk rather than an abstract pattern: the first
/// screen of a tenant app should look like the thing being rented. The veil
/// over it is heavy enough that any property photograph of roughly this
/// exposure can be dropped in without retuning the text colours.
const String kAuthStageImage = 'assets/images/property_sarit_mall.jpg';

/// The theme the sign-in controls resolve against.
///
/// Built once at the library level rather than per build: it depends on
/// nothing in the [BuildContext], and rebuilding a whole [ThemeData] on every
/// keystroke in a text field is real work for no change in output.
///
/// It starts from the app's dark theme — which already has a scheme tuned for
/// navy — and re-cuts only the surfaces that sit on glass. Everything else,
/// including the error colours and the control geometry, stays shared with the
/// rest of the app.
final ThemeData authStageTheme = _buildAuthStageTheme();

ThemeData _buildAuthStageTheme() {
  final base = AppTheme.dark;
  final scheme = base.colorScheme;
  final textTheme = base.textTheme;

  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: AppRadius.small,
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    // The stage paints the background; a scaffold colour here would cover it.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      // A tint of the foreground rather than a solid fill, so the fields read
      // as cut into the glass instead of laid on top of it.
      fillColor: kAuthOnDark.withValues(alpha: 0.055),
      border: border(kAuthOnDark.withValues(alpha: 0.16)),
      enabledBorder: border(kAuthOnDark.withValues(alpha: 0.16)),
      focusedBorder: border(scheme.primary, 1.6),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 1.6),
      disabledBorder: border(kAuthOnDark.withValues(alpha: 0.08)),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: kAuthOnDark.withValues(alpha: 0.7),
      ),
      floatingLabelStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.primary,
        fontWeight: AppTypography.semibold,
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: kAuthOnDark.withValues(alpha: 0.45),
      ),
      helperStyle: textTheme.bodySmall?.copyWith(
        color: kAuthOnDark.withValues(alpha: 0.62),
      ),
      prefixIconColor: kAuthOnDark.withValues(alpha: 0.62),
      suffixIconColor: kAuthOnDark.withValues(alpha: 0.62),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: 0.32),
      selectionHandleColor: scheme.primary,
    ),
    dividerTheme: DividerThemeData(
      color: kAuthOnDark.withValues(alpha: 0.14),
      space: 1,
      thickness: 1,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        minimumSize: const Size(AppLayout.minTouchTarget, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
        textStyle: textTheme.labelLarge,
      ),
    ),
  );
}

/// The photographic ground the sign-in journey is played on.
///
/// Meant to be dropped into a [Stack] behind the content with
/// [Positioned.fill]. It owns four layers, in order: a navy ground so the
/// first painted frame is never a white flash, the photograph, the veil that
/// makes text on it legible, and two ambient lights that give the flat veil
/// somewhere to fall off to.
///
/// Every animation here is one-shot. The image settles out of a slow push-in
/// and the lights bloom once; nothing is left running, so the widget tree
/// still goes idle and `pumpAndSettle` still returns.
///
/// Named for what it draws rather than for the stage itself, because
/// [AuthStage] is already the sign-in lifecycle enum in the controller.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({
    this.image = kAuthStageImage,
    this.shadeTrailingEdge = false,
    super.key,
  });

  final String image;

  /// Set by the split layout, whose controls sit over the middle of the
  /// photograph rather than over its dark head and foot.
  final bool shadeTrailingEdge;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget photograph = Image.asset(
      image,
      fit: BoxFit.cover,
      // Off-centre on purpose. A portrait window crops a landscape photograph
      // to a narrow vertical strip, and the centre of this one is the shaded
      // depth of the walkway; the lit frontages that make it look like
      // somewhere worth renting are to the left of it.
      alignment: const Alignment(-0.35, 0),
      excludeFromSemantics: true,
      // The veil and the lights carry the screen on their own, so a missing
      // or unreadable asset costs atmosphere rather than legibility.
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );

    if (!reduceMotion) {
      photograph = photograph
          .animate()
          .fadeIn(duration: AppMotion.slow, curve: AppMotion.enter)
          // Long and shallow. The eye should register that the building is
          // settling, not that something is zooming.
          .scaleXY(
            begin: 1.09,
            end: 1,
            duration: const Duration(milliseconds: 2200),
            curve: Curves.easeOutCubic,
          );
    }

    Widget glow(Color color, double size, Duration delay) {
      final light = AmbientGlow(color: color, size: size);
      if (reduceMotion) return light;
      return light
          .animate(delay: delay)
          .fadeIn(duration: AppMotion.slow)
          .scaleXY(begin: 0.82, end: 1, duration: const Duration(seconds: 1));
    }

    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppPalette.navy950),
            photograph,
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppGradients.stageVeil),
              ),
            ),
            if (shadeTrailingEdge)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppGradients.stageEdgeVeil,
                  ),
                ),
              ),
            // Azure high and to the right, brass low and to the left: the
            // same two-light arrangement the balance card uses, so the two
            // dark surfaces in the app read as the same material.
            Positioned(
              top: -150,
              right: -120,
              child: glow(
                AppPalette.azure500.withValues(alpha: 0.34),
                400,
                const Duration(milliseconds: 240),
              ),
            ),
            Positioned(
              bottom: -190,
              left: -150,
              child: glow(
                AppPalette.brass500.withValues(alpha: 0.2),
                440,
                const Duration(milliseconds: 420),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The plate of frosted glass the sign-in controls sit on.
///
/// A real [BackdropFilter] rather than a flat tint. It is one composited layer
/// on a screen that has nothing else to spend its frame budget on, and it is
/// what makes the warm light behind the panel read as diffusing through glass
/// rather than as a ghost of a photograph under a translucent box.
///
/// The console also owns the failure treatment, because a failure is something
/// that happens *to this panel*: the alert appears inside it and the panel
/// itself flinches once.
class AuthConsole extends StatelessWidget {
  const AuthConsole({
    required this.child,
    this.failure,
    this.onDismissFailure,
    super.key,
  });

  final Widget child;
  final Failure? failure;
  final VoidCallback? onDismissFailure;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget panel = Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.extraLarge,
        boxShadow: AppElevation.lifted(
          AppPalette.navy950,
          level: 3,
          brightness: Brightness.dark,
        ),
      ),
      // The hairline goes in front of the clipped glass, otherwise the clip
      // eats the outer half of it and the edge looks soft.
      foregroundDecoration: BoxDecoration(
        borderRadius: AppRadius.extraLarge,
        border: Border.all(color: kAuthOnDark.withValues(alpha: 0.15)),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.extraLarge,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppPalette.navy950.withValues(alpha: 0.52),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 140,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppGradients.sheen(Brightness.dark),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (failure != null) ...[
                        AuthAlert(
                          failure: failure!,
                          onDismiss: onDismissFailure,
                        ),
                        Gap.h16,
                      ],
                      child,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!reduceMotion) {
      // One light crosses the console shortly after it lands, and nothing else
      // on the screen shines. Same reasoning as the balance card: a second
      // highlight anywhere would make both look cheap.
      panel = panel.animate().shimmer(
        delay: const Duration(milliseconds: 760),
        duration: const Duration(milliseconds: 1200),
        color: kAuthOnDark.withValues(alpha: 0.16),
      );
    }

    // A rejected credential should feel like the panel refusing, not like a
    // paragraph appearing. The shake is keyed on the failure's identity so a
    // second attempt that fails the same way still flinches.
    return _Flinch(trigger: failure?.message, child: panel);
  }
}

/// The failure banner as it appears on glass.
///
/// The app's error container colours are built for a card on cream and turn to
/// mud over a photograph, so this is a red-tinted plate of the same glass the
/// console is made of.
class AuthAlert extends StatelessWidget {
  const AuthAlert({required this.failure, this.onDismiss, super.key});

  final Failure failure;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Error: ${failure.message}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.md,
          AppSpace.sm,
          AppSpace.md,
        ),
        decoration: BoxDecoration(
          color: AppPalette.red700.withValues(alpha: 0.24),
          borderRadius: AppRadius.small,
          border: Border.all(color: AppPalette.red300.withValues(alpha: 0.42)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 20,
              color: AppPalette.red300,
            ),
            Gap.w12,
            Expanded(
              child: Text(
                failure.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: kAuthOnDark,
                  fontWeight: AppTypography.medium,
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: 'Dismiss error',
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                color: kAuthOnDark.withValues(alpha: 0.8),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shakes its child once whenever [trigger] changes to a new non-null value.
///
/// Driven by a controller that is only ever run forward, so it comes to rest
/// on its own and leaves the tree idle.
class _Flinch extends StatefulWidget {
  const _Flinch({required this.trigger, required this.child});

  final Object? trigger;
  final Widget child;

  @override
  State<_Flinch> createState() => _FlinchState();
}

class _FlinchState extends State<_Flinch> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 440),
  );

  @override
  void didUpdateWidget(covariant _Flinch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger == null || widget.trigger == oldWidget.trigger) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        if (t == 0 || t == 1) return child!;
        // Three passes, each smaller than the last. The decay is what makes it
        // read as a physical object settling rather than as a wobble effect.
        final travel = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(travel, 0), child: child);
      },
    );
  }
}
