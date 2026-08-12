import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/async_button.dart';
import '../../../core/theme/app_theme.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Section 77's Forgot Password screen.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
        title: 'Check your inbox',
        subtitle:
            'If an account exists for ${_email.text.trim()}, we have sent a '
            'link to reset your password.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              size: 48,
              color: scheme.primary,
            ),
            Gap.h24,
            OutlinedButton(
              onPressed: () => setState(() => _sent = false),
              child: const Text('Use a different address'),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      title: 'Reset your password',
      subtitle: 'Enter the email address on your account and we will send you '
          'a reset link.',
      failure: auth.failure,
      onDismissFailure: ref.read(authControllerProvider.notifier).clearFailure,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (v) => (v?.trim().contains('@') ?? false)
                  ? null
                  : 'Enter a valid email address',
              onFieldSubmitted: (_) => _submit(),
            ),
            Gap.h24,
            AsyncButton(
              label: 'Send reset link',
              enabled: !auth.isBusy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
