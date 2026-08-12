import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../services/providers.dart';
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

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    // Biometrics are a device capability, not a platform assumption. Web and
    // desktop have no equivalent, so the option is hidden rather than offered
    // and then failing.
    final available =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    final enabled = await ref.read(tokenStoreProvider).isBiometricEnabled();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
    });
  }

  Future<void> _setBiometric(bool value) async {
    await ref.read(tokenStoreProvider).setBiometricEnabled(value);
    if (mounted) setState(() => _biometricEnabled = value);
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
              subtitle: Text(
                switch (channel) {
                  NotificationChannel.push =>
                    'Invoices, payments and booking reminders on this device',
                  NotificationChannel.sms => 'Text messages for urgent alerts',
                  NotificationChannel.email => 'Copies of invoices and receipts',
                  _ => '',
                },
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
              onChanged: _setBiometric,
              title: const Text('Unlock with biometrics'),
              subtitle: Text(
                'Use your fingerprint or face to open the app',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],

          const Divider(),
          _SectionHeader('About'),
          const ListTile(
            title: Text('Version'),
            trailing: Text('1.0.0'),
          ),
          if (AppConfig.isMock)
            ListTile(
              leading: Icon(Icons.science_outlined, color: scheme.tertiary),
              title: const Text('Demo data'),
              subtitle: Text(
                'This build runs against an in-memory mock of the platform '
                'API. No real bookings or payments are made.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
