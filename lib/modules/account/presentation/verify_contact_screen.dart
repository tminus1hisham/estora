import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_bottom_action_bar.dart';
import '../../../components/async_button.dart';
import '../../../components/page_header.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/access.dart';
import '../application/account_controller.dart';

/// Which thing is being confirmed.
enum VerificationChannel {
  email,
  phone,
  twoFactor;

  static VerificationChannel fromPath(String? raw) => switch (raw) {
    'phone' => VerificationChannel.phone,
    'two-factor' => VerificationChannel.twoFactor,
    _ => VerificationChannel.email,
  };

  String get title => switch (this) {
    VerificationChannel.email => 'Confirm your email',
    VerificationChannel.phone => 'Confirm your phone number',
    VerificationChannel.twoFactor => 'Finish turning on two-factor',
  };
}

/// Entering a code to confirm an email address, a phone number, or two-factor.
///
/// One screen for the three because they are the same act — a code arrives out
/// of band and is typed back — and the contract's three routes differ only in
/// what they confirm. Which one it is decides the copy and the call, and
/// nothing else.
class VerifyContactScreen extends ConsumerStatefulWidget {
  const VerifyContactScreen({required this.channel, super.key});

  final VerificationChannel channel;

  @override
  ConsumerState<VerifyContactScreen> createState() =>
      _VerifyContactScreenState();
}

class _VerifyContactScreenState extends ConsumerState<VerifyContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit(PlatformUser account) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = account.emailAddress ?? '';
    final code = _codeController.text.trim();
    final actions = ref.read(accountActionsProvider);

    final result = switch (widget.channel) {
      VerificationChannel.email => await actions.confirmEmail(
        email: email,
        token: code,
      ),
      VerificationChannel.phone => await actions.confirmPhoneNumber(
        email: email,
        phoneNumber: account.phoneNumber ?? '',
        token: code,
      ),
      VerificationChannel.twoFactor => await actions.verifyTwoFactor(
        email: email,
        code: code,
      ),
    };

    if (!mounted) return;

    switch (result) {
      case Ok():
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(switch (widget.channel) {
              VerificationChannel.email => 'Email address confirmed.',
              VerificationChannel.phone => 'Phone number confirmed.',
              VerificationChannel.twoFactor =>
                'Two-factor authentication is on.',
            }),
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
    final account = ref.watch(myAccountProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.channel.title)),
      body: switch (account) {
        AsyncLoading() when !account.hasValue => const LoadingView(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(myAccountProvider),
        ),
        _ => _form(account.requireValue),
      },
      bottomNavigationBar: account.hasValue
          ? AppBottomActionBar(
              child: AsyncButton(
                label: 'Confirm',
                icon: Icons.check_rounded,
                expand: true,
                onPressed: () => _submit(account.requireValue),
              ),
            )
          : null,
    );
  }

  Widget _form(PlatformUser account) {
    final destination = switch (widget.channel) {
      VerificationChannel.phone => account.phoneNumber,
      _ => account.emailAddress,
    };

    return Form(
      key: _formKey,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            children: [
              PageHeader(
                title: 'Enter the code',
                subtitle: destination == null || destination.isEmpty
                    ? 'We have sent you a code.'
                    : 'We sent a code to $destination.',
                compact: true,
              ),
              Gap.h16,
              SectionCard(
                children: [
                  TextFormField(
                    controller: _codeController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                    decoration: const InputDecoration(
                      labelText: 'Verification code',
                      counterText: '',
                    ),
                    maxLength: 8,
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter the code you were sent'
                        : null,
                  ),
                  Gap.h12,
                  Text(
                    'The code is short-lived. If it has expired, go back and '
                    'ask for a new one.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
