import 'package:flutter/material.dart';

import '../../../../components/surface_atoms.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';

/// The parts of the home screen's visual language that the invoices and lease
/// screens now share live in `components/surface_atoms.dart` — the icon tile,
/// the glow, the tone pill, the hairline, the meter and the stat pair. They are
/// re-exported here so this screen's widgets keep reading as one file's worth
/// of vocabulary.
export '../../../../components/surface_atoms.dart';

/// The foreground on the home screen's dark surfaces.
///
/// Retained as a name because thirteen call sites read better for it; the
/// colour itself is the app-wide [kOnDark].
const Color kHomeOnDark = kOnDark;

/// A status badge drawn over a photograph.
///
/// Smoked glass rather than a tint, because a 16% wash of any colour over an
/// unknown image is a gamble; a dark plate under the label is not. This one
/// stays local: nothing outside the home header puts a badge on a photograph.
class HomeGlassChip extends StatelessWidget {
  const HomeGlassChip({required this.label, required this.tone, super.key});

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
          color: AppPalette.navy950.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ToneDot(color: color),
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

/// True when the platform's text size has grown past the point where a row of
/// side-by-side content still fits on a phone.
bool homePrefersStacked(BuildContext context) => prefersStacked(context);
