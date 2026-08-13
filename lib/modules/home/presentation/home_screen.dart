import 'dart:ui' show lerpDouble;

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
/// A collapsing large title: the tenant's name starts as the biggest word on
/// the screen and shrinks into the pinned bar as the dashboard scrolls under
/// it. The greeting and the name are each rendered once and interpolated,
/// rather than crossfading a large copy with a small one — two copies of the
/// same name would be read out twice by a screen reader.
class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar({required this.unread, this.firstName});

  final int unread;
  final String? firstName;

  /// Matches `AppBarTheme.toolbarHeight`, and is passed explicitly because
  /// [SliverAppBar] defaults to [kToolbarHeight] instead of reading the theme.
  /// The collapse maths below needs the real number.
  static const double _toolbarHeight = 64;

  /// Enough room for the brand mark plus the slack an [AppBar] leaves before
  /// its title.
  static const double _leadingWidth = 64;

  /// Where the title parks once collapsed: clear of the mark by the same
  /// spacing the rest of the screen uses.
  static const double _collapsedInset = 72;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);

    final greetingStyle = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: AppTypography.medium,
    );
    final compactName = theme.textTheme.titleLarge!.copyWith(
      fontWeight: AppTypography.bold,
    );
    final largeName = theme.textTheme.headlineSmall!.copyWith(
      fontWeight: AppTypography.extraBold,
    );

    double lineOf(TextStyle style) =>
        textScaler.scale(style.fontSize!) * (style.height ?? 1.2);

    // The header grows with the platform's text size. A fixed height would
    // clip the greeting at accessibility scales, where the same two lines are
    // half again as tall.
    final greetingLine = lineOf(greetingStyle);
    final expandedHeight =
        _toolbarHeight +
        greetingLine +
        AppSpace.xxs +
        lineOf(largeName) +
        AppSpace.lg;

    // Centres the collapsed title against the brand mark beside it.
    final collapsedBottom = ((_toolbarHeight - lineOf(compactName)) / 2).clamp(
      0.0,
      AppSpace.xl,
    );
    final topPadding = MediaQuery.paddingOf(context).top;
    final name = firstName ?? 'Welcome';

    return SliverAppBar(
      pinned: true,
      toolbarHeight: _toolbarHeight,
      expandedHeight: expandedHeight,
      leadingWidth: _leadingWidth,
      leading: const Padding(
        padding: EdgeInsets.only(left: Gap.lg),
        child: AppBrandMark(size: 40),
      ),
      actions: [
        _NotificationBell(unread: unread),
        Gap.w8,
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final minExtent = _toolbarHeight + topPadding;
          final maxExtent = expandedHeight + topPadding;
          final span = maxExtent - minExtent;
          final t = span <= 0
              ? 0.0
              : ((constraints.maxHeight - minExtent) / span).clamp(0.0, 1.0);

          return Padding(
            padding: EdgeInsets.only(
              // Expanded, the title owns the full width; collapsed, it tucks
              // between the brand mark and the bell.
              left: lerpDouble(_collapsedInset, AppSpace.lg, t)!,
              right: lerpDouble(_collapsedInset, AppSpace.lg, t)!,
              bottom: lerpDouble(collapsedBottom, AppSpace.lg, t)!,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // heightFactor rather than a fixed slot: the greeting gives up
                // its line as it fades, so the name lands centred in the bar.
                ClipRect(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    heightFactor: t,
                    child: Opacity(
                      opacity: t,
                      child: Text(
                        HomeScreen.greeting(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: greetingStyle,
                      ),
                    ),
                  ),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle.lerp(compactName, largeName, t),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The notifications action, drawn as a tonal disc so it reads as a control
/// rather than as a loose glyph floating at the edge of the bar.
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: () => context.pushNamed(Routes.notifications),
      tooltip: 'Notifications',
      style: IconButton.styleFrom(
        backgroundColor: scheme.surfaceContainer,
        foregroundColor: scheme.onSurface,
        shape: const CircleBorder(),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
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
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
            sliver: SliverList.separated(
              itemCount: cards.length,
              separatorBuilder: (_, _) => Gap.h16,
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
///
/// Photograph-led: the unit's own image is the card, with the name, unit and
/// status sitting on it. The text is a sibling of [AppMedia] rather than its
/// overlay because that widget excludes its subtree from semantics — content
/// placed inside it would be invisible to a screen reader.
class _TenancyCard extends StatelessWidget {
  const _TenancyCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = summary.leaseStatus;
    const foreground = AppPalette.stone0;

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      onTap: () => context.pushNamed(
        Routes.leaseDetail,
        pathParameters: {'leaseId': summary.leaseId!},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AppMedia(
                source: summary.propertyImageUrl,
                aspectRatio: 16 / 9,
                semanticLabel: '${summary.propertyName ?? 'Current'} property',
                fallbackIcon: Icons.storefront_rounded,
                overlay: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppGradients.mediaScrim(strength: 0.78),
                  ),
                ),
              ),
              if (status != null)
                PositionedDirectional(
                  top: Gap.md,
                  end: Gap.md,
                  child: _MediaStatusChip(
                    label: status.label,
                    tone: status.tone,
                  ),
                ),
              PositionedDirectional(
                start: Gap.lg,
                end: Gap.lg,
                bottom: Gap.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      summary.propertyName ?? 'Your property',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: foreground,
                        fontWeight: AppTypography.bold,
                        shadows: const [
                          Shadow(color: AppPalette.ink950, blurRadius: 12),
                        ],
                      ),
                    ),
                    Text(
                      'Unit ${summary.unitNumber ?? '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: foreground.withValues(alpha: 0.86),
                        fontWeight: AppTypography.medium,
                        shadows: const [
                          Shadow(color: AppPalette.ink950, blurRadius: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.md, Gap.md),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
                Gap.w12,
                Expanded(
                  child: Text(
                    'View lease details',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: AppTypography.semibold,
                    ),
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
          ),
        ],
      ),
    );
  }
}

/// A status badge drawn over a photograph.
///
/// [StatusChip]'s tinted-on-surface treatment disappears against a scrim, so
/// this uses the dark palette's tones — the ones already tuned for a dark
/// ground — on smoked glass, in both themes.
class _MediaStatusChip extends StatelessWidget {
  const _MediaStatusChip({required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = StatusColors.dark.resolve(tone);

    return Semantics(
      label: 'Status: $label',
      container: true,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: AppPalette.ink950.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(color: color),
            Gap.w8,
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  height: 1.15,
                  fontWeight: AppTypography.bold,
                  letterSpacing: 0.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small tone-coloured dot that leads a status pill.
class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 6,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Shown to a tenant with no lease yet, pointing them at the browse tab.
class _NoTenancyCard extends StatelessWidget {
  const _NoTenancyCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SectionCard(
      children: [
        _IconTile(
          icon: Icons.storefront_rounded,
          color: scheme.primary,
          size: 48,
        ),
        Gap.h16,
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
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
///
/// The one surface on the screen that is allowed to be loud. It stays dark in
/// both themes, the way a bank card does, so the foreground is a fixed light
/// rather than `scheme.onSecondary` — which is itself dark once the app is in
/// dark mode.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});

  final DashboardSummary summary;

  static const Color _foreground = AppPalette.stone0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusLabel, statusTone) = _status();

    return AppSurfaceCard(
      gradient: AppGradients.brandHero,
      borderColor: Colors.transparent,
      // Zero here so the glows below can run off the edges; the content brings
      // its own padding.
      padding: EdgeInsets.zero,
      shadows: AppElevation.lifted(
        AppPalette.ink950,
        level: 3,
        brightness: theme.brightness,
      ),
      child: Stack(
        children: [
          // Two soft lights, clipped by the card, so the gradient reads as a
          // lit surface rather than a printed one. Radial fills rather than a
          // blur: same look, none of the cost of a real shadow layer.
          Positioned(
            top: -70,
            right: -50,
            child: _Glow(
              color: AppPalette.emerald500.withValues(alpha: 0.38),
              size: 210,
            ),
          ),
          Positioned(
            bottom: -110,
            left: -90,
            child: _Glow(
              color: AppPalette.brass500.withValues(alpha: 0.12),
              size: 240,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OUTSTANDING BALANCE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _foreground.withValues(alpha: 0.64),
                    letterSpacing: 1.1,
                  ),
                ),
                Gap.h8,
                MoneyText(
                  summary.outstandingBalance,
                  // A step above `emphasise`. This is the largest figure in the
                  // app and the one the screen is built around.
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: AppTypography.extraBold,
                  ),
                  color: summary.hasOverdue ? AppPalette.red300 : _foreground,
                ),
                Gap.h12,
                // The state of the balance, under the figure it describes, so
                // neither has to share a line at large text sizes.
                _HeroPill(label: statusLabel, tone: statusTone),
                if (summary.nextInvoiceAmount != null) ...[
                  Gap.h16,
                  _HeroPanel(
                    children: [
                      _DarkDetail(
                        label: 'Next invoice',
                        value: summary.nextInvoiceAmount!.format(),
                      ),
                      if (summary.nextPaymentDueDate != null) ...[
                        Divider(
                          height: Gap.xl,
                          color: _foreground.withValues(alpha: 0.14),
                        ),
                        _DarkDetail(
                          label: 'Payment due',
                          value: AppDate.full(summary.nextPaymentDueDate!),
                        ),
                      ],
                    ],
                  ),
                ],
                Gap.h16,
                if (summary.nextInvoice != null) ...[
                  FilledButton.icon(
                    onPressed: () => context.pushNamed(
                      Routes.payment,
                      pathParameters: {'invoiceId': summary.nextInvoice!.id},
                    ),
                    style: FilledButton.styleFrom(
                      // Fixed, like the card it sits on. The scheme's primary
                      // container is itself dark once the app is in dark mode,
                      // which would leave this button invisible against the
                      // gradient.
                      backgroundColor: AppPalette.emerald100,
                      foregroundColor: AppPalette.emerald950,
                      minimumSize: const Size.fromHeight(
                        AppLayout.controlHeight,
                      ),
                    ),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Pay now'),
                  ),
                  Gap.h8,
                  _HeroSecondaryAction(
                    label: 'View all invoices',
                    onPressed: () => context.goNamed(Routes.invoices),
                  ),
                ] else
                  _HeroSecondaryAction(
                    label: 'View all invoices',
                    filled: true,
                    onPressed: () => context.goNamed(Routes.invoices),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// What the figure above means, in three words or fewer.
  (String, StatusTone) _status() {
    if (summary.hasOverdue) return ('Overdue', StatusTone.danger);
    if (!summary.hasOutstandingBalance) {
      return ('Up to date', StatusTone.positive);
    }

    final due = summary.nextPaymentDueDate;
    if (due == null) return ('Awaiting payment', StatusTone.progress);

    final now = DateTime.now();
    final days = DateTime(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days < 0) return ('Past due', StatusTone.danger);
    if (days == 0) return ('Due today', StatusTone.warning);
    if (days == 1) return ('Due tomorrow', StatusTone.warning);
    // Neutral rather than `progress`: a date three weeks out is not news, and
    // the informational blue pulls against the emerald the hero is built from.
    return ('Due in $days days', StatusTone.neutral);
  }
}

/// A soft radial light used to give the balance hero its depth.
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// The status pill on the balance hero.
///
/// Tones come from the dark palette because the hero is dark in both themes.
class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = StatusColors.dark.resolve(tone);

    return Semantics(
      label: 'Status: $label',
      container: true,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: color.withValues(alpha: 0.34)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(color: color),
            Gap.w8,
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: AppTypography.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An inset panel on the balance hero, holding the detail rows.
///
/// A tinted well rather than a divider: it groups the invoice figures as
/// something separate from the balance without adding another hard line.
class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const foreground = AppPalette.stone0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.07),
        borderRadius: AppRadius.medium,
        border: Border.all(color: foreground.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// The quieter of the hero's two actions.
class _HeroSecondaryAction extends StatelessWidget {
  const _HeroSecondaryAction({
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final VoidCallback onPressed;

  /// Set when this is the only action on the card, and so has to carry it.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    const foreground = AppPalette.stone0;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: filled ? foreground.withValues(alpha: 0.12) : null,
        minimumSize: const Size.fromHeight(AppLayout.controlHeight),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.medium,
          side: BorderSide(
            color: foreground.withValues(alpha: filled ? 0.22 : 0),
          ),
        ),
      ),
      child: Text(label),
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
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: AppTypography.bold,
            ),
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
    final payments = summary.recentPayments.take(3).toList();

    return SectionCard(
      title: 'Recent payments',
      trailing: TextButton(
        onPressed: () => context.pushNamed(Routes.paymentHistory),
        child: const Text('See all'),
      ),
      children: [
        for (final (index, payment) in payments.indexed) ...[
          if (index > 0)
            Divider(
              height: Gap.lg,
              color: scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.xs),
            child: Row(
              children: [
                _IconTile(
                  icon: Icons.receipt_long_outlined,
                  color: scheme.primary,
                ),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.invoiceNumber ?? payment.paymentReference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                // Stacked rather than strung along the row: at large text
                // sizes an amount and a chip side by side leave the invoice
                // number nothing to live in.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MoneyText(payment.amount, bare: true),
                    Gap.h4,
                    StatusChip(
                      label: payment.status.label,
                      tone: payment.status.tone,
                      dense: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A rounded tonal square holding a leading icon.
///
/// Used wherever a row or card needs a leading glyph: a bare icon on a card
/// reads as unfinished next to the photography and the hero.
class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadius.small,
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, size: size * 0.5, color: color),
      ),
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
          _IconTile(icon: Icons.timer_outlined, color: scheme.primary),
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
      trailing: StatusChip(
        label: days == 0 ? 'Ends today' : '$days days left',
        tone: days <= 30 ? StatusTone.danger : StatusTone.warning,
        dense: true,
      ),
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
        // A wash rather than a flat tint, so the banner sits in the same
        // lighting as the hero below it.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.06),
          ],
        ),
        // Matches AppSurfaceCard's radius: these stack directly against the
        // cards below and a second radius in the same column shows.
        borderRadius: AppRadius.large,
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconTile(icon: icon, color: color),
              Gap.w12,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xs),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: AppTypography.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Gap.h12,
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          Gap.h16,
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              minimumSize: const Size.fromHeight(AppLayout.controlHeight),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
