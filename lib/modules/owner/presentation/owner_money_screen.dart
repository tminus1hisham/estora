import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../components/app_glass.dart';
import '../../../components/app_refresh_indicator.dart';
import '../../../components/amount_text.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/collection_columns.dart';
import '../../../components/money_count_up.dart';
import '../../../components/state_views.dart';
import '../../../components/page_empty_state.dart';
import '../../../components/surface_atoms.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/owner.dart';
import '../../../domain/entities/property.dart';
import '../../../navigation/routes.dart';
import '../../properties/application/property_controller.dart';
import '../application/owner_controller.dart';
import 'owner_invoices_screen.dart';

/// Section 88. Money in.
///
/// What arrived over a window, what is still owed and for how long, and the
/// record of arrivals — drawn from the [OwnerReport] the contract serves:
/// every M-Pesa arrival and every invoice across the owner's properties. The
/// ageing bands are the point of the screen: an owner with KES 400,000
/// outstanding cares a great deal whether it is three days late or three
/// months.
///
/// Under the collected card sit four doors off the screen — paid and unpaid
/// invoices, then bank and M-Pesa arrivals — each carrying how many it opens
/// onto. They are the only way into the full lists; the page itself is the
/// summary, and repeats none of the rows.
///
/// An owner with more than one property is offered a strip under the title
/// to cut the report to one of them. An owner with one property is not: the
/// only answer it could give is the one already on screen.
class OwnerMoneyScreen extends ConsumerWidget {
  const OwnerMoneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(ownerReportProvider);
    final selected = ref.watch(reportPropertyProvider);
    final properties = ref.watch(propertyListProvider).value ?? const [];

    Future<void> refresh() async {
      await ref.refresh(ownerReportProvider.future).then<void>((_) {});
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Revenue'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Payouts',
            onPressed: () => context.pushNamed(Routes.ownerPayouts),
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
          Gap.w8,
        ],
        bottom: properties.length > 1
            ? PreferredSize(
                // Sized here, where there is a context to read the text scale
                // from; a strip that cannot grow with the type clips it.
                preferredSize: Size.fromHeight(
                  PropertyFilterBar.heightOf(context),
                ),
                child: PropertyFilterBar(
                  properties: properties,
                  selected: selected,
                  onSelected: (id) =>
                      ref.read(reportPropertyProvider.notifier).select(id),
                ),
              )
            : null,
      ),
      body: switch (report) {
        AsyncLoading() when !report.hasValue => const AppSkeletonList(
          header: true,
        ),
        // Even over a previous answer: that one may be another property's.
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: refresh,
        ),
        _ => _Money(
          report: report.requireValue,
          // Dimmed, not replaced, while the next property's answer is on its
          // way — the figures change rather than blank.
          stale: report.isLoading,
          onRefresh: refresh,
        ),
      },
    );
  }
}

/// The strip under the title that cuts the report to one property.
///
/// A tab row rather than a menu, so the property in view is always legible
/// without opening anything. It scrolls sideways — a portfolio of six is a
/// row wider than any phone — and the first tab is the whole portfolio,
/// which is where the screen opens.
class PropertyFilterBar extends StatelessWidget {
  const PropertyFilterBar({
    required this.properties,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<Property> properties;

  /// The property in view, or null for all of them.
  final String? selected;
  final ValueChanged<String?> onSelected;

  /// One row of pills, grown with the type up to the point past which a
  /// taller strip would be eating the report it filters.
  static double heightOf(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return 36 * scale.clamp(1.0, 1.7) + Gap.md + 1;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: heightOf(context),
      child: GlassSurface(
        blur: 18,
        border: false,
        borderRadius: BorderRadius.zero,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.maxReadingWidth,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                    child: Row(
                      children: [
                        _PeriodPill(
                          label: 'All properties',
                          selected: selected == null,
                          onTap: () => onSelected(null),
                        ),
                        for (final property in properties) ...[
                          Gap.w8,
                          _PeriodPill(
                            label: property.name,
                            selected: selected == property.id,
                            onTap: () => onSelected(property.id),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Hairline(),
          ],
        ),
      ),
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({
    required this.report,
    required this.stale,
    required this.onRefresh,
  });

  final OwnerReport report;
  final bool stale;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (report.isEmpty) {
      return PageEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        caption: 'Your money overview',
        title: 'No money activity yet',
        message: report.propertyId == null
            ? 'Once payments arrive, you can follow collections and outstanding balances here.'
            : 'Nothing has been invoiced or received for this property yet.',
        onRefresh: onRefresh,
      );
    }
    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: AnimatedOpacity(
        opacity: stale ? 0.55 : 1,
        duration: AppMotion.standard,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.maxReadingWidth,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The invoices and arrivals themselves live behind the tiles;
                // the page keeps only what summarises them, and both summaries
                // share one card. The card is as tall as its arrears face
                // needs, and the tiles take whatever the page has left, so
                // that a phone is filled without a scroll and a taller screen
                // is not a card over a strip of empty page.
                final abreast = _LedgerTabs.fitsAbreast(
                  context,
                  constraints.maxWidth - 2 * Gap.lg,
                );
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.lg,
                        Gap.sm,
                        Gap.lg,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: AppReveal(
                          index: 0,
                          child: _OverviewCard(report: report),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.lg,
                        Gap.md,
                        Gap.lg,
                        0,
                      ),
                      // The tiles are stretched to the foot of the page, and
                      // past it only when they must be — a small phone at a
                      // large text size — which is when the page scrolls.
                      sliver: SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          // Inside the fill rather than on the sliver, which
                          // would not count it and so overrun the page by it.
                          padding: const EdgeInsets.only(bottom: Gap.sm),
                          child: AppReveal(
                            index: 1,
                            child: _LedgerTabs(
                              report: report,
                              abreast: abreast,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The four doors off the screen, in two groups: the invoices, paid and
/// unpaid, then the arrivals, bank and M-Pesa. Each tile says how many rows
/// it opens onto, and tapping it opens them.
///
/// Every count is the report's own, so a tile and the collected figure are
/// counted from the same records.
class _LedgerTabs extends StatelessWidget {
  const _LedgerTabs({
    required this.report,
    required this.abreast,
  });

  final OwnerReport report;

  /// Whether each pair of tiles sits side by side or one above the other.
  final bool abreast;

  /// Whether two tiles fit side by side in [width]: the same rule an
  /// [EvenGrid] of them would apply, read here from the page's own width
  /// because the tiles are sized by the page rather than by their content.
  static bool fitsAbreast(BuildContext context, double width) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return width >= 2 * _tileMinWidth * scale + Gap.md;
  }

  /// The narrowest a tile may be before its pair stacks.
  static const double _tileMinWidth = 140;

  @override
  Widget build(BuildContext context) {
    final statuses = context.statusColors;
    final primary = Theme.of(context).colorScheme.primary;
    final unpaid = report.outstandingInvoices.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TabGroup(
          heading: 'Invoices',
          abreast: abreast,
          tiles: [
            _CountTile(
              label: 'Paid',
              noun: 'invoice',
              count: report.paidInvoices.length,
              icon: Icons.task_alt_rounded,
              color: statuses.positive,
              onTap: () => context.pushNamed(
                Routes.ownerInvoices,
                pathParameters: {'filter': OwnerInvoiceFilter.paid.slug},
              ),
            ),
            _CountTile(
              label: 'Unpaid',
              noun: 'invoice',
              count: unpaid,
              icon: Icons.pending_actions_rounded,
              // Unpaid is only a warning once there is something unpaid.
              color: statuses.resolve(
                unpaid == 0 ? StatusTone.neutral : StatusTone.warning,
              ),
              onTap: () => context.pushNamed(
                Routes.ownerInvoices,
                pathParameters: {'filter': OwnerInvoiceFilter.unpaid.slug},
              ),
            ),
          ],
        ),
        Gap.h16,
        _TabGroup(
          heading: 'Transactions',
          abreast: abreast,
          tiles: [
            _CountTile(
              label: 'Bank',
              noun: 'payment',
              count: report.banked.length,
              icon: Icons.account_balance_outlined,
              color: primary,
              onTap: () => context.pushNamed(Routes.bankPayments),
            ),
            _CountTile(
              label: 'M-Pesa',
              noun: 'payment',
              count: report.received.length,
              icon: Icons.phone_android_rounded,
              color: primary,
              onTap: () => context.pushNamed(Routes.mpesaTransactions),
            ),
          ],
        ),
      ],
    );
  }
}

/// A small-caps heading over a pair of tiles the same size as each other.
///
/// The group takes an equal share of the height the page gives the tiles,
/// and its tiles split that share, so the two groups are two equal bands
/// however tall the page is. Laid out by hand rather than with an [EvenGrid]
/// because a grid measures its tiles to size itself, and these are sized the
/// other way round.
class _TabGroup extends StatelessWidget {
  const _TabGroup({
    required this.heading,
    required this.tiles,
    required this.abreast,
  });

  final String heading;
  final List<Widget> tiles;

  /// Side by side down to a narrow phone; stacked once the text is large
  /// enough that two abreast would squeeze the figure.
  final bool abreast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spaced = [
      for (final (index, tile) in tiles.indexed) ...[
        if (index > 0) abreast ? Gap.w16 : Gap.h16,
        Expanded(child: tile),
      ],
    ];
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xs, 0, Gap.xs, Gap.xs),
            child: Text(
              heading.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: abreast
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: spaced,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: spaced,
                  ),
          ),
        ],
      ),
    );
  }
}

/// One door: what is behind it, how many, and a corner arrow that says it
/// opens — on one line, so a pair of them is a row and the four together are
/// two. The figure is set medium, like every other figure on the screen: a
/// count of twelve unpaid invoices is information, not an alarm.
class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.label,
    required this.noun,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;

  /// Singular; pluralised against [count].
  final String noun;

  /// Null while the count is not yet known.
  final int? count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final figure = count == null ? '—' : '$count';
    final detail = count == 1 ? noun : '${noun}s';

    return AppSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md),
      semanticLabel: '$label $detail, $figure',
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.small,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          Gap.w8,
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: AppTypography.medium,
              ),
            ),
          ),
          Gap.w8,
          Text(
            figure,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: AppTypography.medium,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Gap.w4,
          Icon(Icons.north_east_rounded, size: 14, color: muted),
        ],
      ),
    );
  }
}

/// The two faces of the overview card: what came in, and what is still owed.
enum _Face { collected, outstanding }

/// The screen's one figure card, with two faces the owner switches between:
/// what came in over a window, and what is still owed and for how long.
///
/// One card rather than two so that neither question needs a scroll to
/// answer — the owner opening the screen to check arrears should not have to
/// go looking for them under the collections chart. Which face is showing is
/// the card's own state; it survives a property switch, so an owner reading
/// arrears across the portfolio can cut to one property and still be reading
/// arrears.
///
/// The card is one height whichever face is showing, so switching faces
/// changes what is on the card and nothing under it. The outstanding face
/// sets that height — its bands are the part that grows — and the collected
/// face fills it, its chart taking whatever the figure leaves. When the
/// arrears are short, one band or none, the card is held at the least the
/// chart needs to say anything.
class _OverviewCard extends ConsumerStatefulWidget {
  const _OverviewCard({required this.report});

  final OwnerReport report;

  @override
  ConsumerState<_OverviewCard> createState() => _OverviewCardState();
}

class _OverviewCardState extends ConsumerState<_OverviewCard> {
  _Face _face = _Face.collected;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final collected = _face == _Face.collected;

    return AppSurfaceCard(
      gradient: AppGradients.brandHero,
      borderRadius: AppRadius.extraLarge,
      borderColor: AppPalette.brass300.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The switch is the card's title: its two words are the two things
          // the card can be showing, and a heading above it would say one of
          // them again.
          _FaceSwitch(
            face: _face,
            onChanged: (next) => setState(() => _face = next),
          ),
          Gap.h12,
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: _collectedLeast * scale),
            child: Stack(
              children: [
                // Always laid out, so the card is its height either way;
                // only painted and touchable while it is the face showing.
                _Ghost(
                  hidden: collected,
                  child: TickerMode(
                    enabled: !collected,
                    child: _OutstandingFace(report: widget.report),
                  ),
                ),
                if (collected)
                  Positioned.fill(child: _CollectedFace(report: widget.report)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The collected face at text scale one with its chart at the shortest it
  /// is worth drawing: the period strip, caption, figure and detail line, the
  /// chart's readout, plot and ticks, and the gaps and rule between them.
  /// Everything in it is text and pills that grow with the type, so it is
  /// scaled with the type.
  static const double _collectedLeast = 309;
}

/// [child] at its full size but, while [hidden], neither painted, touched
/// nor read — and, like an [Offstage] child, not there to a widget test's
/// finders. What [Offstage] cannot do is keep the child's size, and keeping
/// it is the point: the card holds the outstanding face's height under the
/// collected face without showing two faces at once.
class _Ghost extends SingleChildRenderObjectWidget {
  const _Ghost({required this.hidden, required super.child});

  final bool hidden;

  @override
  _RenderGhost createRenderObject(BuildContext context) =>
      _RenderGhost(hidden: hidden);

  @override
  void updateRenderObject(BuildContext context, _RenderGhost renderObject) {
    renderObject.hidden = hidden;
  }

  @override
  SingleChildRenderObjectElement createElement() => _GhostElement(this);
}

class _GhostElement extends SingleChildRenderObjectElement {
  _GhostElement(_Ghost super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    if (!(widget as _Ghost).hidden) super.debugVisitOnstageChildren(visitor);
  }
}

class _RenderGhost extends RenderProxyBox {
  _RenderGhost({required bool hidden}) : _hidden = hidden;

  bool get hidden => _hidden;
  bool _hidden;
  set hidden(bool value) {
    if (value == _hidden) return;
    _hidden = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!hidden) super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      !hidden && super.hitTest(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (!hidden) super.visitChildrenForSemantics(visitor);
  }
}

/// Two equal segments on the dark card. The selected one is brass, which is
/// the card's one accent and so the only thing on it that reads as "on".
class _FaceSwitch extends StatelessWidget {
  const _FaceSwitch({required this.face, required this.onChanged});

  final _Face face;
  final ValueChanged<_Face> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          for (final (label, value) in const [
            ('Collected', _Face.collected),
            ('Outstanding', _Face.outstanding),
          ])
            Expanded(
              child: Semantics(
                button: true,
                selected: face == value,
                label: label,
                excludeSemantics: true,
                child: Material(
                  color: face == value
                      ? AppPalette.brass300
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.md,
                        vertical: Gap.sm,
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: face == value
                              ? AppPalette.navy900
                              : Colors.white,
                          fontWeight: face == value
                              ? AppTypography.bold
                              : AppTypography.semibold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// What came in, over the window the owner picks.
///
/// The month is the default and the figure the screen is named for. The
/// wider windows are a question the owner asks — "what has the quarter
/// brought in?" — and each answer is cut from the same arrivals the report
/// holds, by the calendar arithmetic in [CollectionWindow.resolve]. Switching
/// tabs changes a figure rather than fetching one.
///
/// Fills the height it is given — the card's, set by the other face — with
/// the chart taking whatever the figure leaves. So it must be placed with a
/// bounded height.
class _CollectedFace extends ConsumerWidget {
  const _CollectedFace({required this.report});

  final OwnerReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final window = ref.watch(collectionWindowProvider);
    final figures = _Figures.of(report.sliceOver(window));

    return Column(
      key: const ValueKey(_Face.collected),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PeriodStrip(
          window: window,
          onSelected: (next) =>
              ref.read(collectionWindowProvider.notifier).select(next),
          onCustom: () => _pickRange(context, ref, window),
        ),
        Gap.h12,
        Text(
          figures.caption,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppPalette.brass300,
            letterSpacing: 1.6,
          ),
        ),
        Gap.h8,
        MoneyCountUp(
          figures.collected,
          scale: AmountScale.hero,
          color: Colors.white,
        ),
        Gap.h8,
        Text(
          figures.detail,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
        if (figures.points.isNotEmpty) ...[
          Gap.h12,
          Divider(color: Colors.white.withValues(alpha: 0.14), height: 1),
          Gap.h8,
          // The columns carry their own readout, which is the caption the
          // chart needs; a second one above it was a line spent twice.
          Expanded(
            child: CollectionColumns(
              key: ValueKey(figures.window),
              points: figures.points,
              height: null,
              ink: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickRange(
    BuildContext context,
    WidgetRef ref,
    CollectionWindow current,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 2, today.month, today.day),
      lastDate: today,
      initialDateRange: current.period == CollectionPeriod.custom
          ? DateTimeRange(start: current.from!, end: current.to!)
          : null,
      helpText: 'Collected between',
      saveText: 'Show',
    );
    if (picked == null) return;
    ref
        .read(collectionWindowProvider.notifier)
        .select(CollectionWindow.custom(from: picked.start, to: picked.end));
  }
}

/// What the card shows for one window.
class _Figures {
  const _Figures({
    required this.window,
    required this.caption,
    required this.collected,
    required this.detail,
    required this.points,
  });

  factory _Figures.of(ReportSlice slice) {
    final window = slice.window;
    final span = switch (window.period) {
      CollectionPeriod.month => 'this month',
      CollectionPeriod.threeMonths => 'in the last 3 months',
      CollectionPeriod.custom => 'between these dates',
    };
    final caption = switch (window.period) {
      CollectionPeriod.custom =>
        'COLLECTED ${_rangeLabel(window, year: true).toUpperCase()}',
      _ => 'COLLECTED ${span.toUpperCase()}',
    };
    final count = slice.paymentCount;
    final detail = slice.isEmpty
        ? 'Nothing came in $span.'
        : '$count M-Pesa payment${count == 1 ? '' : 's'} $span.';
    return _Figures(
      window: window,
      caption: caption,
      collected: slice.collected,
      detail: detail,
      // An empty window keeps its sentence and loses its chart: a row of
      // nothing is not a picture of anything.
      points: slice.isEmpty ? const [] : slice.points,
    );
  }

  final CollectionWindow window;
  final String caption;
  final Money collected;
  final String detail;
  final List<CollectionPoint> points;
}

/// `3 – 14 Sep`, or `14 Sep` when the span is one day.
String _rangeLabel(CollectionWindow window, {bool year = false}) {
  final from = window.from!;
  final to = window.to!;
  final format = year ? AppDate.short : DateFormat('d MMM').format;
  if (from == to) return format(from);
  // Both ends in the same month say the month once.
  if (from.year == to.year && from.month == to.month) {
    return '${from.day} – ${format(to)}';
  }
  return '${format(from)} – ${format(to)}';
}

/// The month, the three months to date, or two dates of the owner's choosing.
class _PeriodStrip extends StatelessWidget {
  const _PeriodStrip({
    required this.window,
    required this.onSelected,
    required this.onCustom,
  });

  final CollectionWindow window;
  final ValueChanged<CollectionWindow> onSelected;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final custom = window.period == CollectionPeriod.custom;

    // Wrapped rather than scrolled: a chosen range has to stay in view, and
    // a pill half-hidden past the card's edge reads as a mistake.
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        for (final (label, choice) in const [
          ('This month', CollectionWindow.month()),
          ('Last 3 months', CollectionWindow.threeMonths()),
        ])
          _PeriodPill(
            label: label,
            onDark: true,
            selected: window == choice,
            onTap: () => onSelected(choice),
          ),
        _PeriodPill(
          label: custom ? _rangeLabel(window) : 'Custom',
          onDark: true,
          selected: custom,
          icon: Icons.date_range_rounded,
          onTap: onCustom,
        ),
      ],
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.onDark = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = onDark
        ? (selected ? AppPalette.navy900 : Colors.white)
        : selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: onDark
            ? (selected
                  ? AppPalette.brass300
                  : Colors.white.withValues(alpha: 0.08))
            : selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerLowest.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: BorderSide(
            color: onDark
                ? Colors.white.withValues(alpha: selected ? 0 : 0.16)
                : selected
                ? Colors.transparent
                : scheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: foreground),
                  Gap.w4,
                ],
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: selected
                          ? AppTypography.bold
                          : AppTypography.semibold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What is still owed, banded by how long it has been owed.
///
/// The bands are the point: an owner with KES 400,000 outstanding cares a
/// great deal whether it is three days late or three months. Drawn on the
/// dark card in the same order the collected face draws its own figure —
/// caption, amount, one line of detail — so switching faces swaps a question,
/// not a layout.
class _OutstandingFace extends StatelessWidget {
  const _OutstandingFace({required this.report});

  final OwnerReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statuses = context.statusColors;
    final buckets = report
        .ageingAt(DateTime.now())
        .where((bucket) => !bucket.isEmpty)
        .toList(growable: false);
    final count = report.outstandingInvoices.length;

    return Column(
      key: const ValueKey(_Face.outstanding),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'TOTAL OUTSTANDING',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppPalette.brass300,
            letterSpacing: 1.6,
          ),
        ),
        Gap.h8,
        MoneyCountUp(
          report.outstanding,
          scale: AmountScale.hero,
          color: Colors.white,
        ),
        Gap.h8,
        Text(
          count == 0
              ? 'Nothing is owed to you.'
              : '$count unpaid invoice${count == 1 ? '' : 's'}, by age.',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
        if (buckets.isNotEmpty) ...[
          Gap.h12,
          ClipRRect(
            borderRadius: AppRadius.small,
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  for (final bucket in buckets)
                    if (bucket.amount.minorUnits > 0)
                      Expanded(
                        flex: bucket.amount.minorUnits,
                        child: ColoredBox(
                          color: statuses.resolve(_tone(bucket)),
                          child: const SizedBox.expand(),
                        ),
                      ),
                ],
              ),
            ),
          ),
          Gap.h12,
          Divider(color: Colors.white.withValues(alpha: 0.14), height: 1),
          for (final (index, bucket) in buckets.indexed) ...[
            if (index > 0)
              Divider(color: Colors.white.withValues(alpha: 0.14), height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statuses.resolve(_tone(bucket)),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Gap.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bucket.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: AppTypography.medium,
                          ),
                        ),
                        Text(
                          '${bucket.invoiceCount} invoice'
                          '${bucket.invoiceCount == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Gap.w12,
                  AmountText(
                    bucket.amount,
                    color: Colors.white,
                    align: TextAlign.end,
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  /// The bands darken as they age, which is the only thing the colours here
  /// are being asked to say.
  static StatusTone _tone(ArrearsBucket bucket) => switch (bucket.label) {
    'Not yet due' => StatusTone.neutral,
    '1–30 days' => StatusTone.warning,
    _ => StatusTone.danger,
  };
}
