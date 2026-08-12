import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_surface_card.dart';
import '../../../components/async_button.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../navigation/routes.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';

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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_acceptedTerms) {
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: 'Create your account',
      subtitle:
          'Tell us how you will use the space. You can add company details later.',
      failure: auth.failure,
      onDismissFailure: ref.read(authControllerProvider.notifier).clearFailure,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'I am renting as',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Gap.h8,
              SegmentedButton<TenantType>(
                expandedInsets: EdgeInsets.zero,
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: TenantType.individual,
                    label: Text('Individual'),
                  ),
                  ButtonSegment(
                    value: TenantType.business,
                    label: Text('Business'),
                  ),
                ],
                selected: {_tenantType},
                onSelectionChanged: auth.isBusy
                    ? null
                    : (selection) =>
                          setState(() => _tenantType = selection.first),
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
              TextFormField(
                controller: _phone,
                enabled: !auth.isBusy,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+254 712 345 678',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
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
              TextFormField(
                controller: _email,
                enabled: !auth.isBusy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: (value) => (value?.trim().contains('@') ?? false)
                    ? null
                    : 'Enter a valid email address',
              ),
              Gap.h12,
              TextFormField(
                controller: _password,
                enabled: !auth.isBusy,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Create password',
                  helperText: 'Use at least 8 characters.',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').length < 8) {
                    return 'Use at least 8 characters';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              Gap.h16,
              AppSurfaceCard(
                color: scheme.surfaceContainerLow,
                padding: EdgeInsets.zero,
                borderRadius: AppRadius.small,
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
                  title: const Text(
                    'I agree to the terms of use and privacy policy.',
                  ),
                ),
              ),
              Gap.h24,
              AsyncButton(
                label: 'Create account',
                loadingLabel: 'Creating your account',
                icon: Icons.arrow_forward_rounded,
                expand: true,
                enabled: !auth.isBusy,
                onPressed: _submit,
              ),
              Gap.h16,
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
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
    return TextFormField(
      controller: controller,
      enabled: enabled,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      autofillHints: [autofillHint],
      decoration: InputDecoration(labelText: label),
      validator: (value) => (value?.trim().isEmpty ?? true) ? 'Required' : null,
    );
  }
}
