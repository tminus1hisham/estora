import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/async_button.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../navigation/routes.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Section 77's Register screen.
///
/// Collects only what is needed to create the account. The fuller tenant
/// profile from section 20 — registration number, tax number, address — is
/// captured later, on the profile screen, so a first-time visitor browsing
/// units is not asked for company paperwork before they have seen anything.
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

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Browse available spaces, book a unit and manage your lease.',
      failure: auth.failure,
      onDismissFailure: ref.read(authControllerProvider.notifier).clearFailure,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<TenantType>(
              segments: const [
                ButtonSegment(
                  value: TenantType.individual,
                  label: Text('Individual'),
                  icon: Icon(Icons.person_outline_rounded),
                ),
                ButtonSegment(
                  value: TenantType.business,
                  label: Text('Business'),
                  icon: Icon(Icons.business_outlined),
                ),
              ],
              selected: {_tenantType},
              onSelectionChanged: (selection) =>
                  setState(() => _tenantType = selection.first),
            ),
            Gap.h16,
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'First name'),
                    validator: (v) =>
                        (v?.trim().isEmpty ?? true) ? 'Required' : null,
                  ),
                ),
                Gap.w12,
                Expanded(
                  child: TextFormField(
                    controller: _lastName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Last name'),
                    validator: (v) =>
                        (v?.trim().isEmpty ?? true) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            Gap.h12,
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
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
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (v) => (v?.trim().contains('@') ?? false)
                  ? null
                  : 'Enter a valid email address',
            ),
            Gap.h12,
            TextFormField(
              controller: _password,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
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
                final text = value ?? '';
                if (text.length < 8) {
                  return 'Use at least 8 characters';
                }
                return null;
              },
            ),
            Gap.h8,
            CheckboxListTile(
              value: _acceptedTerms,
              onChanged: (value) =>
                  setState(() => _acceptedTerms = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I agree to the terms of use and privacy policy',
                style: TextStyle(fontSize: 13),
              ),
            ),
            Gap.h8,
            AsyncButton(
              label: 'Create account',
              enabled: !auth.isBusy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
