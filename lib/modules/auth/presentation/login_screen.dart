import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/async_button.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/routes.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Phone plus OTP is the primary flow for tenants; email and password remains
/// available for tenants with an established password.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginMethod { phone, email }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  _LoginMethod _method = _LoginMethod.phone;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;
    final sent = await ref
        .read(authControllerProvider.notifier)
        .requestOtp(_phoneController.text.trim());
    if (sent && mounted) context.pushNamed(Routes.otp);
  }

  Future<void> _signIn() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authControllerProvider.notifier)
        .loginWithPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  void _changeMethod(Set<_LoginMethod> selection) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _method = selection.first);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final useVerticalMethodSelector =
        MediaQuery.textScalerOf(context).scale(14) >= 20;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Access your spaces, invoices and lease documents securely.',
      failure: auth.failure,
      onDismissFailure: ref.read(authControllerProvider.notifier).clearFailure,
      showBackButton: false,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (useVerticalMethodSelector) ...[
              _AccessibleMethodButton(
                label: 'Phone code',
                icon: Icons.sms_outlined,
                selected: _method == _LoginMethod.phone,
                onPressed: auth.isBusy
                    ? null
                    : () => _changeMethod({_LoginMethod.phone}),
              ),
              Gap.h8,
              _AccessibleMethodButton(
                label: 'Email',
                icon: Icons.mail_outline_rounded,
                selected: _method == _LoginMethod.email,
                onPressed: auth.isBusy
                    ? null
                    : () => _changeMethod({_LoginMethod.email}),
              ),
            ] else
              SegmentedButton<_LoginMethod>(
                expandedInsets: EdgeInsets.zero,
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _LoginMethod.phone,
                    label: Text('Phone code'),
                    icon: Icon(Icons.sms_outlined),
                  ),
                  ButtonSegment(
                    value: _LoginMethod.email,
                    label: Text('Email'),
                    icon: Icon(Icons.mail_outline_rounded),
                  ),
                ],
                selected: {_method},
                onSelectionChanged: auth.isBusy ? null : _changeMethod,
              ),
            Gap.h24,
            AnimatedSwitcher(
              duration: AppMotion.standard,
              switchInCurve: AppMotion.enter,
              switchOutCurve: AppMotion.exit,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.topCenter,
                children: [...previousChildren, ?currentChild],
              ),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: child,
                ),
              ),
              child: _method == _LoginMethod.phone
                  ? _phoneForm(auth)
                  : _passwordForm(auth),
            ),
            Gap.h24,
            Row(
              children: [
                Expanded(child: Divider(color: scheme.outlineVariant)),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md,
                    ),
                    child: Text(
                      'NEW TO TENANT PORTAL?',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                Expanded(child: Divider(color: scheme.outlineVariant)),
              ],
            ),
            Gap.h16,
            OutlinedButton.icon(
              onPressed: auth.isBusy
                  ? null
                  : () => context.pushNamed(Routes.register),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 19),
              label: const Text('Create an account'),
            ),
            Gap.h16,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                Gap.w4,
                Flexible(
                  child: Text(
                    'Your details are encrypted and kept private.',
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
    );
  }

  Widget _phoneForm(AuthState auth) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        key: const ValueKey(_LoginMethod.phone),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _phoneController,
            enabled: !auth.isBusy,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
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
            onFieldSubmitted: (_) => _sendCode(),
          ),
          Gap.h8,
          Text(
            'We will text you a one-time code. Standard messaging rates may apply.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Gap.h24,
          AsyncButton(
            label: 'Continue securely',
            loadingLabel: 'Sending your code',
            icon: Icons.arrow_forward_rounded,
            expand: true,
            enabled: !auth.isBusy,
            onPressed: _sendCode,
          ),
        ],
      ),
    );
  }

  Widget _passwordForm(AuthState auth) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        key: const ValueKey(_LoginMethod.email),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            enabled: !auth.isBusy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
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
            controller: _passwordController,
            enabled: !auth.isBusy,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) =>
                (value?.isEmpty ?? true) ? 'Enter your password' : null,
            onFieldSubmitted: (_) => _signIn(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: auth.isBusy
                  ? null
                  : () => context.pushNamed(Routes.forgotPassword),
              child: const Text('Forgot password?'),
            ),
          ),
          Gap.h8,
          AsyncButton(
            label: 'Sign in',
            loadingLabel: 'Signing you in',
            icon: Icons.login_rounded,
            expand: true,
            enabled: !auth.isBusy,
            onPressed: _signIn,
          ),
        ],
      ),
    );
  }
}

class _AccessibleMethodButton extends StatelessWidget {
  const _AccessibleMethodButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Text(label, textAlign: TextAlign.center);
    return Semantics(
      selected: selected,
      child: selected
          ? FilledButton.tonalIcon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: child,
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: child,
            ),
    );
  }
}
