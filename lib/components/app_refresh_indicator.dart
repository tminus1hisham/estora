import 'dart:async';

import 'package:flutter/material.dart';

/// Consistent refresh behavior, including pages shorter than the viewport.
class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    required this.onRefresh,
    required this.child,
    this.edgeOffset = 0,
    super.key,
  });

  final FutureOr<void> Function() onRefresh;
  final Widget child;
  final double edgeOffset;

  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RefreshScope>() != null;

  static Future<void> refresh(
    BuildContext context,
    FutureOr<void> Function() callback,
  ) async {
    try {
      await callback();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Could not refresh. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _RefreshScope(
      child: ScrollConfiguration(
        behavior: const _RefreshScrollBehavior(),
        child: RefreshIndicator(
          edgeOffset: edgeOffset,
          onRefresh: () => refresh(context, onRefresh),
          child: child,
        ),
      ),
    );
  }
}

class _RefreshScope extends InheritedWidget {
  const _RefreshScope({required super.child});

  @override
  bool updateShouldNotify(_RefreshScope oldWidget) => false;
}

class _RefreshScrollBehavior extends MaterialScrollBehavior {
  const _RefreshScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      AlwaysScrollableScrollPhysics(parent: super.getScrollPhysics(context));
}

/// Keeps an empty or error message centered and gives it a pullable viewport.
class RefreshPlaceholder extends StatelessWidget {
  const RefreshPlaceholder({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    slivers: [SliverFillRemaining(hasScrollBody: false, child: child)],
  );
}
