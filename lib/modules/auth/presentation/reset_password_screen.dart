import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/async_button.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/routes.dart';
import '../../account/application/account_controller.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_page.dart';

/// Finishing a password reset with the code that was sent.
///
/// Reachable without a session, because whoever is here could not sign in —
/// that is the whole reason they are here. The token stands in for the
/// session, and the server is what decides whether it is good.
///
/// The phone number is carried through from the forgot-password screen so it
/// does not have to be typed twice, and stays editable in case it was typed
/// wrong the first time.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({this.phoneNumber, super.key});

  final String? phoneNumber;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController = TextEditingController(
    text: widget.phoneNumber ?? '',
  );
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await ref
        .read(accountActionsProvider)
        .resetPassword(
          phoneNumber: _phoneController.text.trim(),
          resetToken: _tokenController.text.trim(),
          newPassword: _passwordController.text,
        );

    if (!mounted) return;

    switch (result) {
      case Ok():
        // Back to the sign-in screen rather than straight in: the reset proves
        // they hold the phone, not that they know the password they just set.
        context.goNamed(Routes.login);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset. Sign in with your new password.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case Err(:final failure):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      title: 'Set a new password',
      subtitle:
          'Enter the code we sent you, then choose a password you have not '
          'used here before.',
      console: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthField(
              controller: _phoneController,
              label: 'Phone number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Enter your phone number';
                return text.replaceAll(RegExp(r'\D'), '').length < 9
                    ? 'Enter a valid phone number'
                    : null;
              },
            ),
            Gap.h12,
            AuthField(
              controller: _tokenController,
              label: 'Reset code',
              icon: Icons.pin_outlined,
              keyboardType: TextInputType.number,
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? 'Enter the code you were sent'
                  : null,
            ),
            Gap.h12,
            AuthField(
              controller: _passwordController,
              label: 'New password',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) => (value ?? '').trim().length < 8
                  ? 'Use at least 8 characters'
                  : null,
            ),
            Gap.h12,
            AuthField(
              controller: _confirmController,
              label: 'Confirm new password',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              validator: (value) => value == _passwordController.text
                  ? null
                  : 'The two passwords do not match',
            ),
            Gap.h24,
            AsyncButton(
              label: 'Reset password',
              icon: Icons.lock_reset_rounded,
              expand: true,
              onPressed: _submit,
            ),
          ],
        ),
      ),
      footer: TextButton(
        onPressed: () => context.goNamed(Routes.login),
        child: const Text('Back to sign in'),
      ),
    );
  }
}
