import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_bottom_action_bar.dart';
import '../../../components/async_button.dart';
import '../../../components/page_header.dart';
import '../../../components/section_card.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../application/account_controller.dart';

/// Changing the password on a signed-in account.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscure = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final phone = ref.read(authControllerProvider).user?.phone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This account has no phone number on file, so the password cannot '
            'be changed here.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await ref
        .read(accountActionsProvider)
        .changePassword(
          phoneNumber: phone,
          currentPassword: _currentController.text,
          newPassword: _newController.text,
        );

    if (!mounted) return;

    switch (result) {
      case Ok():
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed.'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.maxReadingWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.sm,
                Gap.lg,
                Gap.xxl,
              ),
              children: [
                const PageHeader(
                  title: 'Choose a new password',
                  subtitle:
                      'You stay signed in on this device. Other devices will '
                      'need the new password next time.',
                  compact: true,
                ),
                Gap.h16,
                SectionCard(
                  children: [
                    TextFormField(
                      controller: _currentController,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: _obscure ? 'Show' : 'Hide',
                        ),
                      ),
                      validator: (value) => (value?.isEmpty ?? true)
                          ? 'Enter your current password'
                          : null,
                    ),
                    Gap.h12,
                    TextFormField(
                      controller: _newController,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        prefixIcon: Icon(Icons.lock_reset_rounded),
                        helperText: 'At least 8 characters.',
                      ),
                      validator: (value) {
                        final text = value ?? '';
                        if (text.trim().length < 8) {
                          return 'Use at least 8 characters';
                        }
                        return text == _currentController.text
                            ? 'Choose something different from your current '
                                  'password'
                            : null;
                      },
                    ),
                    Gap.h12,
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: Icon(Icons.lock_reset_rounded),
                      ),
                      validator: (value) => value == _newController.text
                          ? null
                          : 'The two passwords do not match',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomActionBar(
        child: AsyncButton(
          label: 'Change password',
          icon: Icons.check_rounded,
          expand: true,
          onPressed: _save,
        ),
      ),
    );
  }
}
