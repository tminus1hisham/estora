import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/status_palette.dart';

/// The foreground used on the app's dark brand surfaces.
///
/// The hero cards on home, invoices and leases stay dark in both themes, the
/// way a bank card does, so their text cannot come from the colour scheme —
/// `onSurface` is itself light once the app is in dark mode and would vanish.
const Color kOnDark = AppPalette.stone0;

/// A rounded tonal square holding a leading icon.
///
/// Used wherever a row or a card needs a leading glyph. A bare icon reads as
/// unfinished next to the photography and the hero surfaces.
class ToneIconTile extends StatelessWidget {
  const ToneIconTile({
    required this.icon,
    required this.color,
    this.size = 40,
    this.onDark = false,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;

  /// Set when the tile sits on a brand surface, where a 12% tint of the icon's
  /// own colour disappears into the navy behind it.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: onDark ? 0.18 : 0.12),
          borderRadius: AppRadius.small,
          border: Border.all(
            color: color.withValues(alpha: onDark ? 0.3 : 0.18),
          ),
        ),
        child: Icon(icon, size: size * 0.5, color: color),
      ),
    );
  }
}

/// A soft radial light, used to give the dark surfaces their depth.
///
/// A radial fill rather than a real blur: the same look, none of the cost of
/// an extra composited layer on a card that is already carrying a gradient.
class SoftGlow extends StatelessWidget {
  const SoftGlow({required this.color, required this.size, super.key});

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

/// The small tone-coloured dot that leads a status pill or a caption.
class ToneDot extends StatelessWidget {
  const ToneDot({required this.color, this.size = 6, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// A status pill for a dark brand surface.
///
/// Tones come from the dark palette because the surfaces this sits on are dark
/// in both themes; [StatusChip]'s tinted-on-surface treatment would be
/// invisible here. On an ordinary themed surface, use [StatusChip] instead.
class TonePill extends StatelessWidget {
  const TonePill({required this.label, required this.tone, super.key});

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
            ToneDot(color: color),
            Gap.w8,
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: AppTypography.semibold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A one-pixel rule.
///
/// A [Divider] carries theme spacing and a thickness meant for lists; inside a
/// card — and especially on a dark surface, where the theme's outline is the
/// wrong colour entirely — what is wanted is a hairline and nothing else.
class Hairline extends StatelessWidget {
  const Hairline({this.onDark = false, this.alpha, super.key});

  final bool onDark;

  /// Overrides the default opacity, for a rule that should sit further back.
  final double? alpha;

  @override
  Widget build(BuildContext context) {
    final color = onDark
        ? kOnDark.withValues(alpha: alpha ?? 0.14)
        : Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: alpha ?? 0.7);

    return SizedBox(height: 1, child: ColoredBox(color: color));
  }
}

/// A hairline bar that fills once, as its surface arrives.
///
/// Used for anything that is genuinely a proportion — how much of a lease term
/// has run, how far through a billing cycle a due date is. Never for a count.
class LinearMeter extends StatelessWidget {
  const LinearMeter({
    required this.value,
    required this.color,
    this.trackColor,
    this.height = 5,
    super.key,
  });

  /// 0–1. Values outside the range are clamped rather than rejected, because
  /// the dates behind them come from a server and a stale one should not
  /// throw on a screen the tenant is reading.
  final double value;
  final Color color;
  final Color? trackColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = value.clamp(0.0, 1.0);
    final settled = MediaQuery.disableAnimationsOf(context);

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          height: height,
          // Expand rather than loose: an empty [DecoratedBox] has no intrinsic
          // size, so under loose constraints the fill would measure zero high
          // and the bar would never appear.
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color:
                    trackColor ?? scheme.outlineVariant.withValues(alpha: 0.6),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: settled ? target : 0, end: target),
                duration: settled
                    ? Duration.zero
                    : const Duration(milliseconds: 760),
                curve: AppMotion.emphasized,
                builder: (context, t, _) => FractionallySizedBox(
                  widthFactor: t,
                  alignment: AlignmentDirectional.centerStart,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.55), color],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A label above a value.
///
/// The quiet alternative to a label/value row: two of these side by side read
/// as a statement, where two rows read as small print.
class StatPair extends StatelessWidget {
  const StatPair({
    required this.label,
    this.value,
    this.valueWidget,
    this.align = CrossAxisAlignment.start,
    this.onDark = false,
    super.key,
  }) : assert(
         value != null || valueWidget != null,
         'StatPair needs either a value or a valueWidget',
       );

  final String label;
  final String? value;
  final Widget? valueWidget;
  final CrossAxisAlignment align;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: align == CrossAxisAlignment.end
              ? TextAlign.end
              : TextAlign.start,
          style: theme.textTheme.bodySmall?.copyWith(
            color: onDark
                ? kOnDark.withValues(alpha: 0.62)
                : scheme.onSurfaceVariant,
          ),
        ),
        Gap.h4,
        valueWidget ??
            Text(
              value!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: align == CrossAxisAlignment.end
                  ? TextAlign.end
                  : TextAlign.start,
              style: theme.textTheme.titleSmall?.copyWith(
                color: onDark ? kOnDark : scheme.onSurface,
                fontWeight: AppTypography.semibold,
              ),
            ),
      ],
    );
  }
}

/// A heading with a status badge beside it.
///
/// The badge drops onto its own line once the platform's text size means the
/// two no longer fit across — a status that has been squeezed to three
/// ellipsised characters tells a tenant nothing.
class BadgedHeader extends StatelessWidget {
  const BadgedHeader({required this.child, required this.badge, super.key});

  final Widget child;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    if (prefersStacked(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [child, Gap.h12, badge],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: child),
        Gap.w12,
        Flexible(child: badge),
      ],
    );
  }
}

/// One half of a [StatRow].
///
/// Carries a builder rather than a widget for the value because whether the
/// value is aligned to the start or the end depends on whether the pair ended
/// up side by side, and only [StatRow] knows that.
class Stat {
  const Stat(this.label, {this.value, this.builder})
    : assert(
        value != null || builder != null,
        'Stat needs either a value or a builder',
      );

  final String label;
  final String? value;
  final Widget Function(BuildContext context, TextAlign align)? builder;
}

/// Two stats side by side: one starting at the left edge, one ending at the
/// right, with the space between them doing the separating.
///
/// Falls back to one column once the platform's text size means two would
/// truncate. Nothing here is worth reading half of.
class StatRow extends StatelessWidget {
  const StatRow({
    required this.left,
    required this.right,
    this.onDark = false,
    super.key,
  });

  final Stat left;
  final Stat right;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    if (prefersStacked(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pair(context, left, TextAlign.start),
          Gap.h12,
          _pair(context, right, TextAlign.start),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _pair(context, left, TextAlign.start)),
        Gap.w12,
        Expanded(child: _pair(context, right, TextAlign.end)),
      ],
    );
  }

  Widget _pair(BuildContext context, Stat stat, TextAlign align) => StatPair(
    label: stat.label,
    value: stat.value,
    valueWidget: stat.builder?.call(context, align),
    align: align == TextAlign.end
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    onDark: onDark,
  );
}

/// How much of the surface an [OnDarkAction] is entitled to.
enum OnDarkActionStyle {
  /// The one action the card was built to offer.
  primary,

  /// A second action of equal standing.
  tonal,

  /// An alternative, present but not urged.
  quiet,
}

/// An action on a dark brand surface.
///
/// The colour scheme is no help here: `primary` is itself a pale sky blue once
/// the app is in dark mode, and a filled button in it would vanish into the
/// navy behind it. Both palettes are fixed, like the card they sit on.
class OnDarkAction extends StatelessWidget {
  const OnDarkAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = OnDarkActionStyle.quiet,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final OnDarkActionStyle style;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);

    if (style == OnDarkActionStyle.primary) {
      final buttonStyle = FilledButton.styleFrom(
        backgroundColor: AppPalette.azure100,
        foregroundColor: AppPalette.azure950,
        minimumSize: const Size.fromHeight(AppLayout.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      );

      return icon == null
          ? FilledButton(onPressed: onPressed, style: buttonStyle, child: text)
          : FilledButton.icon(
              onPressed: onPressed,
              style: buttonStyle,
              icon: Icon(icon, size: 20),
              label: text,
            );
    }

    final tonal = style == OnDarkActionStyle.tonal;
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: kOnDark,
      backgroundColor: kOnDark.withValues(alpha: tonal ? 0.12 : 0.08),
      minimumSize: const Size.fromHeight(AppLayout.controlHeight),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.small,
        side: BorderSide(color: kOnDark.withValues(alpha: 0.2)),
      ),
    );

    return icon == null
        ? TextButton(onPressed: onPressed, style: buttonStyle, child: text)
        : TextButton.icon(
            onPressed: onPressed,
            style: buttonStyle,
            icon: Icon(icon, size: 20),
            label: text,
          );
  }
}

/// An action on a themed surface — the light sibling of [OnDarkAction].
///
/// On glass a secondary action is a pane of the same material rather than an
/// outlined control: a hairline box over a whisper of fill, so the actions read
/// as part of the card instead of as buttons dropped onto it.
class SurfaceAction extends StatelessWidget {
  const SurfaceAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  /// The one action the card was built to offer. Everything else is a pane.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A label that has been ellipsised still says which button it is; one that
    // has overflowed says nothing and paints a stripe over the card.
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);

    if (primary) {
      final buttonStyle = FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppLayout.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      );

      return icon == null
          ? FilledButton(onPressed: onPressed, style: buttonStyle, child: text)
          : FilledButton.icon(
              onPressed: onPressed,
              style: buttonStyle,
              icon: Icon(icon, size: 20),
              label: text,
            );
    }

    final buttonStyle = TextButton.styleFrom(
      foregroundColor: scheme.onSurface,
      backgroundColor: scheme.onSurface.withValues(alpha: 0.04),
      minimumSize: const Size.fromHeight(AppLayout.controlHeight),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.small,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    );

    return icon == null
        ? TextButton(onPressed: onPressed, style: buttonStyle, child: text)
        : TextButton.icon(
            onPressed: onPressed,
            style: buttonStyle,
            icon: Icon(icon, size: 20),
            label: text,
          );
  }
}

/// A card's actions, side by side while each still has room to say what it is.
///
/// The alternative — splitting the width evenly and letting the labels fall
/// where they may — is how "Review and sign" becomes "Review and…", which is
/// worse than the same two buttons stacked.
class ActionRow extends StatelessWidget {
  const ActionRow({required this.actions, this.minWidth = 140, super.key});

  final List<Widget> actions;

  /// The narrowest a button may get before the row gives up and stacks.
  ///
  /// The default suits a pair of two-word labels. Raise it for anything
  /// longer — the row cannot measure the text inside its children, so this is
  /// where the caller says how much room its labels need.
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    if (actions.length == 1) return actions.single;

    Widget stacked() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, action) in actions.indexed) ...[
          if (index > 0) Gap.h8,
          action,
        ],
      ],
    );

    if (prefersStacked(context)) return stacked();

    return LayoutBuilder(
      builder: (context, constraints) {
        final gaps = AppSpace.md * (actions.length - 1);
        final each = (constraints.maxWidth - gaps) / actions.length;
        if (each < minWidth) return stacked();

        return Row(
          children: [
            for (final (index, action) in actions.indexed) ...[
              if (index > 0) Gap.w12,
              Expanded(child: action),
            ],
          ],
        );
      },
    );
  }
}

/// True when the platform's text size has grown past the point where a row of
/// side-by-side content still fits on a phone.
///
/// Used by the two-up layouts to fall back to a single column. The threshold is
/// the body size the app draws labels at; once one line of it is 19 logical
/// pixels tall, two columns of anything stop working at 390pt.
bool prefersStacked(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) >= 19;
