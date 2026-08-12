import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A titled card used to group related fields on detail screens.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.children,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(Gap.lg),
    super.key,
  });

  final String? title;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              Gap.h12,
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A label/value row. The workhorse of every detail screen in the app.
class DetailRow extends StatelessWidget {
  const DetailRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.emphasise = false,
    super.key,
  }) : assert(
         value != null || valueWidget != null,
         'DetailRow needs either a value or a valueWidget',
       );

  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Gap.w12,
          Expanded(
            flex: 5,
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  valueWidget ??
                  Text(
                    value!,
                    textAlign: TextAlign.right,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: emphasise ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
