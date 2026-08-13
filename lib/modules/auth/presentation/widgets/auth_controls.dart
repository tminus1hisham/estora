import 'package:flutter/material.dart';

import '../../../../components/app_pressable.dart';
import '../../../../components/async_button.dart';
import '../../../../core/theme/app_theme.dart';
import 'auth_stage.dart';

/// A text field that lights up when it has the caret.
///
/// The app's shared [InputDecorationTheme] already thickens the border on
/// focus. On a dark stage that is not enough to say where you are typing, so
/// this adds a soft glow behind the field and warms the leading icon to the
/// primary colour. Both are driven from one tween, so they move together.
///
/// The field owns its [FocusNode] because the glow is the only thing that
/// needs it; a caller that passes one in would have to remember to dispose it.
class AuthField extends StatefulWidget {
  const AuthField({
    required this.controller,
    required this.label,
    this.icon,
    this.hint,
    this.enabled = true,
    this.obscureText = false,
    this.autocorrect = true,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.helperText,
    this.suffix,
    this.validator,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;

  /// Optional. A pair of fields on one row — a first and last name — reads
  /// better without one; a field standing alone reads better with one.
  final IconData? icon;

  final String? hint;
  final bool enabled;
  final bool obscureText;
  final bool autocorrect;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final String? helperText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChanged);
  bool _focused = false;

  void _onFocusChanged() {
    if (_focused == _focusNode.hasFocus) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final idleIcon = kAuthOnDark.withValues(alpha: 0.62);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.standard;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _focused ? 1 : 0),
      duration: duration,
      curve: AppMotion.enter,
      builder: (context, t, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.small,
            boxShadow: t < 0.01
                ? const <BoxShadow>[]
                : [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.26 * t),
                      blurRadius: 26 * t,
                      // Pulled in so the glow reads as light escaping from
                      // behind the field rather than as a second border.
                      spreadRadius: -8,
                    ),
                  ],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            obscureText: widget.obscureText,
            autocorrect: widget.autocorrect,
            autofocus: widget.autofocus,
            textCapitalization: widget.textCapitalization,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            validator: widget.validator,
            onFieldSubmitted: widget.onSubmitted,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: kAuthOnDark,
              fontWeight: AppTypography.medium,
            ),
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              helperText: widget.helperText,
              prefixIcon: widget.icon == null
                  ? null
                  : Icon(
                      widget.icon,
                      color: Color.lerp(idleIcon, scheme.primary, t),
                    ),
              suffixIcon: widget.suffix,
            ),
          ),
        );
      },
    );
  }
}

/// The one control the sign-in screen is built around.
///
/// A gradient plate with the app's [AsyncButton] laid over it in transparent
/// form, rather than a bespoke button: the button underneath keeps the
/// double-tap guard, the spinner and the loading semantics that every other
/// primary action in the app has, and this only changes what it is made of.
class AuthPrimaryAction extends StatelessWidget {
  const AuthPrimaryAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.enabled,
    this.loadingLabel,
    super.key,
  });

  final String label;
  final IconData icon;
  final Future<void> Function() onPressed;
  final bool enabled;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.standard;

    return AppPressable(
      enabled: enabled,
      // Firmer than a card's press. This is a control, and a control that
      // barely moves under the finger feels unresponsive.
      scale: 0.965,
      child: AnimatedOpacity(
        duration: duration,
        curve: AppMotion.enter,
        // The gradient is painted by this wrapper, so the button underneath
        // cannot dim itself when disabled the way a filled button would.
        opacity: enabled ? 1 : 0.5,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppGradients.action,
            borderRadius: AppRadius.small,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppPalette.azure500.withValues(alpha: 0.34),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                      spreadRadius: -6,
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: FilledButtonTheme(
            data: FilledButtonThemeData(
              style:
                  FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    foregroundColor: kAuthOnDark,
                    disabledForegroundColor: kAuthOnDark.withValues(alpha: 0.7),
                    shadowColor: Colors.transparent,
                    elevation: AppElevation.none,
                    // A touch taller than the app's standard control: this is
                    // the only thing on the screen anyone came here to press.
                    minimumSize: const Size(0, AppLayout.controlHeight + 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.xl,
                      vertical: AppSpace.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.small,
                    ),
                    textStyle: Theme.of(context).textTheme.labelLarge,
                  ).copyWith(
                    overlayColor: WidgetStatePropertyAll(
                      kAuthOnDark.withValues(alpha: 0.1),
                    ),
                  ),
            ),
            child: AsyncButton(
              label: label,
              loadingLabel: loadingLabel,
              icon: icon,
              expand: true,
              enabled: enabled,
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }
}

/// Supporting text inside the console.
///
/// Quieter than [TextTheme.bodySmall] on its own would be. This is the text
/// that explains a field rather than the text anyone is here to read.
class AuthNote extends StatelessWidget {
  const AuthNote(this.text, {this.align = TextAlign.start, super.key});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: kAuthOnDark.withValues(alpha: 0.62),
      ),
    );
  }
}

/// A plate for content that needs separating from the rest of a console.
///
/// A tint of the foreground rather than a surface colour, for the same reason
/// the fields are: the console is already glass over a photograph, and a solid
/// panel inside it reads as a hole rather than as a raised area.
class AuthInsetCard extends StatelessWidget {
  const AuthInsetCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.accent = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Tints the plate with the primary colour, for the one card on a screen
  /// that is the answer rather than a detail of it.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = accent ? scheme.primary : kAuthOnDark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: accent ? 0.12 : 0.05),
        borderRadius: AppRadius.small,
        border: Border.all(color: tint.withValues(alpha: accent ? 0.3 : 0.13)),
      ),
      child: child,
    );
  }
}

/// A secondary action for the stage itself, outside the console.
///
/// Outlined in the foreground colour rather than in the primary one: out here
/// there is no glass to separate a blue outline from the photograph behind it,
/// and the brand's blues are dark enough to vanish against navy.
class AuthGhostButton extends StatelessWidget {
  const AuthGhostButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      enabled: onPressed != null,
      scale: 0.975,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: kAuthOnDark,
          disabledForegroundColor: kAuthOnDark.withValues(alpha: 0.4),
          backgroundColor: kAuthOnDark.withValues(alpha: 0.04),
          minimumSize: const Size(0, AppLayout.controlHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xl,
            vertical: AppSpace.md,
          ),
          side: BorderSide(color: kAuthOnDark.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
          textStyle: Theme.of(context).textTheme.labelLarge,
        ),
      ),
    );
  }
}
