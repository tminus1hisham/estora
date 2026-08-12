import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_surface_card.dart';
import '../../../components/async_button.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/mock/mock_server.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Verifies the six-digit code sent to the pending phone number.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _resendTimer;
  int _resendIn = 30;
  bool _showCodeError = false;

  @override
  void initState() {
    super.initState();
    _startResendCountdown(notify: false);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startResendCountdown({bool notify = true}) {
    _resendTimer?.cancel();
    if (notify && mounted) {
      setState(() => _resendIn = 30);
    } else {
      _resendIn = 30;
    }
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    if (_controller.text.length != 6) {
      setState(() => _showCodeError = true);
      _focusNode.requestFocus();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(_controller.text.trim());
  }

  Future<void> _resend() async {
    final phone = ref.read(authControllerProvider).pendingPhone;
    if (phone == null) return;
    final sent = await ref
        .read(authControllerProvider.notifier)
        .requestOtp(phone);
    if (sent && mounted) _startResendCountdown();
  }

  void _onCodeChanged(String value) {
    setState(() => _showCodeError = false);
    if (value.length == 6 && !ref.read(authControllerProvider).isBusy) {
      _verify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final phone = auth.pendingPhone ?? 'your phone';
    final scheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      eyebrow: 'Secure verification',
      title: 'Enter your code',
      subtitle: 'We sent a six-digit code to $phone.',
      failure: auth.failure,
      onDismissFailure: ref.read(authControllerProvider.notifier).clearFailure,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OtpInput(
            controller: _controller,
            focusNode: _focusNode,
            enabled: !auth.isBusy,
            hasError: _showCodeError,
            onChanged: _onCodeChanged,
          ),
          if (_showCodeError) ...[
            Gap.h8,
            Text(
              'Enter all six digits.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
          Gap.h24,
          AsyncButton(
            label: 'Verify and continue',
            loadingLabel: 'Verifying your code',
            icon: Icons.arrow_forward_rounded,
            expand: true,
            enabled: !auth.isBusy,
            onPressed: _verify,
          ),
          Gap.h12,
          Center(
            child: _resendIn > 0
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                    child: Text(
                      'You can request a new code in ${_resendIn}s',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : TextButton.icon(
                    onPressed: auth.isBusy ? null : _resend,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Send a new code'),
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

class _OtpInput extends StatelessWidget {
  const _OtpInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hasError,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Six-digit verification code',
      textField: true,
      child: GestureDetector(
        onTap: enabled ? focusNode.requestFocus : null,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([controller, focusNode]),
              builder: (context, _) {
                final digits = controller.text;
                return Row(
                  children: List.generate(6, (index) {
                    final active = focusNode.hasFocus && digits.length == index;
                    final filled = digits.length > index;
                    final borderColor = hasError
                        ? scheme.error
                        : active
                        ? scheme.primary
                        : scheme.outlineVariant;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
                        child: AnimatedContainer(
                          duration: AppMotion.fast,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: filled
                                ? scheme.primaryContainer.withValues(
                                    alpha: 0.48,
                                  )
                                : scheme.surfaceContainerLow,
                            borderRadius: AppRadius.small,
                            border: Border.all(
                              color: borderColor,
                              width: active || hasError ? 1.6 : 1,
                            ),
                          ),
                          child: MediaQuery.withClampedTextScaling(
                            maxScaleFactor: 1.35,
                            child: Text(
                              filled ? digits[index] : '',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: AppTypography.extraBold,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.01,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  autofocus: true,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(counterText: ''),
                  onChanged: onChanged,
                  onSubmitted: (_) => onChanged(controller.text),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Visible only against the mock data source, where no SMS gateway is present.
class _DemoHint extends StatelessWidget {
  const _DemoHint({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppSurfaceCard(
      color: scheme.tertiaryContainer.withValues(alpha: 0.5),
      borderColor: scheme.tertiary.withValues(alpha: 0.22),
      borderRadius: AppRadius.small,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, size: 19, color: scheme.tertiary),
          Gap.w12,
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Demo mode · use code '),
                  TextSpan(
                    text: code,
                    style: const TextStyle(fontWeight: AppTypography.extraBold),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
