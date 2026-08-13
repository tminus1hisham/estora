import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
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
            'If an account exists for ${_email.text.trim()}, a secure reset link is on its way.',
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
                      Icons.mark_email_read_outlined,
                      size: 30,
                      color: scheme.onPrimary,
                    ),
                  ),
                  Gap.h16,
                  Text(
                    'The link expires for your security.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: kAuthOnDark),
                  ),
                  Gap.h8,
                  const AuthNote(
                    'Check your spam folder if it does not arrive within a few '
                    'minutes.',
                    align: TextAlign.center,
                  ),
                ],
              ),
            ),
            Gap.h24,
            AuthGhostButton(
              label: 'Use a different address',
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
          'Enter your account email and we will send a secure reset link.',
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
                label: 'Email address',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                autofocus: true,
                validator: (value) => (value?.trim().contains('@') ?? false)
                    ? null
                    : 'Enter a valid email address',
                onSubmitted: (_) => _submit(),
              ),
              Gap.h24,
              AuthPrimaryAction(
                label: 'Send reset link',
                loadingLabel: 'Sending reset link',
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
                      'We never disclose whether an email is registered.',
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
