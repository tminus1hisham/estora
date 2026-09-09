import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/debug/debug_log.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../navigation/routes.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_method_switch.dart';
import 'widgets/auth_page.dart';
import 'widgets/auth_stage.dart';

/// A concise account setup. Formal company and tax details remain part of
/// profile completion so first-time visitors can reach available spaces fast.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// The two types a tenant can register as, in the order the switch offers
  /// them. Listed explicitly rather than taken from [TenantType.values]: that
  /// enum also carries `corporate` and `unknown`, and indexing into it would
  /// tie this control to the declaration order of something it does not own.
  static const _offeredTypes = [TenantType.individual, TenantType.business];

  TenantType _tenantType = TenantType.business;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();

    // Both refusals below happen entirely on the handset: no request is sent,
    // so nothing downstream has anything to say about them. Without these two
    // lines the button looks dead — the commonest reason "creating an account
    // does nothing" turns out to be a field the tenant never scrolled back to.
    if (!(_formKey.currentState?.validate() ?? false)) {
      DebugLog.write(
        'auth',
        'Create account blocked: the form did not validate',
        detail: _unfilledFields(),
      );
      return;
    }
    if (!_acceptedTerms) {
      DebugLog.write('auth', 'Create account blocked: terms not accepted');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms to continue.')),
      );
      return;
    }

    final ok = await ref
        .read(authControllerProvider.notifier)
        .register(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          tenantType: _tenantType,
        );

    if (ok && mounted) context.pushNamed(Routes.otp);
  }

  /// Which inputs are still empty, by name only.
  ///
  /// An empty field is the usual cause of a refused form and the one thing the
  /// validators cannot say from here. The values are deliberately left out:
  /// a name, an email address and a phone number are the tenant's, and a log
  /// is not the place for them.
  List<String> _unfilledFields() => <String>[
    if (_firstName.text.trim().isEmpty) 'firstName',
    if (_lastName.text.trim().isEmpty) 'lastName',
    if (_phone.text.trim().isEmpty) 'phone',
    if (_email.text.trim().isEmpty) 'email',
    if (_password.text.isEmpty) 'password',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return AuthPage(
      eyebrow: 'Join',
      title: 'Create your account',
      showBrandMark: false,
      subtitle:
          'Tell us how you will use the space. You can add company details later.',
      failure: auth.failure,
      onDismissFailure: ref.read(authControllerProvider.notifier).clearFailure,
      console: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'I am renting as',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: kAuthOnDark.withValues(alpha: 0.8),
                ),
              ),
              Gap.h8,
              // The same control the sign-in screen chooses a method with, so
              // the two screens read as one product rather than two.
              AuthMethodSwitch(
                selectedIndex: _offeredTypes.indexOf(_tenantType),
                enabled: !auth.isBusy,
                onChanged: (index) =>
                    setState(() => _tenantType = _offeredTypes[index]),
                options: const [
                  AuthMethodOption(
                    label: 'Individual',
                    icon: Icons.person_outline_rounded,
                  ),
                  AuthMethodOption(
                    label: 'Business',
                    icon: Icons.storefront_outlined,
                  ),
                ],
              ),
              Gap.h24,
              LayoutBuilder(
                builder: (context, constraints) {
                  final useColumn =
                      constraints.maxWidth < 380 ||
                      MediaQuery.textScalerOf(context).scale(14) >= 20;
                  final firstName = _NameField(
                    controller: _firstName,
                    label: 'First name',
                    autofillHint: AutofillHints.givenName,
                    enabled: !auth.isBusy,
                  );
                  final lastName = _NameField(
                    controller: _lastName,
                    label: 'Last name',
                    autofillHint: AutofillHints.familyName,
                    enabled: !auth.isBusy,
                  );
                  if (useColumn) {
                    return Column(children: [firstName, Gap.h12, lastName]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: firstName),
                      Gap.w12,
                      Expanded(child: lastName),
                    ],
                  );
                },
              ),
              Gap.h12,
              AuthField(
                controller: _phone,
                enabled: !auth.isBusy,
                label: 'Phone number',
                hint: '+254 712 345 678',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Enter your phone number';
                  if (text.replaceAll(RegExp(r'[^0-9]'), '').length < 9) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
              Gap.h12,
              AuthField(
                controller: _email,
                enabled: !auth.isBusy,
                label: 'Email address',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                validator: (value) => (value?.trim().contains('@') ?? false)
                    ? null
                    : 'Enter a valid email address',
              ),
              Gap.h12,
              AuthField(
                controller: _password,
                enabled: !auth.isBusy,
                label: 'Create password',
                helperText: 'Use at least 8 characters.',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                suffix: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (value) {
                  if ((value ?? '').length < 8) {
                    return 'Use at least 8 characters';
                  }
                  return null;
                },
                onSubmitted: (_) => _submit(),
              ),
              Gap.h16,
              AuthInsetCard(
                padding: EdgeInsets.zero,
                child: CheckboxListTile(
                  value: _acceptedTerms,
                  enabled: !auth.isBusy,
                  onChanged: (value) =>
                      setState(() => _acceptedTerms = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm,
                    vertical: AppSpace.xs,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
                  title: Text(
                    'I agree to the terms of use and privacy policy.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: kAuthOnDark.withValues(alpha: 0.86),
                    ),
                  ),
                ),
              ),
              Gap.h24,
              AuthPrimaryAction(
                label: 'Create account',
                loadingLabel: 'Creating your account',
                icon: Icons.arrow_forward_rounded,
                enabled: !auth.isBusy,
                onPressed: _submit,
              ),
              Gap.h16,
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const AuthNote('Already have an account?'),
                  TextButton(
                    onPressed: auth.isBusy
                        ? null
                        : () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.goNamed(Routes.login);
                            }
                          },
                    child: const Text('Sign in'),
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

class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.label,
    required this.autofillHint,
    required this.enabled,
  });

  final TextEditingController controller;
  final String label;
  final String autofillHint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AuthField(
      controller: controller,
      enabled: enabled,
      label: label,
      // No leading icon: these two sit side by side on a phone, and a pair of
      // icons costs width the names themselves need.
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      autofillHints: [autofillHint],
      validator: (value) => (value?.trim().isEmpty ?? true) ? 'Required' : null,
    );
  }
}
