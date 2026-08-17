import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_reveal.dart';
import '../../../components/page_header.dart';
import '../../../components/record_group.dart';
import '../../../components/section_card.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
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
        eyebrow: 'Owner',
        title: owner?.displayName ?? user?.fullName ?? 'Account',
        subtitle: owner?.legalName,
      ),
      SectionCard(
        title: 'Business',
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
      RecordGroup(
        heading: 'Session',
        rowInset: 56,
        children: [
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sign out'),
            subtitle: AppConfig.isMock
                // There is no view-as toggle by design: an owner account has
                // no tenancy to show. The login screen offers both demo
                // accounts, so switching sides is a sign-out away.
                ? const Text('Pick the tenant demo account to see that side.')
                : null,
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxReadingWidth),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.xxl),
            itemCount: sections.length,
            separatorBuilder: (_, _) => Gap.h16,
            itemBuilder: (context, index) =>
                AppReveal(index: index, child: sections[index]),
          ),
        ),
      ),
    );
  }
}
