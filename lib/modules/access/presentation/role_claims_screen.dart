import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../core/theme/app_theme.dart';
import '../application/access_controller.dart';
import 'widgets/claim_editor.dart';

/// What a role carries.
///
/// Everyone holding the role gets everything on this screen, which is the
/// point of a role and also the reason a change here deserves more thought
/// than the same change against one account.
class RoleClaimsScreen extends ConsumerWidget {
  const RoleClaimsScreen({required this.roleName, super.key});

  final String roleName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(roleClaimsProvider(roleName));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(roleName),
        backgroundColor: Colors.transparent,
      ),
      body: AppRefreshIndicator(
        onRefresh: () async {
          await ref
              .refresh(roleClaimsProvider(roleName).future)
              .then<void>((_) {});
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.maxReadingWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.sm,
                Gap.lg,
                Gap.xxl,
              ),
              children: [
                ClaimEditor(
                  title: 'Permissions',
                  description:
                      'Granted to everyone who holds the $roleName role. '
                      'Removing one takes it from all of them at once.',
                  claims: claims,
                  onAdd: (type, value) => ref
                      .read(accessActionsProvider)
                      .addClaimToRole(
                        roleName: roleName,
                        claimType: type,
                        claimValue: value,
                      ),
                  onRemove: (claim) => ref
                      .read(accessActionsProvider)
                      .removeClaimFromRole(
                        roleName: roleName,
                        claimType: claim.type,
                        claimValue: claim.value,
                      ),
                  onRetry: () async {
                    await ref
                        .refresh(roleClaimsProvider(roleName).future)
                        .then<void>((_) {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
