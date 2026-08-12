import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              user?.firstName ?? 'Welcome',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
      ),
      body: switch (summaryAsync) {
        AsyncLoading() when !summaryAsync.hasValue => const LoadingView(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.read(dashboardControllerProvider.notifier).refresh(),
        ),
        _ => _HomeBody(summary: summaryAsync.requireValue),
      },
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(dashboardControllerProvider.notifier).refresh();
        ref.invalidate(unreadNotificationCountProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
        children: [
          // Things that need doing, first.
          if (summary.needsSignature) ...[
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
            Gap.h12,
          ],

          if (summary.hasActiveBooking) ...[
            _BookingCountdownCard(summary: summary),
            Gap.h12,
          ],

          if (summary.hasOverdue) ...[
            _ActionBanner(
              icon: Icons.warning_amber_rounded,
              tone: StatusTone.danger,
              title: 'You have an overdue balance',
              message: '${summary.overdueAmount!.format()} is past its due date.',
              actionLabel: 'Pay now',
              onAction: () => context.goNamed(Routes.invoices),
            ),
            Gap.h12,
          ],

          // Section 44: current property, unit and lease status.
          if (summary.hasTenancy)
            _TenancyCard(summary: summary)
          else
            const _NoTenancyCard(),

          Gap.h12,
          _BalanceCard(summary: summary),

          if (summary.recentPayments.isNotEmpty) ...[
            Gap.h12,
            _RecentPaymentsCard(summary: summary),
          ],

          if (summary.isLeaseExpiringSoon) ...[
            Gap.h12,
            _LeaseExpiryCard(summary: summary),
          ],
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
                Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
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
                                ?.copyWith(fontWeight: FontWeight.w700),
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
                    Text(
                      'View lease details',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
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
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
    final scheme = Theme.of(context).colorScheme;

    return SectionCard(
      title: 'Your balance',
      trailing: TextButton(
        onPressed: () => context.goNamed(Routes.invoices),
        child: const Text('All invoices'),
      ),
      children: [
        Text(
          'Outstanding',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        Gap.h4,
        MoneyText(
          summary.outstandingBalance,
          emphasise: true,
          color: summary.hasOverdue ? scheme.error : null,
        ),
        if (summary.nextInvoiceAmount != null) ...[
          Gap.h16,
          const Divider(),
          Gap.h8,
          DetailRow(
            label: 'Next invoice',
            valueWidget: MoneyText(summary.nextInvoiceAmount!),
          ),
          if (summary.nextPaymentDueDate != null)
            DetailRow(
              label: 'Next payment due',
              value: AppDate.full(summary.nextPaymentDueDate!),
            ),
        ],
        if (summary.nextInvoice != null) ...[
          Gap.h12,
          FilledButton.icon(
            onPressed: () => context.pushNamed(
              Routes.payment,
              pathParameters: {'invoiceId': summary.nextInvoice!.id},
            ),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Pay now'),
          ),
        ],
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
                        style: const TextStyle(fontWeight: FontWeight.w600),
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

    return Card(
      child: InkWell(
        onTap: () => context.pushNamed(
          Routes.bookingStatus,
          pathParameters: {'bookingId': summary.activeBookingId!},
        ),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
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
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
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
        ),
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
        DetailRow(
          label: 'Ends on',
          value: AppDate.full(summary.leaseEndDate!),
        ),
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
        borderRadius: BorderRadius.circular(16),
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
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
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
