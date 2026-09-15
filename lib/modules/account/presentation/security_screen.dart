import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../domain/entities/access.dart';
import '../../../navigation/routes.dart';
import '../application/account_controller.dart';

/// Everything about the credentials on this account, in one place.
///
/// The published contract spreads this across five routes — change password,
/// enable two-factor, verify two-factor, confirm email, confirm phone — and a
/// screen per route would be five screens nobody could find. They are one
/// subject: whether this account is who it says it is, and who can get into
/// it. So they are one screen, and the ones that need typing open from here.
class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  Future<void> _enableTwoFactor(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(accountActionsProvider).enableTwoFactor();
    if (!context.mounted) return;

    switch (result) {
      case Ok():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'We have sent a code. Enter it to finish turning two-factor on.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await context.pushNamed(
          Routes.verifyContact,
          pathParameters: {'channel': 'two-factor'},
        );
      case Err(:final failure):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(myAccountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sign-in and security')),
      body: switch (account) {
        AsyncLoading() when !account.hasValue => const LoadingView(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () async {
            await ref.refresh(myAccountProvider.future).then<void>((_) {});
          },
        ),
        _ => _Body(
          account: account.requireValue,
          onEnableTwoFactor: () => _enableTwoFactor(context, ref),
          onRefresh: () async {
            await ref.refresh(myAccountProvider.future).then<void>((_) {});
          },
        ),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.account,
    required this.onEnableTwoFactor,
    required this.onRefresh,
  });

  final PlatformUser account;
  final Future<void> Function() onEnableTwoFactor;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            children: [
              SectionCard(
                title: 'Password',
                children: [
                  Text(
                    'Change it whenever you like. You will need your current '
                    'password.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Gap.h12,
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.password_outlined),
                    title: const Text('Change password'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.pushNamed(Routes.changePassword),
                  ),
                ],
              ),
              Gap.h12,
              SectionCard(
                title: 'Two-factor authentication',
                trailing: StatusChip(
                  label: account.twoFactorEnabled ? 'On' : 'Off',
                  tone: account.twoFactorEnabled
                      ? StatusTone.positive
                      : StatusTone.neutral,
                  dense: true,
                ),
                children: [
                  Text(
                    account.twoFactorEnabled
                        ? 'A code is required alongside your password when you '
                              'sign in.'
                        : 'Adds a code to your sign-in, so a stolen password is '
                              'not enough on its own.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (!account.twoFactorEnabled) ...[
                    Gap.h12,
                    FilledButton.tonalIcon(
                      onPressed: onEnableTwoFactor,
                      icon: const Icon(Icons.shield_outlined),
                      label: const Text('Turn on two-factor'),
                    ),
                  ],
                ],
              ),
              Gap.h12,
              SectionCard(
                title: 'Contact details',
                children: [
                  Text(
                    'Confirming these is how we can reach you about a payment '
                    'or reset your password.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Gap.h8,
                  _ContactRow(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    value: account.emailAddress,
                    confirmed: account.emailConfirmed,
                    channel: 'email',
                  ),
                  _ContactRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone number',
                    value: account.phoneNumber,
                    confirmed: account.phoneConfirmed,
                    channel: 'phone',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.confirmed,
    required this.channel,
  });

  final IconData icon;
  final String label;
  final String? value;
  final bool confirmed;
  final String channel;

  @override
  Widget build(BuildContext context) {
    final missing = value == null || value!.isEmpty;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(missing ? 'Not on file' : value!),
      trailing: confirmed
          ? const StatusChip(
              label: 'Confirmed',
              tone: StatusTone.positive,
              dense: true,
              icon: Icons.check_rounded,
            )
          : const Icon(Icons.chevron_right_rounded),
      // A confirmed detail has nothing to do, and one that is not on file has
      // nothing to confirm — that is an edit on the profile screen, not a
      // verification here.
      onTap: confirmed || missing
          ? null
          : () => context.pushNamed(
              Routes.verifyContact,
              pathParameters: {'channel': channel},
            ),
    );
  }
}
