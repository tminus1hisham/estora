import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/async_button.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/mock/mock_server.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Section 72's OTP step.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  Timer? _resendTimer;
  int _resendIn = 30;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    // On success the router redirects to the home tab.
    await ref.read(authControllerProvider.notifier).verifyOtp(
      _controller.text.trim(),
    );
  }

  Future<void> _resend() async {
    final phone = ref.read(authControllerProvider).pendingPhone;
    if (phone == null) return;
    final sent = await ref
        .read(authControllerProvider.notifier)
        .requestOtp(phone);
    if (sent) _startResendCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final phone = auth.pendingPhone ?? 'your phone';

    return AuthScaffold(
      title: 'Enter your code',
      subtitle: 'We sent a six-digit code to $phone.',
      failure: auth.failure,
      onDismissFailure: ref.read(authControllerProvider.notifier).clearFailure,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofocus: true,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 12,
            ),
            decoration: const InputDecoration(counterText: ''),
            onChanged: (value) {
              // Submit automatically once the code is complete — nobody wants
              // to tap a button after typing six digits.
              if (value.length == 6) _verify();
            },
          ),
          Gap.h16,
          AsyncButton(
            label: 'Verify',
            enabled: !auth.isBusy,
            onPressed: _verify,
          ),
          Gap.h12,
          Center(
            child: _resendIn > 0
                ? Text(
                    'Resend code in ${_resendIn}s',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : TextButton(
                    onPressed: _resend,
                    child: const Text('Resend code'),
                  ),
          ),
          if (AppConfig.isMock) ...[
            Gap.h24,
            _DemoHint(code: MockServer.demoOtp),
          ],
        ],
      ),
    );
  }
}

/// Visible only against the mock data source, where there is no SMS gateway to
/// deliver a real code.
class _DemoHint extends StatelessWidget {
  const _DemoHint({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: scheme.primary),
          Gap.w12,
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Demo mode — no SMS is sent. Use code '),
                  TextSpan(
                    text: code,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
