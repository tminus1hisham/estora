import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_reveal.dart';
import '../../../components/page_header.dart';
import '../../../components/record_group.dart';
import '../../../components/section_card.dart';
import '../../../components/theme_mode_control.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/routes.dart';
import '../../auth/application/auth_controller.dart';

/// Section 88. The owner's account, and the way back to the tenant side.
class OwnerAccountScreen extends ConsumerWidget {
  const OwnerAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final owner = auth.owner;
    final user = auth.user;

    final sections = <Widget>[
      PageHeader(
        eyebrow: 'Manager',
        title: owner?.displayName ?? user?.fullName ?? 'Account',
        subtitle: owner?.legalName,
      ),
      SectionCard(
        title: 'Account details',
        children: [
          if (owner?.registrationNumber != null)
            DetailRow(
              label: 'Registration number',
              value: owner!.registrationNumber!,
            ),
          if (owner?.taxNumber != null)
            DetailRow(label: 'Tax number', value: owner!.taxNumber!),
          if (owner?.maskedPayoutAccount != null)
            DetailRow(
              label: 'Payout account',
              value: owner!.maskedPayoutAccount!,
            ),
          if (user?.email != null)
            DetailRow(label: 'Email', value: user!.email!),
          if (user?.phone != null)
            DetailRow(label: 'Phone', value: user!.phone!),
        ],
      ),
      if (AppConfig.showAdministration)
        RecordGroup(
          heading: 'Administration',
          rowInset: 56,
          children: [
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('People'),
              subtitle: const Text(
                'Who has an account, and what each of them may do.',
              ),
              onTap: () => context.pushNamed(Routes.accessUsers),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Roles'),
              subtitle: const Text(
                'The permissions a job carries, granted once instead of one at '
                'a time.',
              ),
              onTap: () => context.pushNamed(Routes.accessRoles),
            ),
          ],
        ),
      const RecordGroup(heading: 'Appearance', children: [ThemeModeControl()]),
      RecordGroup(
        heading: 'Session',
        rowInset: 56,
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline_rounded),
            title: const Text('Sign-in and security'),
            subtitle: const Text(
              'Your password, two-factor, and confirming your contact details.',
            ),
            onTap: () => context.pushNamed(Routes.security),
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sign out'),
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: Colors.transparent,
      ),
      body: AppRefreshIndicator(
        onRefresh: () async {
          await ref.read(authControllerProvider.notifier).refreshProfile();
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.maxReadingWidth,
            ),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.xs,
                Gap.lg,
                Gap.xxl,
              ),
              itemCount: sections.length,
              separatorBuilder: (_, _) => Gap.h16,
              itemBuilder: (context, index) =>
                  AppReveal(index: index, child: sections[index]),
            ),
          ),
        ),
      ),
    );
  }
}
