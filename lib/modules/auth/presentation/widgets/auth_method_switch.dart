import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'auth_stage.dart';

/// One choice in an [AuthMethodSwitch].
class AuthMethodOption {
  const AuthMethodOption({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// The control that chooses how someone signs in.
///
/// A bespoke switch rather than [SegmentedButton] because the stock control
/// draws its own container, its own dividers and a check mark on the selected
/// segment, all of which fight the glass. This is a single plate with a
/// selection that slides between positions — the movement is what tells you
/// the two options are one control with one state, which is the thing a pair
/// of buttons can never say.
///
/// Past the point where the platform text size stops two labels fitting side
/// by side, it becomes a stack of full-width options. The sliding plate is
/// worth losing; a clipped label is not.
class AuthMethodSwitch extends StatelessWidget {
  const AuthMethodSwitch({
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final List<AuthMethodOption> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // The same threshold the home screen's two-up layouts use, one step later:
    // these labels are short enough to survive slightly more growth than a
    // row of statistics.
    final stacked = MediaQuery.textScalerOf(context).scale(14) >= 20;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.standard;

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) Gap.h8,
            _Option(
              option: options[i],
              selected: i == selectedIndex,
              enabled: enabled,
              duration: duration,
              // Standing alone, each option has to carry its own plate.
              framed: true,
              onTap: () => onChanged(i),
            ),
          ],
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpace.xs),
      decoration: BoxDecoration(
        color: kAuthOnDark.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: kAuthOnDark.withValues(alpha: 0.12)),
      ),
      child: Stack(
        children: [
          // Fills to the size the row settles on, so the sliding plate never
          // needs to be told how tall a segment is at the current text size.
          Positioned.fill(
            child: AnimatedAlign(
              alignment: _alignmentFor(selectedIndex),
              duration: duration,
              curve: AppMotion.emphasized,
              child: FractionallySizedBox(
                widthFactor: 1 / options.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: kAuthOnDark.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: kAuthOnDark.withValues(alpha: 0.22),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < options.length; i++)
                Expanded(
                  child: _Option(
                    option: options[i],
                    selected: i == selectedIndex,
                    enabled: enabled,
                    duration: duration,
                    framed: false,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Alignment _alignmentFor(int index) {
    if (options.length < 2) return Alignment.center;
    return Alignment(-1 + 2 * index / (options.length - 1), 0);
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.duration,
    required this.framed,
    required this.onTap,
  });

  final AuthMethodOption option;
  final bool selected;
  final bool enabled;
  final Duration duration;

  /// Whether this option draws its own background, or leaves that to the
  /// plate sliding behind it.
  final bool framed;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = kAuthOnDark.withValues(
      alpha: enabled ? (selected ? 1 : 0.6) : 0.35,
    );

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The one spot of colour in the control: what is selected reads at a
        // glance without having to compare two weights of white.
        Icon(
          option.icon,
          size: 18,
          color: selected && enabled ? scheme.primary : foreground,
        ),
        Gap.w8,
        Flexible(
          child: Text(
            option.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: selected
                  ? AppTypography.bold
                  : AppTypography.semibold,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: AnimatedContainer(
        duration: duration,
        curve: AppMotion.enter,
        decoration: BoxDecoration(
          color: framed && selected
              ? kAuthOnDark.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: framed
              ? Border.all(
                  color: kAuthOnDark.withValues(alpha: selected ? 0.22 : 0.1),
                )
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            splashColor: kAuthOnDark.withValues(alpha: 0.06),
            highlightColor: kAuthOnDark.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: AppSpace.md,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 24),
                child: Center(heightFactor: 1, child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
