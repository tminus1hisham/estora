import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/record_group.dart';
import '../../../components/section_card.dart';
import '../../../components/surface_atoms.dart';
import '../../../components/theme_mode_control.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/routes.dart';
import '../../auth/application/auth_controller.dart';

/// The manager's identity, account details and preferences.
class OwnerAccountScreen extends ConsumerWidget {
  const OwnerAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final owner = auth.owner;
    final user = auth.user;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final businessDetails = <Widget>[
      if (owner?.registrationNumber != null)
        DetailRow(
          label: 'Registration number',
          value: owner!.registrationNumber!,
        ),
      if (owner?.taxNumber != null)
        DetailRow(label: 'Tax number', value: owner!.taxNumber!),
      if (owner?.maskedPayoutAccount != null)
        DetailRow(label: 'Payout account', value: owner!.maskedPayoutAccount!),
    ];

    final sections = <Widget>[
      AppSurfaceCard(
        padding: const EdgeInsets.all(Gap.lg),
        borderColor: scheme.primary.withValues(alpha: 0.25),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.surfaceContainerHigh, scheme.surfaceContainerLowest],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: AppRadius.medium,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                owner?.initials ?? user?.initials ?? '?',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: AppTypography.bold,
                ),
              ),
            ),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MANAGER ACCOUNT',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: AppTypography.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Gap.h4,
                  Text(
                    owner?.displayName ?? user?.fullName ?? 'Your account',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppTypography.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (owner?.legalName != null) ...[
                    Gap.h4,
                    Text(
                      owner!.legalName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      SectionCard(
        title: 'Contact details',
        trailing: Icon(
          Icons.contact_mail_outlined,
          size: 20,
          color: scheme.primary,
        ),
        children: [
          _ContactDetail(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: user?.email,
          ),
          const Divider(height: 24),
          _ContactDetail(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: user?.phone,
          ),
        ],
      ),
      if (businessDetails.isNotEmpty)
        SectionCard(
          title: 'Business & payouts',
          trailing: Icon(
            Icons.account_balance_outlined,
            size: 20,
            color: scheme.primary,
          ),
          children: businessDetails,
        ),
      if (AppConfig.showAdministration)
        RecordGroup(
          heading: 'Administration',
          children: [
            _AccountAction(
              icon: Icons.group_outlined,
              title: 'People',
              subtitle: 'Manage accounts and access.',
              onTap: () => context.pushNamed(Routes.accessUsers),
            ),
            _AccountAction(
              icon: Icons.badge_outlined,
              title: 'Roles',
              subtitle: 'Set permissions for each role.',
              onTap: () => context.pushNamed(Routes.accessRoles),
            ),
          ],
        ),
      RecordGroup(
        heading: 'Security',
        children: [
          _AccountAction(
            icon: Icons.lock_outline_rounded,
            title: 'Sign-in and security',
            subtitle: 'Manage your password and verify your contacts.',
            onTap: () => context.pushNamed(Routes.security),
          ),
        ],
      ),
      const RecordGroup(
        heading: 'Appearance',
        children: [
          Padding(
            padding: EdgeInsets.only(top: Gap.lg),
            child: ThemeModeControl(),
          ),
        ],
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: scheme.error,
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg,
              vertical: Gap.md,
            ),
          ),
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: const Text('Sign out'),
        ),
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
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.xs,
                Gap.lg,
                Gap.xxl,
              ),
              itemCount: sections.length,
              separatorBuilder: (_, _) => Gap.h24,
              itemBuilder: (context, index) =>
                  AppReveal(index: index, child: sections[index]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactDetail extends StatelessWidget {
  const _ContactDetail({required this.icon, required this.label, this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ToneIconTile(icon: icon, color: theme.colorScheme.primary),
        Gap.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Gap.h4,
              SelectableText(
                value == null || value!.trim().isEmpty
                    ? 'Not provided'
                    : value!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: AppTypography.semibold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountAction extends StatelessWidget {
  const _AccountAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Row(
          children: [
            ToneIconTile(icon: icon, color: theme.colorScheme.primary),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  Gap.h4,
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Gap.w8,
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
