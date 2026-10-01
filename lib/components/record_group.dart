import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_surface_card.dart';
import 'surface_atoms.dart';

/// How far a [RecordGroup]'s hairlines are inset from the left edge.
///
/// The rule starts where the row's text starts, not where the surface does, so
/// it separates the entries rather than boxing them. The default clears a
/// 40-unit leading tile: 16 of card padding, the tile, then its 12-unit gap.
const double kRecordRowInset = 68;

/// The same grouped surface as [RecordGroup], with rows built on demand.
class SliverRecordGroup extends StatelessWidget {
  const SliverRecordGroup({
    required this.itemCount,
    required this.itemBuilder,
    this.heading,
    this.trailing,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String? heading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SliverMainAxisGroup(
      slivers: [
        if (heading != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.xs, 0, Gap.xs, Gap.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      heading!.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[Gap.w8, trailing!],
                ],
              ),
            ),
          ),
        DecoratedSliver(
          decoration: BoxDecoration(
            borderRadius: AppRadius.large,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
            boxShadow: AppElevation.lifted(
              scheme.shadow,
              brightness: scheme.brightness,
            ),
          ),
          sliver: SliverList.builder(
            itemCount: itemCount,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(
                left: 1,
                right: 1,
                top: index == 0 ? 1 : 0,
                bottom: index == itemCount - 1 ? 1 : 0,
              ),
              child: Material(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? AppRadius.large.topLeft : Radius.zero,
                  bottom: index == itemCount - 1
                      ? AppRadius.large.bottomLeft
                      : Radius.zero,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (index > 0)
                      const Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: kRecordRowInset,
                        ),
                        child: Hairline(),
                      ),
                    itemBuilder(context, index),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A heading and the rows it covers, drawn as one surface.
///
/// The alternative — a card per entry — is what most of this app used to do,
/// and it reads as a stack of unrelated decisions rather than as a record. It
/// also costs a border, a shadow and a gap for every row, which on a list of
/// any length is most of the scrolling.
///
/// Use it for anything a tenant reads as a ledger: invoices in a month,
/// payments, bookings, the settings on a screen. Do not use it for entries
/// carrying photography — a unit someone is choosing between is a card,
/// because looking at it is the point.
class RecordGroup extends StatelessWidget {
  const RecordGroup({
    required this.children,
    this.heading,
    this.trailing,
    this.rowInset = kRecordRowInset,
    super.key,
  });

  /// The rows. Hairlines are drawn between them, never above the first or
  /// below the last — the surface's own edge already closes the group.
  final List<Widget> children;

  /// Set in small caps above the surface. Omit for a group whose meaning is
  /// obvious from the screen it is on.
  final String? heading;

  /// Sits opposite the heading. Usually a count or a "See all".
  final Widget? trailing;

  /// Overrides [kRecordRowInset] for rows with no leading tile, where a rule
  /// that starts 68 units in would look like a mistake.
  final double rowInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (heading != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xs, 0, Gap.xs, Gap.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    heading!.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                if (trailing != null) ...[Gap.w8, trailing!],
              ],
            ),
          ),
        AppSurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0)
                  Padding(
                    padding: EdgeInsetsDirectional.only(start: rowInset),
                    child: const Hairline(),
                  ),
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One entry in a [RecordGroup]: a tonal glyph, what it is, and what it cost.
///
/// The anatomy is fixed on purpose. Every ledger in this app answers the same
/// three questions in the same three places — what happened, what it was for,
/// how much — and a reader who has learned that on the invoice list should not
/// have to learn it again on the payment list.
///
/// Above roughly a 19-point body size the amount drops beneath the title
/// instead of sitting across from it. Squeezed side by side at that size the
/// title has nothing left to live in, and a truncated invoice number identifies
/// nothing.
class RecordRow extends StatelessWidget {
  const RecordRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.amount,
    this.caption,
    this.captionColor,
    this.footnote,
    this.onTap,
    super.key,
  });

  final IconData icon;

  /// Usually resolved from the entry's [StatusTone] via `context.statusColors`.
  final Color iconColor;

  final String title;

  /// What the entry covers, in one line. Ellipsised rather than wrapped — a
  /// row that grows to three lines stops being a row.
  final String? subtitle;

  /// The figure, normally an `AmountText`. Passed as a widget because only the
  /// caller knows whether the amount is due, paid or refunded, and that decides
  /// its colour.
  final Widget? amount;

  /// The line under the amount: when it falls due, or where it ended up.
  final String? caption;
  final Color? captionColor;

  /// An extra line across the full width, below everything else. For the rare
  /// entry that has to explain itself — a failure reason, most often.
  final Widget? footnote;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stacked = prefersStacked(context);

    final leading = ToneIconTile(icon: icon, color: iconColor, size: 40);
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: AppTypography.semibold,
          ),
        ),
        if (subtitle != null) ...[
          Gap.h4,
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    final trailingBlock = (amount == null && caption == null)
        ? null
        : Column(
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              ?amount,
              if (caption != null) ...[
                if (amount != null) Gap.h4,
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: captionColor ?? scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stacked)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leading,
                  Gap.w12,
                  Expanded(child: titleBlock),
                ],
              ),
              if (trailingBlock != null) ...[Gap.h12, trailingBlock],
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leading,
              Gap.w12,
              Expanded(flex: 5, child: titleBlock),
              if (trailingBlock != null) ...[
                Gap.w12,
                Expanded(flex: 4, child: trailingBlock),
              ],
            ],
          ),
        if (footnote != null) ...[Gap.h8, footnote!],
      ],
    );

    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.lg),
      child: body,
    );

    return onTap == null ? padded : InkWell(onTap: onTap, child: padded);
  }
}
