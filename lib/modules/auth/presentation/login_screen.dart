import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../navigation/routes.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_method_switch.dart';
import 'widgets/auth_page.dart';
import 'widgets/auth_stage.dart';
import 'widgets/demo_accounts.dart';
import '../../../services/providers.dart';

/// The first thing anyone sees of this app.
///
/// It is built as one image and one object: a commercial frontage at dusk
/// running edge to edge under the status bar, and a plate of frosted glass
/// carrying the two fields that stand between a tenant and their account.
/// Everything else — the invitation to register, the promise about
/// encryption — is arranged around that object rather than stacked into a
/// form. [AuthPage] owns that arrangement; this screen owns what goes in it.
///
/// A phone number and a password is what signs a tenant in: it is the pair the
/// contract keys on. An email address with the same password stays available
/// for accounts that are listed by address rather than by number.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginMethod { phone, email }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  // A password per identifier rather than one shared between them: both forms
  // are mounted while the switcher crossfades, and a single controller would
  // put two live fields on the same text.
  final _phonePasswordController = TextEditingController();
  final _emailPasswordController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();
  final _emailFormKey = GlobalKey<FormState>();
  _LoginMethod _method = _LoginMethod.phone;
  bool _obscurePassword = true;

  /// Which demo account is signing in, so its tile can say so.
  String? _pendingDemoEmail;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _phonePasswordController.dispose();
    _emailPasswordController.dispose();
    super.dispose();
  }

  /// Signs in with whichever identifier the visible form asks for.
  ///
  /// Only that form is validated and only its two controllers are read, so the
  /// method on screen is the one that decides what goes to the server.
  Future<void> _signIn() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final byPhone = _method == _LoginMethod.phone;
    final form = byPhone ? _phoneFormKey : _emailFormKey;
    if (!(form.currentState?.validate() ?? false)) return;
    await ref
        .read(authControllerProvider.notifier)
        .loginWithPassword(
          (byPhone ? _phoneController : _emailController).text.trim(),
          (byPhone ? _phonePasswordController : _emailPasswordController).text,
        );
  }

  void _changeMethod(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _method = _LoginMethod.values[index]);
  }

  /// Signs in as one of the seeded accounts.
  ///
  /// Goes through the same password path a real sign-in uses rather than
  /// reaching into the mock, so the account that ends up signed in is decided
  /// by the server exactly as it would be otherwise. The router then takes it
  /// to whichever shell the role belongs to.
  Future<void> _useDemoAccount(DemoAccount account) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _pendingDemoEmail = account.email);
    await ref
        .read(authControllerProvider.notifier)
        .loginWithPassword(account.email, 'demo-password');
    // On success the router replaces this screen, so the state is only worth
    // clearing when the sign-in came back and we are still here.
    if (mounted) setState(() => _pendingDemoEmail = null);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return AuthPage(
      title: 'Welcome back',
      subtitle: 'Your spaces, invoices and leases in one secure place.',
      // Nowhere to go back to: this is where the app starts.
      showBackButton: false,
      showBrandMark: false,
      failure: auth.failure,
      onDismissFailure: ref.read(authControllerProvider.notifier).clearFailure,
      trustPoints: const [
        AuthTrustPoint(
          icon: Icons.verified_user_outlined,
          label: 'Secure tenant access, protected end to end',
        ),
        AuthTrustPoint(
          icon: Icons.receipt_long_outlined,
          label: 'Invoices, receipts and payments in one ledger',
        ),
        AuthTrustPoint(
          icon: Icons.draw_outlined,
          label: 'Review and sign your lease from anywhere',
        ),
      ],
      console: _console(auth),
      footer: _footer(auth),
    );
  }

  Widget _console(AuthState auth) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthMethodSwitch(
            selectedIndex: _method.index,
            enabled: !auth.isBusy,
            onChanged: _changeMethod,
            options: const [
              AuthMethodOption(label: 'Phone', icon: Icons.phone_outlined),
              AuthMethodOption(
                label: 'Email',
                icon: Icons.mail_outline_rounded,
              ),
            ],
          ),
          Gap.h24,
          AnimatedSwitcher(
            duration: AppMotion.standard,
            switchInCurve: AppMotion.enter,
            switchOutCurve: AppMotion.exit,
            // The two forms are different heights, so they have to overlap
            // while one replaces the other rather than reflow the column.
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.topCenter,
              children: [...previousChildren, ?currentChild],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
            ),
            child: _method == _LoginMethod.phone
                ? _phoneForm(auth)
                : _emailForm(auth),
          ),
        ],
      ),
    );
  }

  Widget _phoneForm(AuthState auth) {
    return _credentialsForm(
      auth: auth,
      method: _LoginMethod.phone,
      formKey: _phoneFormKey,
      passwordController: _phonePasswordController,
      identifier: AuthField(
        controller: _phoneController,
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
    );
  }

  Widget _emailForm(AuthState auth) {
    return _credentialsForm(
      auth: auth,
      method: _LoginMethod.email,
      formKey: _emailFormKey,
      passwordController: _emailPasswordController,
      identifier: AuthField(
        controller: _emailController,
        enabled: !auth.isBusy,
        label: 'Email address',
        icon: Icons.mail_outline_rounded,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.username, AutofillHints.email],
        autocorrect: false,
        validator: (value) => (value?.trim().contains('@') ?? false)
            ? null
            : 'Enter a valid email address',
      ),
    );
  }

  /// Sign-in as it stands for either method: an identifier, the password that
  /// goes with it, and one way out if the password has been forgotten.
  ///
  /// Both methods send the same pair to the same endpoint and differ only in
  /// the field on top, so this is one form built twice rather than two forms
  /// kept in step by hand.
  Widget _credentialsForm({
    required AuthState auth,
    required _LoginMethod method,
    required GlobalKey<FormState> formKey,
    required TextEditingController passwordController,
    required Widget identifier,
  }) {
    return Form(
      key: formKey,
      child: Column(
        key: ValueKey(method),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          identifier,
          Gap.h12,
          AuthField(
            controller: passwordController,
            enabled: !auth.isBusy,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
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
            validator: (value) =>
                (value?.isEmpty ?? true) ? 'Enter your password' : null,
            onSubmitted: (_) => _signIn(),
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
          AuthPrimaryAction(
            label: 'Sign in',
            loadingLabel: 'Signing you in',
            icon: Icons.login_rounded,
            enabled: !auth.isBusy,
            onPressed: _signIn,
          ),
        ],
      ),
    );
  }

  Widget _footer(AuthState auth) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The demo's front door. An account carries one role and the router
        // sends it to the matching shell, so this is how you move between the
        // tenant and the owner experience — there is nothing to toggle.
        if (ref.watch(isMockDataProvider)) ...[
          DemoAccounts(
            enabled: !auth.isBusy,
            pendingEmail: _pendingDemoEmail,
            onSelected: _useDemoAccount,
          ),
          Gap.h32,
        ],
        Row(
          children: [
            // The rules take a single share each and the label takes five.
            // Given equal flex they would squeeze twenty-one characters into a
            // third of a phone's width, which is how a one-line caption
            // becomes three lines.
            const Expanded(child: Divider()),
            Flexible(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                child: Text(
                  'NEW TO TENANT PORTAL?',
                  textAlign: TextAlign.center,
                  style: textTheme.labelSmall?.copyWith(
                    color: kAuthOnDark.withValues(alpha: 0.55),
                    letterSpacing: 0.9,
                  ),
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        Gap.h16,
        AuthGhostButton(
          label: 'Create an account',
          icon: Icons.person_add_alt_1_outlined,
          onPressed: auth.isBusy
              ? null
              : () => context.pushNamed(Routes.register),
        ),
        Gap.h24,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 15,
              color: kAuthOnDark.withValues(alpha: 0.55),
            ),
            Gap.w8,
            Flexible(
              child: Text(
                'Your details are encrypted and kept private.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: kAuthOnDark.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
