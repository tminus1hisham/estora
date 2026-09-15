import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/record_group.dart';
import '../../../components/section_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../navigation/routes.dart';
import '../../auth/application/auth_controller.dart';

/// Section 77's Profile screen, and the entry point for the account section of
/// section 45's navigation — payments, documents and settings hang off here.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final tenant = auth.tenant;
    final profile = tenant?.profile;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: AppRefreshIndicator(
        onRefresh: () async {
          await ref.read(authControllerProvider.notifier).refreshProfile();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
          children: [
            AppSurfaceCard(
              color: scheme.secondary,
              borderColor: Colors.transparent,
              elevation: AppElevation.low,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      user?.initials ?? '?',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Gap.w16,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenant?.displayName ??
                              user?.fullName ??
                              'Your account',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: scheme.onSecondary),
                        ),
                        if (tenant != null) ...[
                          Gap.h4,
                          Text(
                            tenant.tenantType.label,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: scheme.onSecondary.withValues(
                                    alpha: 0.68,
                                  ),
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit profile',
                    onPressed: () => context.pushNamed(Routes.editProfile),
                    style: IconButton.styleFrom(
                      foregroundColor: scheme.onSecondary,
                      backgroundColor: scheme.onSecondary.withValues(
                        alpha: 0.1,
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
            Gap.h24,

            SectionCard(
              title: 'Contact',
              trailing: TextButton(
                onPressed: () => context.pushNamed(Routes.editProfile),
                child: const Text('Edit'),
              ),
              children: [
                DetailRow(label: 'Name', value: user?.fullName ?? '—'),
                DetailRow(
                  label: 'Phone',
                  valueWidget: _VerifiedValue(
                    value: user?.phone ?? '—',
                    verified: user?.phoneVerified ?? false,
                  ),
                ),
                DetailRow(
                  label: 'Email',
                  valueWidget: _VerifiedValue(
                    value: user?.email ?? '—',
                    verified: user?.emailVerified ?? false,
                  ),
                ),
                if (profile?.address != null)
                  DetailRow(label: 'Address', value: profile!.address!),
              ],
            ),

            if (profile != null &&
                (tenant?.tenantType.isOrganisation ?? false)) ...[
              Gap.h12,
              SectionCard(
                title: 'Business details',
                children: [
                  if (profile.legalName != null)
                    DetailRow(label: 'Legal name', value: profile.legalName!),
                  if (profile.registrationNumber != null)
                    DetailRow(
                      label: 'Registration number',
                      value: profile.registrationNumber!,
                    ),
                  if (profile.maskedTaxNumber != null)
                    DetailRow(
                      label: 'Tax number',
                      value: profile.maskedTaxNumber!,
                    ),
                  if (profile.contactPerson != null)
                    DetailRow(
                      label: 'Contact person',
                      value: profile.contactPerson!,
                    ),
                ],
              ),
            ],

            if (profile?.maskedNationalId != null ||
                profile?.maskedPassportNumber != null) ...[
              Gap.h12,
              SectionCard(
                title: 'Identification',
                children: [
                  if (profile?.maskedNationalId != null)
                    DetailRow(
                      label: 'National ID',
                      value: profile!.maskedNationalId!,
                    ),
                  if (profile?.maskedPassportNumber != null)
                    DetailRow(
                      label: 'Passport',
                      value: profile!.maskedPassportNumber!,
                    ),
                  Gap.h8,
                  Text(
                    // Section 20 requires this data to be encrypted at rest;
                    // masking it here is the display-side counterpart, so the
                    // number is not left readable on a screen in a public place.
                    'Partially hidden for your security. Your property manager '
                    'holds the full details on file.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],

            Gap.h24,
            RecordGroup(
              heading: 'Your account',
              // A ListTile's own leading icon sits 56 in, not 68.
              rowInset: 56,
              children: [
                _NavTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Payment history',
                  onTap: () => context.pushNamed(Routes.paymentHistory),
                ),
                _NavTile(
                  icon: Icons.folder_outlined,
                  label: 'Documents',
                  onTap: () => context.pushNamed(Routes.documents),
                ),
                _NavTile(
                  icon: Icons.event_note_outlined,
                  label: 'My bookings',
                  onTap: () => context.pushNamed(Routes.bookings),
                ),
                _NavTile(
                  icon: Icons.lock_outline_rounded,
                  label: 'Sign-in and security',
                  onTap: () => context.pushNamed(Routes.security),
                ),
                _NavTile(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => context.pushNamed(Routes.settings),
                ),
              ],
            ),

            if (user?.lastLoginAt != null) ...[
              Gap.h16,
              Center(
                child: Text(
                  'Last signed in ${AppDate.dateTime(user!.lastLoginAt!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerifiedValue extends StatelessWidget {
  const _VerifiedValue({required this.value, required this.verified});

  final String value;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: AppTypography.semibold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (verified) ...[
          Gap.w4,
          Icon(
            Icons.verified_rounded,
            size: 15,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
