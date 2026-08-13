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
