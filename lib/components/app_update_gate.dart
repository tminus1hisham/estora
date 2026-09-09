import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

import '../services/providers.dart';
import '../services/update/app_update_service.dart';

/// Asks Google Play whether a newer build exists, and acts on the answer.
///
/// It wraps the whole app rather than sitting on one screen for two reasons: a
/// release Play calls mandatory has to be able to interrupt whatever the
/// tenant is in the middle of, and a background download has to survive them
/// moving between tabs.
///
/// Nothing here is visible unless Play has something to install. On iOS, on
/// desktop, on side-loaded and debug builds, and under test the check fails
/// immediately and the gate renders its child untouched.
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate>
    with WidgetsBindingObserver {
  StreamSubscription<InstallStatus>? _progress;
  bool _checking = false;
  bool _offered = false;

  @override
  void initState() {
    super.initState();
    // Nothing is observed and nothing is asked on a platform that has no Play
    // Store, so the gate costs a build method and no more.
    if (!AppUpdateService.isSupported) return;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _progress?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the Play Store is exactly when a download has finished or
    // an interrupted immediate update needs picking up again.
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    final service = ref.read(appUpdateServiceProvider);
    final status = await service.check();
    _checking = false;
    if (!mounted) return;

    switch (status.stance) {
      case UpdateStance.none:
        return;

      case UpdateStance.readyToInstall:
        _promptRestart();

      case UpdateStance.mandatory:
        // Play draws its own full-screen, undismissable flow for this, so the
        // app does not put a dialog of its own in front of it first. Where
        // Play will not allow that flow, the download still starts; it is
        // better than leaving a build Play has ruled out running untouched.
        if (status.immediateAllowed) {
          await service.performImmediate();
        } else if (status.flexibleAllowed) {
          await _startFlexible();
        }

      case UpdateStance.offered:
        // Once per run. An offer the tenant has already declined should not
        // reappear every time they switch away and back.
        if (_offered) return;
        _offered = true;
        _offer(status);
    }
  }

  void _offer(UpdateStatus status) {
    final service = ref.read(appUpdateServiceProvider);
    _show(
      'A newer version of the app is available.',
      action: SnackBarAction(
        label: 'Update',
        onPressed: () {
          if (status.flexibleAllowed) {
            _startFlexible();
          } else {
            service.performImmediate();
          }
        },
      ),
      duration: const Duration(seconds: 8),
    );
  }

  Future<void> _startFlexible() async {
    final service = ref.read(appUpdateServiceProvider);
    // Subscribed before the download starts, so a fast one cannot finish
    // before anything is listening for it.
    _progress ??= service.installProgress.listen((status) {
      if (status == InstallStatus.downloaded) _promptRestart();
    });

    if (await service.startFlexible()) return;
    // Declined or refused: stop listening rather than hold a subscription for
    // a download that never began.
    await _progress?.cancel();
    _progress = null;
  }

  void _promptRestart() {
    if (!mounted) return;
    _show(
      'The update is downloaded and ready to install.',
      action: SnackBarAction(
        label: 'Restart',
        // This restarts the app, so nothing after it runs.
        onPressed: () => ref.read(appUpdateServiceProvider).completeFlexible(),
      ),
      duration: const Duration(seconds: 12),
    );
  }

  void _show(
    String message, {
    required SnackBarAction action,
    required Duration duration,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
