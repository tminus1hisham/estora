import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/access.dart';
import '../application/access_controller.dart';
import 'widgets/claim_editor.dart';

/// What one account is allowed to do.
///
/// Roles and claims side by side, because they are two ways of answering the
/// same question and an administrator holds both in mind at once: the role is
/// the shorthand, the claim is the exception to it.
class UserAccessScreen extends ConsumerWidget {
  const UserAccessScreen({required this.phoneNumber, super.key});

  final String phoneNumber;

  PlatformUser? _find(List<PlatformUser> users) {
    for (final user in users) {
      if (user.phoneNumber == phoneNumber) return user;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(platformUsersProvider);
    final user = users.hasValue ? _find(users.requireValue) : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(user?.fullName ?? 'Account'),
        backgroundColor: Colors.transparent,
      ),
      body: switch (users) {
        AsyncLoading() when !users.hasValue => const LoadingView(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(platformUsersProvider),
        ),
        _ when user == null => const EmptyState(
          icon: Icons.person_off_outlined,
          title: 'That account is no longer listed',
          message: 'It may have been removed from another device.',
        ),
        _ => _Body(user: user),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.user});

  final PlatformUser user;

  Future<void> _toggleEnabled(BuildContext context, WidgetRef ref) async {
    final disabling = user.isActive;
    if (disabling) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Disable ${user.fullName}?'),
          content: const Text(
            'They will not be able to sign in. Nothing is deleted, and the '
            'account can be enabled again from here.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Disable'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    final result = await ref
        .read(accessActionsProvider)
        .toggleEnabled(user.userId ?? user.id);
    if (!context.mounted) return;

    if (result case Err(:final failure)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${user.fullName}?'),
        content: const Text(
          'This removes the account. Disabling it is usually the better answer '
          '— it stops the sign-in without losing who did what.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(accessActionsProvider)
        .deleteUser(user.userId ?? user.id);
    if (!context.mounted) return;

    switch (result) {
      case Ok():
        Navigator.of(context).pop();
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
    final phone = user.phoneNumber!;
    final roles = ref.watch(userRolesProvider(phone));
    final claims = ref.watch(userClaimsProvider(phone));
    final available = ref.watch(accessRolesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userRolesProvider(phone));
        ref.invalidate(userClaimsProvider(phone));
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            children: [
              SectionCard(
                title: 'The account',
                children: [
                  if (user.emailAddress != null)
                    DetailRow(label: 'Email', value: user.emailAddress!),
                  DetailRow(label: 'Phone', value: phone),
                  DetailRow(
                    label: 'Email confirmed',
                    value: user.emailConfirmed ? 'Yes' : 'No',
                  ),
                  DetailRow(
                    label: 'Phone confirmed',
                    value: user.phoneConfirmed ? 'Yes' : 'No',
                  ),
                  DetailRow(
                    label: 'Two-factor',
                    value: user.twoFactorEnabled ? 'On' : 'Off',
                  ),
                  if (user.lastLoginAt != null)
                    DetailRow(
                      label: 'Last signed in',
                      value: AppDate.dateTime(user.lastLoginAt!),
                    ),
                ],
              ),
              Gap.h12,
              _RolesCard(
                phoneNumber: phone,
                granted: roles,
                available: available,
              ),
              Gap.h12,
              ClaimEditor(
                title: 'Permissions for this person',
                description:
                    'Claims granted to the account directly, on top of '
                    'whatever its roles carry.',
                claims: claims,
                onAdd: (type, value) => ref
                    .read(accessActionsProvider)
                    .addClaimToUser(
                      phoneNumber: phone,
                      claimType: type,
                      claimValue: value,
                    ),
                onRemove: (claim) => ref
                    .read(accessActionsProvider)
                    .removeClaimFromUser(
                      phoneNumber: phone,
                      claimType: claim.type,
                      claimValue: claim.value,
                    ),
                onRetry: () => ref.invalidate(userClaimsProvider(phone)),
              ),
              Gap.h12,
              SectionCard(
                title: 'Access to the platform',
                children: [
                  SwitchListTile(
                    value: user.isActive,
                    onChanged: (_) => _toggleEnabled(context, ref),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Can sign in'),
                    subtitle: Text(
                      user.isActive
                          ? 'The account is active.'
                          : 'The account is disabled.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Gap.h8,
                  TextButton.icon(
                    onPressed: () => _delete(context, ref),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete this account'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
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

/// Which roles the account holds, and which it could.
class _RolesCard extends ConsumerWidget {
  const _RolesCard({
    required this.phoneNumber,
    required this.granted,
    required this.available,
  });

  final String phoneNumber;
  final AsyncValue<List<AccessRole>> granted;
  final AsyncValue<List<AccessRole>> available;

  Future<void> _grant(
    BuildContext context,
    WidgetRef ref,
    String roleName,
  ) async {
    final result = await ref
        .read(accessActionsProvider)
        .addUserToRole(phoneNumber: phoneNumber, roleName: roleName);
    if (!context.mounted) return;
    if (result case Err(:final failure)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    String roleName,
  ) async {
    final result = await ref
        .read(accessActionsProvider)
        .removeUserFromRole(phoneNumber: phoneNumber, roleName: roleName);
    if (!context.mounted) return;
    if (result case Err(:final failure)) {
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
    final held = granted.hasValue ? granted.requireValue : const <AccessRole>[];
    final all = available.hasValue
        ? available.requireValue
        : const <AccessRole>[];
    final heldNames = held.map((role) => role.name).toSet();

    return SectionCard(
      title: 'Roles',
      children: [
        if (granted.isLoading && !granted.hasValue)
          const LoadingView(compact: true)
        else if (held.isEmpty)
          Text(
            'No roles granted. This account can sign in and nothing more.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final role in held)
                InputChip(
                  label: Text(role.name),
                  onDeleted: () => _revoke(context, ref, role.name),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                ),
            ],
          ),
        if (all.where((role) => !heldNames.contains(role.name)).isNotEmpty) ...[
          Gap.h16,
          Text('Add a role', style: Theme.of(context).textTheme.labelLarge),
          Gap.h8,
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final role in all)
                if (!heldNames.contains(role.name))
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 16),
                    label: Text(role.name),
                    onPressed: () => _grant(context, ref, role.name),
                  ),
            ],
          ),
        ],
      ],
    );
  }
}
