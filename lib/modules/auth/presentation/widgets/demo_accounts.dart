import 'package:flutter/material.dart';

import '../../../../components/app_pressable.dart';
import '../../../../core/theme/app_theme.dart';
import 'auth_stage.dart';

/// One of the accounts the seeded mock can sign in as.
class DemoAccount {
  const DemoAccount({
    required this.email,
    required this.name,
    required this.role,
    required this.detail,
    required this.icon,
  });

  final String email;
  final String name;

  /// `Tenant` or `Owner` — the word that decides which half of the app opens.
  final String role;

  /// What this account will be looking at once it is in.
  final String detail;

  final IconData icon;
}

/// The two sides of the platform, one tap apart.
///
/// An account has exactly one role (section 88) and the router enforces it, so
/// moving between the tenant and the owner experience means changing account.
/// There is deliberately no toggle: an owner has no tenant record to show and
/// a tenant has no portfolio, so a switch that claimed to flip between them
/// would land you on screens with nothing behind them.
///
/// This exists only while the app runs on the mock. It is the demo's front
/// door, and it disappears the moment `AppConfig.dataSource` points at a real
/// backend.
class DemoAccounts extends StatelessWidget {
  const DemoAccounts({
    required this.onSelected,
    this.enabled = true,
    this.pendingEmail,
    super.key,
  });

  /// Signs straight in as the chosen account. No password is asked for: the
  /// mock accepts any non-empty one, and prompting would be theatre.
  final ValueChanged<DemoAccount> onSelected;

  final bool enabled;

  /// The account currently signing in, which takes a spinner in place of its
  /// arrow. Sign-in is not instant even against the mock, and a tile that
  /// looked inert while it worked would just get tapped again.
  final String? pendingEmail;

  static const accounts = <DemoAccount>[
    DemoAccount(
      email: 'amina@example.co.ke',
      name: 'Amina Wanjiru',
      role: 'Tenant',
      detail: 'Wanjiru Retail · SHOP-101 at Sarit Mall',
      icon: Icons.storefront_outlined,
    ),
    DemoAccount(
      email: 'owner@karunaholdings.co.ke',
      name: 'Karuna Holdings',
      role: 'Owner',
      detail: 'Sarit Mall and ABC Business Centre',
      icon: Icons.apartment_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Flexible(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                child: Text(
                  'OR EXPLORE A DEMO ACCOUNT',
                  textAlign: TextAlign.center,
                  style: textTheme.labelSmall?.copyWith(
                    color: kAuthOnDark.withValues(alpha: 0.55),
                    letterSpacing: 0.9,
                  ),
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        Gap.h16,
        for (final (index, account) in accounts.indexed) ...[
          if (index > 0) Gap.h12,
          _AccountTile(
            account: account,
            busy: pendingEmail == account.email,
            onPressed: enabled ? () => onSelected(account) : null,
          ),
        ],
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.onPressed,
    this.busy = false,
  });

  final DemoAccount account;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;

    final body = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kAuthOnDark.withValues(alpha: 0.1),
            borderRadius: AppRadius.small,
          ),
          child: Icon(
            account.icon,
            size: 20,
            color: kAuthOnDark.withValues(alpha: 0.9),
          ),
        ),
        Gap.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: kAuthOnDark,
                        fontWeight: AppTypography.semibold,
                      ),
                    ),
                  ),
                  Gap.w8,
                  _RolePill(label: account.role),
                ],
              ),
              Gap.h4,
              Text(
                account.detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kAuthOnDark.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
        ),
        Gap.w8,
        SizedBox.square(
          dimension: 18,
          child: busy
              ? CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kAuthOnDark.withValues(alpha: 0.7),
                )
              : Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: kAuthOnDark.withValues(alpha: 0.55),
                ),
        ),
      ],
    );

    return AppPressable(
      enabled: enabled,
      scale: 0.985,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: kAuthOnDark.withValues(alpha: 0.06),
          borderRadius: AppRadius.medium,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg,
                vertical: AppSpace.md,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadius.medium,
                border: Border.all(
                  color: kAuthOnDark.withValues(alpha: 0.18),
                ),
              ),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    // Brass for the owner, matching the stage that account opens on; the
    // tenant keeps the auth screen's own foreground.
    final colour = label == 'Owner' ? AppPalette.brass300 : kAuthOnDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colour.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colour,
          letterSpacing: 0.8,
          fontSize: 10,
        ),
      ),
    );
  }
}
