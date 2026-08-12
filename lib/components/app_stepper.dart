import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// One stop in an [AppStepper].
class AppStep {
  const AppStep({
    required this.label,
    this.icon,
    this.detail,
    this.done = false,
  });

  final String label;

  /// Shown in the marker instead of the step number.
  final IconData? icon;

  /// A second line, in the vertical form only — "3 of 4 done", "Outstanding".
  final String? detail;

  /// Whether this step is finished. Read by the vertical form, where progress
  /// is not necessarily a single frontier: a booking can have its fee paid but
  /// its requirements outstanding.
  final bool done;
}

enum _StepState { complete, current, upcoming }

/// Progress through a multi-step flow.
///
/// Two forms, because the app needs both and they were previously three
/// separate hand-built widgets: [AppStepper.horizontal] heads a screen that is
/// one step of a flow, and [AppStepper.vertical] is a checklist of what has and
/// has not happened yet.
class AppStepper extends StatelessWidget {
  /// A compact header showing where this screen sits in a flow.
  const AppStepper.horizontal({
    required this.steps,
    required this.currentIndex,
    this.semanticsLabel,
    super.key,
  }) : _axis = Axis.horizontal;

  /// A checklist. Each step's state comes from its own [AppStep.done].
  const AppStepper.vertical({
    required this.steps,
    this.semanticsLabel,
    super.key,
  }) : _axis = Axis.vertical,
       currentIndex = 0;

  final List<AppStep> steps;
  final int currentIndex;
  final String? semanticsLabel;
  final Axis _axis;

  @override
  Widget build(BuildContext context) {
    final label =
        semanticsLabel ??
        (_axis == Axis.horizontal && currentIndex < steps.length
            ? 'Step ${currentIndex + 1} of ${steps.length}: '
                  '${steps[currentIndex].label}'
            : null);

    final body = _axis == Axis.horizontal
        ? _HorizontalSteps(steps: steps, currentIndex: currentIndex)
        : _VerticalSteps(steps: steps);

    if (label == null) return body;
    return Semantics(label: label, child: ExcludeSemantics(child: body));
  }
}

class _HorizontalSteps extends StatelessWidget {
  const _HorizontalSteps({required this.steps, required this.currentIndex});

  final List<AppStep> steps;
  final int currentIndex;

  _StepState _stateFor(int index) {
    if (index < currentIndex) return _StepState.complete;
    if (index == currentIndex) return _StepState.current;
    return _StepState.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          Expanded(
            child: _HorizontalStep(
              step: steps[index],
              number: index + 1,
              state: _stateFor(index),
            ),
          ),
          if (index != steps.length - 1)
            Expanded(
              child: Padding(
                // Aligns the connector with the middle of the markers rather
                // than the middle of the marker-plus-label column.
                padding: const EdgeInsets.only(top: 16),
                child: _Connector(filled: index < currentIndex),
              ),
            ),
        ],
      ],
    );
  }
}

class _HorizontalStep extends StatelessWidget {
  const _HorizontalStep({
    required this.step,
    required this.number,
    required this.state,
  });

  final AppStep step;
  final int number;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final active = state != _StepState.upcoming;

    final (background, foreground) = switch (state) {
      _StepState.complete => (scheme.primaryContainer, scheme.onPrimaryContainer),
      _StepState.current => (scheme.primary, scheme.onPrimary),
      _StepState.upcoming => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };

    return Column(
      children: [
        AnimatedContainer(
          duration: AppMotion.standard,
          curve: AppMotion.enter,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            boxShadow: state == _StepState.current
                ? AppElevation.lifted(
                    scheme.primary,
                    brightness: Theme.of(context).brightness,
                  )
                : null,
          ),
          child: Center(
            child: switch (state) {
              _StepState.complete => Icon(
                Icons.check_rounded,
                size: 18,
                color: foreground,
              ),
              _ when step.icon != null => Icon(
                step.icon,
                size: 18,
                color: foreground,
              ),
              _ => Text(
                '$number',
                style: textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: AppTypography.extraBold,
                ),
              ),
            },
          ),
        ),
        Gap.h4,
        Text(
          step.label,
          textAlign: TextAlign.center,
          style: textTheme.labelSmall?.copyWith(
            color: active ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: state == _StepState.current
                ? AppTypography.bold
                : AppTypography.medium,
          ),
        ),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: filled ? 1 : 0),
      duration: AppMotion.standard,
      curve: AppMotion.enter,
      builder: (context, value, _) {
        return SizedBox(
          height: 2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: scheme.outlineVariant),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: ColoredBox(color: scheme.primary),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VerticalSteps extends StatelessWidget {
  const _VerticalSteps({required this.steps});

  final List<AppStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < steps.length; index++)
          _VerticalStep(step: steps[index], isLast: index == steps.length - 1),
      ],
    );
  }
}

class _VerticalStep extends StatelessWidget {
  const _VerticalStep({required this.step, required this.isLast});

  final AppStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final done = step.done;
    final markerColor = done ? scheme.primary : scheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: AppMotion.standard,
                curve: AppMotion.enter,
                height: 22,
                width: 22,
                decoration: BoxDecoration(
                  color: done ? scheme.primary : Colors.transparent,
                  border: Border.all(color: markerColor, width: 2),
                  shape: BoxShape.circle,
                ),
                child: done
                    ? Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: scheme.onPrimary,
                      )
                    : null,
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: markerColor)),
            ],
          ),
          Gap.w12,
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: done
                          ? AppTypography.semibold
                          : AppTypography.medium,
                      color: done ? null : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (step.detail != null)
                    Text(
                      step.detail!,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
