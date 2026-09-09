import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/phone_number.dart';
import 'app_pressable.dart';

/// The country code a phone field is dialling on: a flag, a `+254`, and a
/// chevron that opens the picker.
///
/// Built to sit in a text field's `prefixIcon` slot so the code and the number
/// read as one control — which is what they are, since the two halves are only
/// ever sent joined. Pass it with
/// `prefixIconConstraints: CountryCodeField.constraints`, or through
/// `AuthField.prefix`, which does that for you.
///
/// The control is deliberately the same on every stage: it takes its colours
/// from the surrounding [InputDecorationTheme], so the dark sign-in glass and
/// an ordinary form both get a code that matches the field it is cut into.
class CountryCodeField extends StatelessWidget {
  const CountryCodeField({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final Country value;
  final ValueChanged<Country> onChanged;
  final bool enabled;

  /// Lets the control size to its content rather than to the 48px square an
  /// icon would get.
  static const BoxConstraints constraints = BoxConstraints(
    minWidth: 0,
    minHeight: AppLayout.minTouchTarget,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decoration = theme.inputDecorationTheme;
    final foreground =
        decoration.prefixIconColor ?? theme.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      label: 'Country code',
      value: '${value.name}, ${value.display}',
      child: AppPressable(
        enabled: enabled,
        scale: 0.95,
        child: InkWell(
          onTap: enabled ? () => _open(context) : null,
          borderRadius: AppRadius.small,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              AppSpace.sm,
              AppSpace.xs,
              AppSpace.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The flag carries no information the code does not, so it is
                // sized as an ornament rather than as a second label.
                Text(value.flag, style: const TextStyle(fontSize: 17)),
                Gap.w4,
                // Flexible so the field, and not this control, decides how
                // much room the number gets: a long code on a narrow handset
                // gives ground rather than overflowing the row.
                Flexible(
                  child: Text(
                    value.display,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: foreground,
                      fontWeight: AppTypography.medium,
                      // Steadies the row so the number beside it does not
                      // shuffle sideways as codes change width.
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: foreground,
                ),
                Gap.w4,
                // A hairline between the code and the number: one control, two
                // things to read.
                SizedBox(
                  height: 22,
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: foreground.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showCountryPicker(context, selected: value);
    if (picked != null) onChanged(picked);
  }
}

/// Opens the country list and returns what was chosen, or null if the sheet
/// was dismissed.
///
/// The sheet takes the surrounding theme's surface explicitly, because the
/// sign-in stage runs on a transparent canvas and a sheet inheriting that
/// would come up as a floating list with nothing behind it.
Future<Country?> showCountryPicker(
  BuildContext context, {
  required Country selected,
}) {
  final scheme = Theme.of(context).colorScheme;

  return showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: scheme.surface,
    builder: (_) => _CountryPickerSheet(selected: selected),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.selected});

  final Country selected;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _query = TextEditingController();
  List<Country> _results = Countries.all;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() => _results = Countries.search(value));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Tall enough to be worth scrolling, short enough that the field being
    // filled in stays on screen behind it.
    final height = MediaQuery.sizeOf(context).height * 0.72;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Country code',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                  Gap.h12,
                  TextField(
                    controller: _query,
                    autofocus: false,
                    onChanged: _search,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Search country or code',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        'No country matches that.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: Gap.lg),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final country = _results[index];
                        final isSelected = country.iso == widget.selected.iso;

                        return ListTile(
                          leading: Text(
                            country.flag,
                            style: const TextStyle(fontSize: 22),
                          ),
                          title: Text(country.name),
                          trailing: Text(
                            country.display,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: isSelected
                                  ? AppTypography.semibold
                                  : AppTypography.regular,
                            ),
                          ),
                          selected: isSelected,
                          onTap: () => Navigator.of(context).pop(country),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
