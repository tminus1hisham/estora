import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_surface_card.dart';
import '../../../components/async_button.dart';
import '../../../core/theme/app_theme.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';

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
      return AuthScaffold(
        eyebrow: 'Next step',
        title: 'Check your inbox',
        subtitle:
            'If an account exists for ${_email.text.trim()}, a secure reset link is on its way.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSurfaceCard(
              color: scheme.primaryContainer.withValues(alpha: 0.56),
              borderColor: scheme.primary.withValues(alpha: 0.2),
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
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Gap.h8,
                  Text(
                    'Check your spam folder if it does not arrive within a few minutes.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Gap.h24,
            OutlinedButton.icon(
              onPressed: () => setState(() => _sent = false),
              icon: const Icon(Icons.edit_outlined, size: 19),
              label: const Text('Use a different address'),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      eyebrow: 'Account recovery',
      title: 'Reset your password',
      subtitle:
          'Enter your account email and we will send a secure reset link.',
      failure: auth.failure,
      onDismissFailure: ref.read(authControllerProvider.notifier).clearFailure,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                enabled: !auth.isBusy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                autofocus: true,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: (value) => (value?.trim().contains('@') ?? false)
                    ? null
                    : 'Enter a valid email address',
                onFieldSubmitted: (_) => _submit(),
              ),
              Gap.h24,
              AsyncButton(
                label: 'Send reset link',
                loadingLabel: 'Sending reset link',
                icon: Icons.arrow_forward_rounded,
                expand: true,
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
                    color: scheme.onSurfaceVariant,
                  ),
                  Gap.w8,
                  Flexible(
                    child: Text(
                      'We never disclose whether an email is registered.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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
