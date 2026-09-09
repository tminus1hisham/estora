import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_skeleton.dart';
import '../../../components/record_group.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../domain/entities/access.dart';
import '../../../navigation/routes.dart';
import '../application/access_controller.dart';

/// The roles the platform defines.
///
/// Roles can be created but not deleted here, because the contract publishes
/// no delete. Offering a control that would 404 is worse than not offering it;
/// what is missing is stated on the screen rather than left to be discovered.
class RolesScreen extends ConsumerWidget {
  const RolesScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _NewRoleDialog(),
    );
    if (name == null || !context.mounted) return;

    final result = await ref.read(accessActionsProvider).createRole(name);
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
    final roles = ref.watch(accessRolesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Roles'),
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New role'),
      ),
      body: switch (roles) {
        AsyncLoading() when !roles.hasValue => const AppSkeletonList(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(accessRolesProvider),
        ),
        _ => _RoleList(
          roles: roles.requireValue,
          onRefresh: () async => ref.invalidate(accessRolesProvider),
        ),
      },
    );
  }
}

class _RoleList extends StatelessWidget {
  const _RoleList({required this.roles, required this.onRefresh});

  final List<AccessRole> roles;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.badge_outlined,
                title: 'No roles yet',
                message:
                    'A role gathers the permissions a job needs, so they can '
                    'be granted once rather than one at a time.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 96),
            children: [
              RecordGroup(
                heading:
                    '${roles.length} '
                    '${roles.length == 1 ? 'role' : 'roles'}',
                children: [
                  for (final role in roles)
                    RecordRow(
                      icon: Icons.badge_outlined,
                      iconColor: context.statusColors.resolve(StatusTone.info),
                      title: role.name,
                      subtitle: 'Permissions carried by this role',
                      onTap: () => context.pushNamed(
                        Routes.accessRole,
                        pathParameters: {'roleName': role.name},
                      ),
                    ),
                ],
              ),
              Gap.h16,
              Text(
                'Roles cannot be deleted from the app — the API publishes no '
                'route for it.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewRoleDialog extends StatefulWidget {
  const _NewRoleDialog();

  @override
  State<_NewRoleDialog> createState() => _NewRoleDialogState();
}

class _NewRoleDialogState extends State<_NewRoleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New role'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Role name',
            hintText: 'FinanceOfficer',
            helperText: 'One word, no spaces, as the platform names its roles.',
            helperMaxLines: 2,
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return 'Give the role a name';
            return text.contains(' ')
                ? 'Use a single word without spaces'
                : null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
