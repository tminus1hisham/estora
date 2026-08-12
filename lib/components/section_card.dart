import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_surface_card.dart';

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
    return AppSurfaceCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ),
                if (trailing != null) ...[Gap.w12, trailing!],
              ],
            ),
            Gap.h16,
          ],
          ...children,
        ],
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

    final labelWidget = Text(
      label,
      style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
    );
    final resolvedValue =
        valueWidget ??
        Text(
          value!,
          textAlign: TextAlign.right,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: emphasise ? AppTypography.bold : AppTypography.semibold,
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack =
              constraints.maxWidth < 290 ||
              MediaQuery.textScalerOf(context).scale(14) >= 20;
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                labelWidget,
                Gap.h4,
                Align(alignment: Alignment.centerLeft, child: resolvedValue),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: labelWidget),
              Gap.w12,
              Expanded(
                flex: 5,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: resolvedValue,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
