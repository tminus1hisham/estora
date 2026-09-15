import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../services/providers.dart';
import '../../../services/update/app_update_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../notifications/application/notification_controller.dart';

/// Section 77's Settings screen.
///
/// Covers the two tenant-facing preferences the spec names: biometric unlock
/// (section 72) and notification channels (section 49).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _biometricBusy = false;
  bool _updateBusy = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    // Biometrics are a device capability, not a platform assumption. Web and
    // desktop have no equivalent, so the option is hidden rather than offered
    // and then failing.
    final supportedPlatform =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    final available =
        supportedPlatform &&
        await ref.read(biometricUnlockProvider).isAvailable();
    final enabled =
        available && await ref.read(tokenStoreProvider).isBiometricEnabled();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
    });
  }

  Future<void> _setBiometric(bool value) async {
    if (_biometricBusy) return;
    setState(() => _biometricBusy = true);

    if (value) {
      final result = await ref
          .read(biometricUnlockProvider)
          .authenticate(
            reason: 'Confirm your identity to enable biometric unlock',
          );
      if (!mounted) return;
      if (!result.succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message ?? 'Biometric unlock could not be enabled.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _biometricBusy = false);
        return;
      }
    }

    await ref.read(tokenStoreProvider).setBiometricEnabled(value);
    if (!mounted) return;
    setState(() {
      _biometricEnabled = value;
      _biometricBusy = false;
    });
  }

  /// A check the tenant asked for, so unlike the one at launch it always says
  /// something back — including that there is nothing to install.
  Future<void> _checkForUpdate() async {
    setState(() => _updateBusy = true);
    final service = ref.read(appUpdateServiceProvider);
    final status = await service.check();
    if (!mounted) return;
    setState(() => _updateBusy = false);

    final message = switch (status.stance) {
      UpdateStance.none => 'You are on the latest version.',
      UpdateStance.readyToInstall =>
        'An update is downloaded. Restart the app to install it.',
      _ => 'Downloading the new version...',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );

    // The gate around the app picks the download up from here: it is already
    // listening for the install, and it survives leaving this screen.
    if (status.stance == UpdateStance.none) return;
    if (status.stance == UpdateStance.readyToInstall) {
      await service.completeFlexible();
    } else if (status.flexibleAllowed) {
      await service.startFlexible();
    } else {
      await service.performImmediate();
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to view your lease, invoices and '
          'payments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    // The router's redirect takes over once the auth stage flips.
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(notificationChannelsProvider);
    final selected = channels.value ?? const <NotificationChannel>{};
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.xxl),
        children: [
          _SectionHeader('Appearance'),
          const _ThemeModeControl(),

          const Divider(),
          _SectionHeader('Notifications'),
          // Section 49's channels.
          for (final channel in const [
            NotificationChannel.push,
            NotificationChannel.sms,
            NotificationChannel.email,
          ])
            SwitchListTile(
              value: selected.contains(channel),
              onChanged: channels.hasValue
                  ? (value) => ref
                        .read(notificationChannelsProvider.notifier)
                        .toggle(channel, value)
                  : null,
              title: Text(channel.label),
              subtitle: Text(switch (channel) {
                NotificationChannel.push =>
                  'Invoices, payments and booking reminders on this device',
                NotificationChannel.sms => 'Text messages for urgent alerts',
                NotificationChannel.email => 'Copies of invoices and receipts',
                _ => '',
              }, style: Theme.of(context).textTheme.bodySmall),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
            child: Text(
              'In-app notifications cannot be turned off — they are how we '
              'record what we have told you.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),

          if (_biometricAvailable) ...[
            const Divider(),
            _SectionHeader('Security'),
            SwitchListTile(
              value: _biometricEnabled,
              onChanged: _biometricBusy ? null : _setBiometric,
              title: const Text('Unlock with biometrics'),
              subtitle: Text(
                _biometricBusy
                    ? 'Waiting for device authentication...'
                    : 'Require your fingerprint or face before restoring your '
                          'session',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],

          const Divider(),
          _SectionHeader('About'),
          const ListTile(title: Text('Version'), trailing: Text('1.0.0')),
          // The app asks Play on its own at launch. This is for the tenant who
          // has been told a fix is out and wants to go and get it rather than
          // wait to be offered it.
          if (AppUpdateService.isSupported)
            ListTile(
              leading: const Icon(Icons.system_update_outlined),
              title: const Text('Check for updates'),
              subtitle: Text(
                _updateBusy ? 'Asking Google Play...' : 'Via Google Play',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onTap: _updateBusy ? null : _checkForUpdate,
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: OutlinedButton.icon(
              onPressed: _confirmLogout,
              style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}

/// System, Light or Dark.
///
/// A segmented button rather than a single dark-mode switch: "System" is a
/// real third choice, and a switch cannot express following the platform.
class _ThemeModeControl extends ConsumerWidget {
  const _ThemeModeControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeModeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ThemeMode>(
            segments: [
              for (final mode in ThemeMode.values)
                ButtonSegment<ThemeMode>(
                  value: mode,
                  label: Text(mode.label),
                  icon: Icon(mode.icon),
                ),
            ],
            selected: {selected},
            showSelectedIcon: false,
            onSelectionChanged: (values) =>
                ref.read(themeModeProvider.notifier).select(values.first),
          ),
          Gap.h8,
          Text(
            selected == ThemeMode.system
                ? 'Following your device setting.'
                : 'Staying ${selected.label.toLowerCase()} whatever your '
                      'device is set to.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: AppTypography.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
