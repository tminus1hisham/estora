import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../navigation/routes.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_page.dart';
import 'widgets/auth_stage.dart';

/// Requests a password reset without revealing whether an account exists.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(_email.text.trim());
    if (ok && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    if (_sent) {
      return AuthPage(
        eyebrow: 'Next step',
        title: 'Check your inbox',
        subtitle:
            'If an account exists for ${_email.text.trim()}, a reset code is on its way.',
        console: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AuthInsetCard(
              accent: true,
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.sms_outlined,
                      size: 30,
                      color: scheme.onPrimary,
                    ),
                  ),
                  Gap.h16,
                  Text(
                    'The code expires for your security.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: kAuthOnDark),
                  ),
                  Gap.h8,
                  const AuthNote(
                    'It should arrive within a few minutes.',
                    align: TextAlign.center,
                  ),
                ],
              ),
            ),
            Gap.h24,
            AuthPrimaryAction(
              label: 'Enter the code',
              icon: Icons.arrow_forward_rounded,
              enabled: true,
              // Carried through so the number does not have to be typed
              // twice; the reset screen leaves it editable in case it was
              // wrong the first time.
              onPressed: () async => context.pushNamed(
                Routes.resetPassword,
                queryParameters: {'phone': _email.text.trim()},
              ),
            ),
            Gap.h12,
            AuthGhostButton(
              label: 'Use a different number',
              icon: Icons.edit_outlined,
              onPressed: () => setState(() => _sent = false),
            ),
          ],
        ),
      );
    }

    return AuthPage(
      eyebrow: 'Account recovery',
      title: 'Reset your password',
      subtitle:
          'Enter the phone number on your account and we will send a reset '
          'code.',
      failure: auth.failure,
      onDismissFailure: ref.read(authControllerProvider.notifier).clearFailure,
      console: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AuthField(
                controller: _email,
                enabled: !auth.isBusy,
                label: 'Phone number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                autocorrect: false,
                autofocus: true,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Enter your phone number';
                  return text.replaceAll(RegExp(r'\D'), '').length < 9
                      ? 'Enter a valid phone number'
                      : null;
                },
                onSubmitted: (_) => _submit(),
              ),
              Gap.h24,
              AuthPrimaryAction(
                label: 'Send reset code',
                loadingLabel: 'Sending reset code',
                icon: Icons.arrow_forward_rounded,
                enabled: !auth.isBusy,
                onPressed: _submit,
              ),
              Gap.h16,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: kAuthOnDark.withValues(alpha: 0.62),
                  ),
                  Gap.w8,
                  const Flexible(
                    child: AuthNote(
                      'We never disclose whether a number is registered.',
                      align: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
