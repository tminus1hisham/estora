import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_controller.dart';

/// System, Light or Dark.
///
/// A segmented button rather than a single dark-mode switch: "System" is a
/// real third choice, and a switch cannot express following the platform.
class ThemeModeControl extends ConsumerWidget {
  const ThemeModeControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeModeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ThemeMode>(
            segments: [
              for (final mode in ThemeMode.values)
                ButtonSegment<ThemeMode>(
                  value: mode,
                  label: Text(mode.label),
                  icon: Icon(mode.icon),
                ),
            ],
            selected: {selected},
            showSelectedIcon: false,
            onSelectionChanged: (values) =>
                ref.read(themeModeProvider.notifier).select(values.first),
          ),
          Gap.h8,
          Text(
            selected == ThemeMode.system
                ? 'Following your device setting.'
                : 'Staying ${selected.label.toLowerCase()} whatever your '
                      'device is set to.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
