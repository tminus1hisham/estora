import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';

/// Page transitions for pushed routes.
///
/// go_router's default `builder` gives a platform page, which on this app's
/// desktop and web demo targets means no transition at all: screens simply
/// replace one another. A push that does not move reads as a redraw rather
/// than as navigation, and it is the most-felt absence when the app is driven
/// in front of an audience.
///
/// Tab switching is deliberately left instant. A bottom tab bar that animates
/// between destinations feels slow, and the shell's IndexedStack is keeping all
/// five branches alive anyway.

/// A lateral push: the incoming screen slides in from the trailing edge while
/// the outgoing one steps back.
///
/// Used for going deeper into a section — a list to its detail, a detail to a
/// focused transaction.
CustomTransitionPage<T> lateralPage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.standard,
    reverseTransitionDuration: AppMotion.fast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;

      final incoming = CurvedAnimation(
        parent: animation,
        curve: AppMotion.enter,
        reverseCurve: AppMotion.exit,
      );

      // Both tweens run from the resting state outwards, because these
      // animations sit at 0 for the whole time a screen is simply on display:
      // `animation` is 1 once a page has finished arriving, and
      // `secondaryAnimation` is 0 until something is pushed on top of it.
      // Beginning the outgoing tween anywhere but at rest would leave every
      // screen in the app permanently displaced.
      final outgoing = CurvedAnimation(
        parent: secondaryAnimation,
        curve: AppMotion.enter,
        reverseCurve: AppMotion.exit,
      );

      return SlideTransition(
        position: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0, -0.02),
        ).animate(outgoing),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0.6).animate(outgoing),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(incoming),
            child: FadeTransition(opacity: incoming, child: child),
          ),
        ),
      );
    },
  );
}

/// A plain cross-fade, for screens that are a change of context rather than a
/// step deeper — the auth journey, and anything reached sideways.
CustomTransitionPage<T> fadePage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.standard,
    reverseTransitionDuration: AppMotion.fast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;

      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: AppMotion.enter,
          reverseCurve: AppMotion.exit,
        ),
        child: child,
      );
    },
  );
}
