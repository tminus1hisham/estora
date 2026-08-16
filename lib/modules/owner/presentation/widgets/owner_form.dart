import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';

/// A labelled field on the owner stage.
///
/// The app has no shared field widget — screens lean on the app-wide
/// `InputDecorationTheme`, and the only bespoke one is `AuthField`, which is
/// specific to the auth stage. This is the owner's equivalent: thin, so the
/// theme still does the work, but it exists so a four-step form is not four
/// screens of repeated `TextFormField` decoration.
class OwnerField extends StatelessWidget {
  const OwnerField({
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.maxLines = 1,
    this.validator,
    this.suffix,
    this.inputFormatters,
    this.onChanged,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final String? Function(String?)? validator;
  final String? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      validator: validator,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        suffixText: suffix,
      ),
    );
  }
}

/// A field that reads a [Money] amount.
///
/// Digits and at most one decimal separator, parsed through
/// [Money.fromMajor] — never held as a `double`. Section 84 keeps money in
/// integer minor units everywhere, and a form is not an exception: a rate typed
/// as `22.5` has to arrive as 2250 minor units, not as a float that is nearly
/// that.
class MoneyField extends StatelessWidget {
  const MoneyField({
    required this.label,
    required this.controller,
    required this.currency,
    this.hint,
    this.helper,
    this.suffix,
    this.validator,
    this.onChanged,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String currency;
  final String? hint;
  final String? helper;

  /// Trails the figure, e.g. `per m²`.
  final String? suffix;

  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  /// The amount currently typed, or null if it is not a usable number.
  static Money? parse(String raw, String currency) {
    final cleaned = raw.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    final value = num.tryParse(cleaned);
    if (value == null || value < 0) return null;
    return Money.fromMajor(value, currency);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      validator:
          validator ??
          (value) => parse(value ?? '', currency) == null
              ? 'Enter an amount'
              : null,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        prefixText: '$currency ',
        suffixText: suffix,
      ),
    );
  }
}

/// A field that reads a plain number, e.g. an area or a count.
class NumberField extends StatelessWidget {
  const NumberField({
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.suffix,
    this.allowDecimal = true,
    this.validator,
    this.onChanged,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final String? suffix;
  final bool allowDecimal;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  static num? parse(String raw) {
    final cleaned = raw.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    final value = num.tryParse(cleaned);
    return (value == null || value <= 0) ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          allowDecimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
        ),
      ],
      validator:
          validator ??
          (value) => parse(value ?? '') == null ? 'Enter a number' : null,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        suffixText: suffix,
      ),
    );
  }
}

/// The panel that shows what a rate would ask for a given area.
///
/// The one place in the app where the client multiplies money, and it is
/// labelled as indicative for exactly that reason. Section 65 puts the
/// authoritative figure on the server; this is a preview of an intention, and
/// what gets saved is whatever comes back from the write.
class RatePreview extends StatelessWidget {
  const RatePreview({
    required this.rate,
    required this.area,
    this.caption,
    super.key,
  });

  final Money? rate;
  final num? area;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rate = this.rate;
    final area = this.area;

    final ready = rate != null && area != null;
    final derived = ready ? rate.scaledBy(area) : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: AppRadius.medium,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INDICATIVE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          Gap.h8,
          Text(
            derived == null
                ? 'Enter an area and a rate to see what a unit would ask.'
                : caption ??
                      'A ${_trim(area!)} m² unit would ask '
                          '${derived.format()} a month.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: derived == null ? scheme.onSurfaceVariant : null,
            ),
          ),
          if (derived != null) ...[
            Gap.h8,
            Text(
              'The figure saved is the one the server returns.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _trim(num value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}
