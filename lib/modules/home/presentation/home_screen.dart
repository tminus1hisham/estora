import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_brand_mark.dart';
import '../../../components/app_media.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/countdown_timer.dart';
import '../../../components/money_text.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/dashboard_summary.dart';
import '../../../navigation/routes.dart';
import '../../auth/application/auth_controller.dart';
import '../../notifications/application/notification_controller.dart';
import '../application/dashboard_controller.dart';

/// Section 44's tenant home screen.
///
/// Order follows the spec's list: current property and unit, lease status,
/// balance, next invoice and due date, recent payments, lease expiry,
/// notifications. Anything needing the tenant's attention — an unsigned lease,
/// a booking counting down, an overdue balance — is promoted above that so it
/// cannot be missed.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardControllerProvider);
    final user = ref.watch(authControllerProvider).user;
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return Scaffold(
      body: switch (summaryAsync) {
        // A dashboard of cards deserves a skeleton of cards. The spinner this
        // replaced said nothing about what was coming and let the screen jump
        // when it arrived.
        AsyncLoading() when !summaryAsync.hasValue => CustomScrollView(
          slivers: [
            _HomeAppBar(unread: unread, firstName: user?.firstName),
            const SliverToBoxAdapter(
              child: AppSkeletonList(itemCount: 3, header: true),
            ),
          ],
        ),
        AsyncError(:final error) => CustomScrollView(
          slivers: [
            _HomeAppBar(unread: unread, firstName: user?.firstName),
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(
                failure: error is Failure
                    ? error
                    : UnknownFailure(error.toString()),
                onRetry: () =>
                    ref.read(dashboardControllerProvider.notifier).refresh(),
              ),
            ),
          ],
        ),
        _ => _HomeBody(
          summary: summaryAsync.requireValue,
          unread: unread,
          firstName: user?.firstName,
        ),
      },
    );
  }

  static String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

/// The home header.
///
/// A sliver so that content scrolls under it and picks up the theme's
/// scrolled-under elevation, which gives the bar an edge only once there is
/// something behind it to separate from.
class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar({required this.unread, this.firstName});

  final int unread;
  final String? firstName;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      leadingWidth: 64,
      leading: const Padding(
        padding: EdgeInsets.only(left: Gap.lg),
        child: AppBrandMark(size: 40),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            HomeScreen.greeting(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            firstName ?? 'Welcome',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: AppTypography.bold),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => context.pushNamed(Routes.notifications),
          tooltip: 'Notifications',
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
        Gap.w8,
      ],
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({
    required this.summary,
    required this.unread,
    this.firstName,
  });

  final DashboardSummary summary;
  final int unread;
  final String? firstName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Built as a list so each card can be given its place in the order of
    // arrival without threading an index through by hand.
    final cards = <Widget>[
      // Things that need doing, first.
      if (summary.needsSignature)
        _ActionBanner(
          icon: Icons.draw_outlined,
          tone: StatusTone.progress,
          title: 'Your lease is ready to sign',
          message: 'Review the agreement and sign to activate your lease.',
          actionLabel: 'Review and sign',
          onAction: () => context.pushNamed(
            Routes.signAgreement,
            pathParameters: {'leaseId': summary.pendingSignatureLeaseId!},
          ),
        ),

      if (summary.hasActiveBooking) _BookingCountdownCard(summary: summary),

      if (summary.hasOverdue)
        _ActionBanner(
          icon: Icons.warning_amber_rounded,
          tone: StatusTone.danger,
          title: 'You have an overdue balance',
          message: '${summary.overdueAmount!.format()} is past its due date.',
          actionLabel: 'Pay now',
          onAction: () => context.goNamed(Routes.invoices),
        ),

      // Section 44: current property, unit and lease status.
      //
      // The order below is the spec's, not a design choice. The balance is
      // given its weight by how it is drawn rather than by moving it up.
      if (summary.hasTenancy)
        _TenancyCard(summary: summary)
      else
        const _NoTenancyCard(),

      _BalanceCard(summary: summary),

      if (summary.recentPayments.isNotEmpty)
        _RecentPaymentsCard(summary: summary),

      if (summary.isLeaseExpiringSoon) _LeaseExpiryCard(summary: summary),
    ];

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(dashboardControllerProvider.notifier).refresh();
        ref.invalidate(unreadNotificationCountProvider);
      },
      child: CustomScrollView(
        slivers: [
          _HomeAppBar(unread: unread, firstName: firstName),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
            sliver: SliverList.separated(
              itemCount: cards.length,
              separatorBuilder: (_, _) => Gap.h12,
              itemBuilder: (context, index) =>
                  AppReveal(index: index, child: cards[index]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Current property, unit and lease status.
class _TenancyCard extends StatelessWidget {
  const _TenancyCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = summary.leaseStatus;

    return SectionCard(
      padding: EdgeInsets.zero,
      children: [
        InkWell(
          onTap: () => context.pushNamed(
            Routes.leaseDetail,
            pathParameters: {'leaseId': summary.leaseId!},
          ),
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppMedia(
                  source: summary.propertyImageUrl,
                  aspectRatio: 16 / 7,
                  borderRadius: AppRadius.medium,
                  semanticLabel:
                      '${summary.propertyName ?? 'Current'} property',
                  fallbackIcon: Icons.storefront_rounded,
                  overlay: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppGradients.mediaScrim(strength: 0.45),
                    ),
                  ),
                ),
                Gap.h16,
                Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: AppRadius.small,
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    Gap.w12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.propertyName ?? 'Your property',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: AppTypography.bold),
                          ),
                          Text(
                            'Unit ${summary.unitNumber ?? '—'}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (status != null)
                      StatusChip(label: status.label, tone: status.tone),
                  ],
                ),
                Gap.h12,
                Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    Gap.w8,
                    Expanded(
                      child: Text(
                        'View lease details',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Gap.w8,
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown to a tenant with no lease yet, pointing them at the browse tab.
class _NoTenancyCard extends StatelessWidget {
  const _NoTenancyCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      children: [
        Text(
          'Find your space',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: AppTypography.bold),
        ),
        Gap.h8,
        Text(
          'Browse available retail units, kiosks and office suites, and book '
          'the one you want.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Gap.h16,
        FilledButton.tonalIcon(
          onPressed: () => context.goNamed(Routes.browse),
          icon: const Icon(Icons.search_rounded),
          label: const Text('Browse available units'),
        ),
      ],
    );
  }
}

/// Outstanding balance, next invoice and next due date.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    // The hero stays dark in both themes, the way a bank card does, so the
    // foreground is a fixed light rather than scheme.onSecondary — which is
    // itself dark once the app is in dark mode.
    const foreground = AppPalette.stone0;

    return AppSurfaceCard(
      gradient: AppGradients.brandHero,
      borderColor: Colors.transparent,
      padding: const EdgeInsets.all(Gap.xl),
      shadows: AppElevation.lifted(
        AppPalette.ink950,
        level: 2,
        brightness: Theme.of(context).brightness,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'OUTSTANDING BALANCE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground.withValues(alpha: 0.64),
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.goNamed(Routes.invoices),
                style: TextButton.styleFrom(foregroundColor: foreground),
                child: const Text('All invoices'),
              ),
            ],
          ),
          Gap.h8,
          MoneyText(
            summary.outstandingBalance,
            // A step above `emphasise`. This is the largest figure in the app
            // and the one the screen is built around.
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: AppTypography.extraBold,
            ),
            color: summary.hasOverdue ? AppPalette.red300 : foreground,
          ),
          if (summary.nextInvoiceAmount != null) ...[
            Gap.h16,
            Divider(color: foreground.withValues(alpha: 0.18)),
            Gap.h12,
            _DarkDetail(
              label: 'Next invoice',
              value: summary.nextInvoiceAmount!.format(),
            ),
            if (summary.nextPaymentDueDate != null) ...[
              Gap.h8,
              _DarkDetail(
                label: 'Payment due',
                value: AppDate.full(summary.nextPaymentDueDate!),
              ),
            ],
          ],
          if (summary.nextInvoice != null) ...[
            Gap.h16,
            FilledButton.icon(
              onPressed: () => context.pushNamed(
                Routes.payment,
                pathParameters: {'invoiceId': summary.nextInvoice!.id},
              ),
              style: FilledButton.styleFrom(
                // Fixed, like the card it sits on. The scheme's primary
                // container is itself dark once the app is in dark mode, which
                // would leave this button invisible against the gradient.
                backgroundColor: AppPalette.emerald100,
                foregroundColor: AppPalette.emerald950,
                minimumSize: const Size.fromHeight(AppLayout.controlHeight),
              ),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Pay now'),
            ),
          ],
        ],
      ),
    );
  }
}

/// A label/value row on the balance hero, which is dark in both themes.
class _DarkDetail extends StatelessWidget {
  const _DarkDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    const foreground = AppPalette.stone0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foreground.withValues(alpha: 0.64),
            ),
          ),
        ),
        Gap.w12,
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ),
      ],
    );
  }
}

class _RecentPaymentsCard extends StatelessWidget {
  const _RecentPaymentsCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SectionCard(
      title: 'Recent payments',
      trailing: TextButton(
        onPressed: () => context.pushNamed(Routes.paymentHistory),
        child: const Text('See all'),
      ),
      children: [
        for (final payment in summary.recentPayments.take(3))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.invoiceNumber ?? payment.paymentReference,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: AppTypography.semibold,
                        ),
                      ),
                      Text(
                        payment.paidAt == null
                            ? payment.status.label
                            : AppDate.short(payment.paidAt!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Gap.w8,
                MoneyText(payment.amount, bare: true),
                Gap.w8,
                StatusChip(
                  label: payment.status.label,
                  tone: payment.status.tone,
                  dense: true,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Section 23's countdown, surfaced on the home screen so a hold cannot lapse
/// unnoticed.
class _BookingCountdownCard extends ConsumerWidget {
  const _BookingCountdownCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final expiresAt = summary.activeBookingExpiresAt;

    // AppSurfaceCard rather than a bare Card: every other card on this screen
    // is one, and the difference in border and radius showed.
    return AppSurfaceCard(
      onTap: () => context.pushNamed(
        Routes.bookingStatus,
        pathParameters: {'bookingId': summary.activeBookingId!},
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: scheme.primary),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Booking ${summary.activeBookingReference ?? ''}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                if (expiresAt != null)
                  CountdownTimer(
                    expiresAt: expiresAt,
                    // Reaching zero here does not expire anything — the
                    // server decides that (section 23). This just refetches
                    // so the screen shows whatever it decided.
                    onExpired: () => ref
                        .read(dashboardControllerProvider.notifier)
                        .refresh(),
                    builder: (context, remaining) => Text(
                      remaining == Duration.zero
                          ? 'This hold has lapsed'
                          : 'Expires in ${AppDate.humanDuration(remaining)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Text(
                    'Complete your booking to hold this unit',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _LeaseExpiryCard extends StatelessWidget {
  const _LeaseExpiryCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final days = summary.daysUntilLeaseExpiry ?? 0;

    return SectionCard(
      title: 'Lease expiry',
      children: [
        DetailRow(label: 'Ends on', value: AppDate.full(summary.leaseEndDate!)),
        DetailRow(
          label: 'Time remaining',
          value: days == 0 ? 'Today' : '$days days',
        ),
        Gap.h8,
        Text(
          'Your property manager will be in touch about renewal. Renewing '
          'creates a new lease, so this one stays on your record.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A prominent, coloured call to action for something that needs doing.
class _ActionBanner extends StatelessWidget {
  const _ActionBanner({
    required this.icon,
    required this.tone,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final StatusTone tone;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final color = context.statusColors.resolve(tone);

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.medium,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              Gap.w8,
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: AppTypography.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          Gap.h8,
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          Gap.h12,
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              minimumSize: const Size.fromHeight(44),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
