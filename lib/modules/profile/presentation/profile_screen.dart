import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_pressable.dart';
import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/section_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../navigation/routes.dart';
import '../../auth/application/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final tenant = auth.tenant;
    final profile = tenant?.profile;
    final scheme = Theme.of(context).colorScheme;

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          title: 'Personal details',
          subtitle: 'The essentials, all in one place.',
          children: [
            _ContactField(
              icon: Icons.person_outline_rounded,
              label: 'Full name',
              value: user?.fullName,
            ),
            _ContactField(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: user?.phone,
              verified: user?.phoneVerified ?? false,
            ),
            _ContactField(
              icon: Icons.alternate_email_rounded,
              label: 'Email',
              value: user?.email,
              verified: user?.emailVerified ?? false,
            ),
            if (profile?.address != null)
              _ContactField(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: profile!.address,
              ),
          ],
        ),
        if (profile != null &&
            (tenant?.tenantType.isOrganisation ?? false)) ...[
          Gap.h16,
          _Panel(
            title: 'Business details',
            subtitle: 'Your organisation on record.',
            children: [
              if (profile.legalName != null)
                DetailRow(label: 'Legal name', value: profile.legalName!),
              if (profile.registrationNumber != null)
                DetailRow(
                  label: 'Registration number',
                  value: profile.registrationNumber!,
                ),
              if (profile.maskedTaxNumber != null)
                DetailRow(label: 'Tax number', value: profile.maskedTaxNumber!),
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
          Gap.h16,
          _Panel(
            title: 'Identification',
            subtitle: 'Private details. Carefully protected.',
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
              Gap.h12,
              Text(
                'Partially hidden for your security. Your property manager holds the full details on file.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ],
    );
    // Browse lost its tab to Utilities, so this is the way back to it for a
    // tenant who is already settled — and the place a tenant who is not yet
    // settled looks first. Support sits directly beneath it: both are things
    // the tenant reaches outside their own tenancy.
    final beyond = _Panel(
      title: 'Browse more properties',
      subtitle: 'Room to grow, and a hand when you need one.',
      children: [
        _AccountLink(
          icon: Icons.storefront_outlined,
          title: 'Available spaces',
          subtitle: 'Every space you can book today',
          route: Routes.browse,
        ),
        const Divider(height: 16),
        _AccountLink(
          icon: Icons.support_agent_rounded,
          title: 'Support tickets',
          subtitle: 'Raise an issue and follow it through',
          route: Routes.support,
        ),
      ],
    );

    final preferences = _Panel(
      title: 'Make it yours',
      subtitle: 'Your account, your preferences.',
      children: [
        _AccountLink(
          icon: Icons.lock_outline_rounded,
          title: 'Sign-in and security',
          subtitle: 'Manage access to your account',
          route: Routes.security,
        ),
        const Divider(height: 16),
        _AccountLink(
          icon: Icons.tune_rounded,
          title: 'Settings',
          subtitle: 'Personalise your experience',
          route: Routes.settings,
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: AppRefreshIndicator(
        onRefresh: () =>
            ref.read(authControllerProvider.notifier).refreshProfile(),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppReveal(
                      child: _ProfileHero(
                        name:
                            tenant?.displayName ??
                            user?.fullName ??
                            'Your account',
                        initials: user?.initials ?? '?',
                        type: tenant?.tenantType.label ?? 'Tenant account',
                      ),
                    ),
                    Gap.h16,
                    AppReveal(
                      index: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Text(
                          //   'Your tenancy, within reach',
                          //   style: Theme.of(context).textTheme.titleSmall
                          //       ?.copyWith(fontWeight: FontWeight.w800),
                          // ),
                          // Gap.h12,
                          // const _QuickLinks(),
                        ],
                      ),
                    ),
                    // Gap.h16,
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 760) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: AppReveal(index: 2, child: details),
                              ),
                              Gap.w16,
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    AppReveal(index: 3, child: beyond),
                                    Gap.h16,
                                    AppReveal(index: 4, child: preferences),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppReveal(index: 2, child: details),
                            Gap.h16,
                            AppReveal(index: 3, child: beyond),
                            Gap.h16,
                            AppReveal(index: 4, child: preferences),
                          ],
                        );
                      },
                    ),
                    Gap.h16,
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(authControllerProvider.notifier).logout(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        minimumSize: const Size(0, 48),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign out'),
                    ),
                    if (user?.lastLoginAt != null) ...[
                      Gap.h16,
                      Text(
                        'Last signed in ${AppDate.dateTime(user!.lastLoginAt!)}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.initials,
    required this.type,
  });
  final String name;
  final String initials;
  final String type;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(
          color: AppPalette.brass200.withValues(alpha: 0.65),
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: AppPalette.stone0,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppPalette.stone0,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        Gap.h4,
        Text(
          type,
          style: const TextStyle(color: AppPalette.azure200, fontSize: 12.5),
        ),
      ],
    );
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(20),
      borderColor: Colors.white.withValues(alpha: 0.12),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppPalette.navy900, AppPalette.navy800, AppPalette.azure800],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -110,
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07),
                      width: 36,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -150,
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppPalette.azure300.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                avatar,
                Gap.w12,
                Expanded(child: identity),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Transactions is a pane of the invoices tab, so it is switched to rather
    // than pushed; the other two are pages of this tab.
    final links = [
      (
        Icons.event_available_outlined,
        'My bookings',
        'Holds, past and present',
        () => context.pushNamed(Routes.bookings),
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      (
        Icons.folder_open_rounded,
        'Documents',
        'Your files, organised',
        () => context.pushNamed(Routes.documents),
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      (
        Icons.receipt_long_outlined,
        'Transactions',
        'Every payment, in view',
        () => context.goNamed(
          Routes.invoices,
          queryParameters: {
            Routes.invoicesTabQuery: Routes.invoicesTransactionsTab,
          },
        ),
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(14) > 20;
        final width = stacked
            ? constraints.maxWidth
            : (constraints.maxWidth - 24) / 3;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final link in links)
              SizedBox(
                width: width,
                child: AppPressable(
                  child: AppSurfaceCard(
                    padding: const EdgeInsets.all(12),
                    onTap: link.$4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: link.$5,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(link.$1, color: link.$6, size: 20),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_outward_rounded,
                              size: 16,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                        Gap.h16,
                        Text(
                          link.$2,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Gap.h4,
                        Text(
                          link.$3,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        Gap.h4,
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

class _ContactField extends StatelessWidget {
  const _ContactField({
    required this.icon,
    required this.label,
    this.value,
    this.verified = false,
  });
  final IconData icon;
  final String label;
  final String? value;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasValue = value != null && value!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: scheme.onSurfaceVariant),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (verified && hasValue)
                      Semantics(
                        label: '$label verified',
                        child: Tooltip(
                          message: 'Verified',
                          child: Icon(
                            Icons.verified_rounded,
                            size: 15,
                            color: scheme.brightness == Brightness.dark
                                ? AppPalette.green300
                                : AppPalette.green700,
                          ),
                        ),
                      ),
                  ],
                ),
                Gap.h4,
                Text(
                  hasValue ? value! : 'Not added yet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    color: hasValue
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountLink extends StatelessWidget {
  const _AccountLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppPressable(
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: scheme.primary),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: () => context.pushNamed(route),
      ),
    );
  }
}
