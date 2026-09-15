import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/record_group.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../domain/entities/access.dart';
import '../../../navigation/routes.dart';
import '../application/access_controller.dart';

/// Every account on the platform.
///
/// Disabled accounts are shown rather than hidden. An administrator asking
/// "why can this person not sign in" needs to find the account to answer it,
/// and a list that quietly omits them turns a ten-second check into a support
/// ticket.
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(platformUsersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('People'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () => context.pushNamed(Routes.accessRoles),
            icon: const Icon(Icons.badge_outlined),
            tooltip: 'Roles',
          ),
        ],
      ),
      body: switch (users) {
        AsyncLoading() when !users.hasValue => const AppSkeletonList(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () async {
            await ref.refresh(platformUsersProvider.future).then<void>((_) {});
          },
        ),
        _ => _UserList(
          users: users.requireValue,
          onRefresh: () async {
            await ref.refresh(platformUsersProvider.future).then<void>((_) {});
          },
        ),
      },
    );
  }
}

class _UserList extends StatelessWidget {
  const _UserList({required this.users, required this.onRefresh});

  final List<PlatformUser> users;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return AppRefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.group_outlined,
                title: 'No accounts',
                message: 'Accounts appear here as people register.',
              ),
            ),
          ],
        ),
      );
    }

    final active = users.where((user) => user.isActive).toList();
    final disabled = users.where((user) => !user.isActive).toList();

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
              if (active.isNotEmpty)
                RecordGroup(
                  heading:
                      '${active.length} active '
                      '${active.length == 1 ? 'account' : 'accounts'}',
                  children: [for (final user in active) _UserRow(user)],
                ),
              if (disabled.isNotEmpty) ...[
                Gap.h16,
                RecordGroup(
                  heading: 'Disabled',
                  children: [for (final user in disabled) _UserRow(user)],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow(this.user);

  final PlatformUser user;

  @override
  Widget build(BuildContext context) {
    final roles = user.roles.isEmpty ? null : user.roles.join(', ');

    return RecordRow(
      icon: user.isActive
          ? Icons.person_outline_rounded
          : Icons.person_off_outlined,
      iconColor: context.statusColors.resolve(
        user.isActive ? StatusTone.info : StatusTone.neutral,
      ),
      title: user.fullName,
      subtitle: user.contactLabel.isEmpty ? null : user.contactLabel,
      caption: roles,
      footnote: user.isActive
          ? null
          : const StatusChip(
              label: 'Disabled',
              tone: StatusTone.neutral,
              dense: true,
            ),
      // Roles and claims are addressed by phone number, so an account without
      // one cannot be granted anything. Rather than open a screen whose every
      // control would fail, the row says why it does not open.
      onTap: user.isAddressable
          ? () => context.pushNamed(
              Routes.accessUser,
              pathParameters: {'phoneNumber': user.phoneNumber!},
            )
          : () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${user.fullName} has no phone number on file, so roles and '
                  'permissions cannot be changed.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            ),
    );
  }
}
