import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_reveal.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../domain/entities/dashboard_summary.dart';
import '../../../navigation/routes.dart';
import '../../auth/application/auth_controller.dart';
import '../../notifications/application/notification_controller.dart';
import '../application/dashboard_controller.dart';
import 'available_home.dart';
import 'widgets/attention_banner.dart';
import 'widgets/balance_card.dart';
import 'widgets/home_cards.dart';
import 'widgets/home_hero.dart';
import 'widgets/home_skeleton.dart';
import 'widgets/home_top_bar.dart';
import 'widgets/insight_tiles.dart';
import 'widgets/quick_actions.dart';

/// Section 44's tenant home screen.
///
/// Built as three movements rather than as a list of cards. The header is the
/// tenant's own building with their name on it; the balance card overlaps its
/// foot and carries the figure the app exists to show; everything below is
/// what to do about it, in the order it matters — what needs doing, then when
/// it falls due, then where to go, then what has already been paid.
///
/// The screen owns its scrolling because of that overlap. A pinned
/// [SliverAppBar] paints above whatever scrolls under it, which would bury the
/// card, so the bar floats in a [Stack] over the scroll view and takes its
/// background from how far the header has travelled.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  /// Raw pixels scrolled, driving the header's parallax.
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);

  /// The same travel expressed 0–1, driving the top bar and the fade of the
  /// greeting. Two notifiers rather than one because the parallax keeps going
  /// after the bar has finished arriving.
  final ValueNotifier<double> _collapse = ValueNotifier<double>(0);

  /// How far the header travels before the top bar has fully taken over.
  static const double _collapseDistance = 130;

  /// How far the balance card rides up onto the header.
  ///
  /// [Transform.translate] leaves the card's layout box where it was, so this
  /// is also the gap it opens underneath itself — which is why the list below
  /// starts with no padding of its own.
  static const double _cardOverlap = 28;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _scrollOffset.dispose();
    _collapse.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // Clamped at zero so an overscroll bounce does not push the header the
    // wrong way; the image is oversized downwards only.
    final offset = _scrollController.offset.clamp(0.0, double.infinity);
    _scrollOffset.value = offset;
    _collapse.value = (offset / _collapseDistance).clamp(0.0, 1.0);
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(dashboardControllerProvider.notifier).refresh(),
      ref.refresh(unreadNotificationCountProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardControllerProvider);
    if (summaryAsync.error is UnsupportedFeatureFailure) {
      return Scaffold(body: const AvailableHome(manager: false));
    }
    final user = ref.watch(authControllerProvider).user;
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    final topInset = MediaQuery.paddingOf(context).top;

    final slivers = switch (summaryAsync) {
      AsyncLoading() when !summaryAsync.hasValue => const [
        SliverToBoxAdapter(child: HomeSkeleton()),
      ],
      AsyncError(:final error) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.only(top: topInset + HomeTopBar.height),
            child: ErrorView(
              failure: error is Failure
                  ? error
                  : UnknownFailure(error.toString()),
              onRetry: () =>
                  ref.read(dashboardControllerProvider.notifier).refresh(),
            ),
          ),
        ),
      ],
      _ => _slivers(summaryAsync.requireValue, user?.firstName),
    };

    return Scaffold(
      body: Stack(
        children: [
          AppRefreshIndicator(
            onRefresh: _refresh,
            // Drops the spinner clear of the floating bar.
            edgeOffset: topInset + HomeTopBar.height,
            child: CustomScrollView(
              controller: _scrollController,
              // The summary is short enough on a tablet to leave the page
              // unscrollable, and an unscrollable page cannot be pulled to
              // refresh.
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: slivers,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: HomeTopBar(collapse: _collapse, unread: unread),
          ),
        ],
      ),
    );
  }

  List<Widget> _slivers(DashboardSummary summary, String? firstName) {
    final cards = <Widget>[
      // Things that need doing, first.
      if (summary.needsSignature)
        AttentionBanner(
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

      if (summary.hasActiveBooking) BookingCountdownCard(summary: summary),

      // An overdue balance has no banner here. The balance card turns red,
      // says Overdue, names the late portion and offers to pay it — a banner
      // underneath saying the same three things again was the loudest thing
      // on the old screen and the least informative.

      // Only once the end is genuinely close. Between one and three months out
      // the lease tile already carries the countdown, and a banner every day
      // for a quarter is how a tenant learns to ignore banners.
      if (_leaseEndsWithinMonth(summary))
        AttentionBanner(
          icon: Icons.event_busy_rounded,
          tone: StatusTone.warning,
          title: summary.daysUntilLeaseExpiry == 0
              ? 'Your lease ends today'
              : 'Your lease ends in ${summary.daysUntilLeaseExpiry} days',
          message:
              'Your property manager will be in touch about renewal. Renewing '
              'creates a new lease, so this one stays on your record.',
          actionLabel: 'View lease',
          onAction: () => context.pushNamed(
            Routes.currentProperty,
            pathParameters: {'leaseId': summary.leaseId!},
          ),
        ),

      if (!summary.hasTenancy) const NoTenancyCard(),

      if (summary.hasTenancy || summary.nextPaymentDueDate != null)
        InsightTiles(summary: summary),

      QuickActions(summary: summary),

      if (summary.recentPayments.isNotEmpty)
        RecentPaymentsCard(summary: summary),
    ];

    // One sliver, built in full, rather than a lazy list. A lazy list only
    // mounts a card when it scrolls into view, which is when that card's
    // entrance would start — so scrolling down would meet a blank space that
    // fades in half a second later. The body is half a dozen cards; building
    // all of them costs nothing and means the arrival is over before anyone
    // has had time to scroll.
    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HomeHero(
              summary: summary,
              firstName: firstName,
              scrollOffset: _scrollOffset,
              collapse: _collapse,
            ),
            Transform.translate(
              offset: const Offset(0, -_cardOverlap),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                child: BalanceCard(summary: summary),
              ),
            ),
            Padding(
              // No top padding: the overlapped balance card left exactly one
              // gap's worth of its own layout box behind.
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, card) in cards.indexed) ...[
                    if (index > 0) Gap.h16,
                    AppReveal(
                      // Behind the header and the balance card, which have
                      // their own arrival, so the page assembles top to bottom
                      // rather than all at once.
                      delay:
                          AppMotion.stagger(index) +
                          const Duration(milliseconds: 320),
                      child: card,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  static bool _leaseEndsWithinMonth(DashboardSummary summary) {
    final days = summary.daysUntilLeaseExpiry;
    return summary.hasTenancy && days != null && days >= 0 && days <= 30;
  }
}
