import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/async_button.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/routes.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Section 72. Phone plus OTP is the primary flow for tenants; email and
/// password is offered as a secondary tab for those who prefer it.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _tabs.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;
    final sent = await ref
        .read(authControllerProvider.notifier)
        .requestOtp(_phoneController.text.trim());
    if (sent && mounted) context.pushNamed(Routes.otp);
  }

  Future<void> _signIn() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    // On success the router's redirect moves us to the home tab, so there is
    // no explicit navigation here.
    await ref
        .read(authControllerProvider.notifier)
        .loginWithPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to manage your lease, invoices and payments.',
      failure: auth.failure,
      onDismissFailure: ref.read(authControllerProvider.notifier).clearFailure,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Phone'),
              Tab(text: 'Email'),
            ],
          ),
          Gap.h24,
          SizedBox(
            height: 240,
            child: TabBarView(
              controller: _tabs,
              children: [_phoneTab(auth), _passwordTab(auth)],
            ),
          ),
          Gap.h16,
          // Wrap rather than Row: at 360-414dp, which is most phones, the
          // label and the button together exceed the available width and a
          // Row overflows.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('New here?'),
              TextButton(
                onPressed: () => context.pushNamed(Routes.register),
                child: const Text('Create an account'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _phoneTab(AuthState auth) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _phoneController,
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
            'We will send you a one-time code to confirm it is you.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Gap.h24,
          AsyncButton(
            label: 'Send code',
            icon: Icons.arrow_forward_rounded,
            enabled: !auth.isBusy,
            onPressed: _sendCode,
          ),
        ],
      ),
    );
  }

  Widget _passwordTab(AuthState auth) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
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
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
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
            validator: (value) =>
                (value?.isEmpty ?? true) ? 'Enter your password' : null,
            onFieldSubmitted: (_) => _signIn(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.pushNamed(Routes.forgotPassword),
              child: const Text('Forgot password?'),
            ),
          ),
          Gap.h8,
          AsyncButton(
            label: 'Sign in',
            enabled: !auth.isBusy,
            onPressed: _signIn,
          ),
        ],
      ),
    );
  }
}
