import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

import '../../core/config/app_config.dart';

/// What Google Play says this handset should do about a newer build.
enum UpdateStance {
  /// Nothing to do. Either the installed build is current, or Play has no
  /// opinion to give: a debug or side-loaded build, no Play Store on the
  /// device, or no network. Every one of those lands here rather than in
  /// front of the tenant.
  none,

  /// A newer build exists and the tenant is offered it. Declining is a real
  /// answer, and the app keeps working on the build it has.
  offered,

  /// A newer build exists and this one should stop being used: the release was
  /// published at [AppConfig.blockingUpdatePriority] or above, or the handset
  /// has been ignoring it for [AppConfig.forcedUpdateStalenessDays]. Play
  /// draws its own blocking flow for this.
  mandatory,

  /// A background download has already finished. All that is left is the
  /// restart that swaps the build over.
  readyToInstall,
}

/// One reading of Play's update state, with the flows Play will allow.
///
/// Both flags matter to the caller: Play refuses a flexible update on some
/// releases and an immediate one on others, so which prompt to show is not
/// the app's choice alone.
class UpdateStatus {
  const UpdateStatus._({
    required this.stance,
    this.flexibleAllowed = false,
    this.immediateAllowed = false,
    this.availableVersionCode,
    this.stalenessDays,
    this.priority = 0,
  });

  const UpdateStatus.none() : this._(stance: UpdateStance.none);

  UpdateStatus._from(AppUpdateInfo info, UpdateStance stance)
    : this._(
        stance: stance,
        flexibleAllowed: info.flexibleUpdateAllowed,
        immediateAllowed: info.immediateUpdateAllowed,
        availableVersionCode: info.availableVersionCode,
        stalenessDays: info.clientVersionStalenessDays,
        priority: info.updatePriority,
      );

  final UpdateStance stance;

  /// Play will let the build download in the background while the app runs.
  final bool flexibleAllowed;

  /// Play will take over the screen and install the build itself.
  final bool immediateAllowed;

  /// The versionCode waiting in the store, or null when nothing is.
  final int? availableVersionCode;

  /// Days since the Play Store on this device first learned about the update.
  /// Null when Play has no figure, which is not the same as zero.
  final int? stalenessDays;

  /// The release's in-app update priority, 0-5, as set when it was published.
  final int priority;

  bool get hasUpdate => stance != UpdateStance.none;
}

/// The boundary around Google Play's in-app update API.
///
/// The API is Android-only and only answers for builds the Play Store itself
/// installed. Rather than let that leak into the widgets, everything here has
/// one shape of failure: no update. A tenant on iOS, on a side-loaded build,
/// or offline is never shown an error about an update they cannot take.
class AppUpdateService {
  const AppUpdateService();

  /// Whether Play in-app updates exist on this platform at all. iOS, web and
  /// desktop have no equivalent, so the call is skipped rather than made and
  /// swallowed.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Asks Play what it has, and turns the answer into a stance.
  Future<UpdateStatus> check() async {
    if (!isSupported) return const UpdateStatus.none();

    final AppUpdateInfo info;
    try {
      info = await InAppUpdate.checkForUpdate();
    } catch (_) {
      return const UpdateStatus.none();
    }

    switch (info.updateAvailability) {
      case UpdateAvailability.updateAvailable:
        final staleness = info.clientVersionStalenessDays;
        final overdue =
            staleness != null &&
            staleness >= AppConfig.forcedUpdateStalenessDays;
        final urgent = info.updatePriority >= AppConfig.blockingUpdatePriority;

        if ((urgent || overdue) && info.immediateUpdateAllowed) {
          return UpdateStatus._from(info, UpdateStance.mandatory);
        }
        if (info.flexibleUpdateAllowed || info.immediateUpdateAllowed) {
          return UpdateStatus._from(info, UpdateStance.offered);
        }
        return const UpdateStatus.none();

      case UpdateAvailability.developerTriggeredUpdateInProgress:
        // An update this app already started, found again on a later launch or
        // on resume. What to do about it depends on how far it got.
        return switch (info.installStatus) {
          // A background download that finished while the app was away.
          InstallStatus.downloaded => UpdateStatus._from(
            info,
            UpdateStance.readyToInstall,
          ),
          // Still coming down. Leave it alone: the install listener says when
          // it has landed, and interrupting it only starts it again.
          InstallStatus.pending ||
          InstallStatus.downloading => const UpdateStatus.none(),
          // An immediate update that was interrupted. Play expects it to be
          // resumed rather than started over.
          _ => UpdateStatus._from(info, UpdateStance.mandatory),
        };

      case UpdateAvailability.updateNotAvailable:
      case UpdateAvailability.unknown:
        return const UpdateStatus.none();
    }
  }

  /// Downloads the new build in the background, leaving the tenant on the
  /// screen they were on. False means they declined or Play refused.
  Future<bool> startFlexible() => _run(InAppUpdate.startFlexibleUpdate);

  /// Hands the screen to Play, which installs the build and restarts the app
  /// itself. False means they backed out.
  Future<bool> performImmediate() => _run(InAppUpdate.performImmediateUpdate);

  /// Installs a build that [startFlexible] already downloaded. This restarts
  /// the app, so nothing after it runs.
  Future<void> completeFlexible() async {
    if (!isSupported) return;
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (_) {
      // The download can be discarded by the store between finishing and the
      // tenant tapping restart. The next check picks it up again.
    }
  }

  /// Progress of a flexible download in flight.
  Stream<InstallStatus> get installProgress => isSupported
      ? InAppUpdate.installUpdateListener
      : const Stream<InstallStatus>.empty();

  Future<bool> _run(Future<AppUpdateResult> Function() flow) async {
    if (!isSupported) return false;
    try {
      return await flow() == AppUpdateResult.success;
    } catch (_) {
      return false;
    }
  }
}
