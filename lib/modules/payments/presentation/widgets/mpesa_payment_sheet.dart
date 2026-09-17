import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/app_success_mark.dart';
import '../../../../components/async_button.dart';
import '../../../../components/country_code_field.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../domain/entities/billing.dart';
import '../../../auth/application/auth_controller.dart';

/// What a "Pay now" is collecting for, and how to collect it.
///
/// The sheet is the same whether the thing being paid is a booking fee or an
/// invoice; only the record behind it differs. So the record's owner supplies
/// the three things the sheet cannot know — how to raise the prompt, how to
/// re-read the record, how to start over — and the sheet supplies the form,
/// the waiting state and the confirmation.
class MpesaPaymentRequest {
  const MpesaPaymentRequest({
    required this.title,
    required this.amount,
    required this.send,
    required this.confirmPaid,
    required this.restart,
    this.subtitle,
    this.phoneNumber,
  });

  /// What is being paid: "Booking fee", or an invoice number.
  final String title;

  /// Where it comes from: "Unit 12 · Grace Mall".
  final String? subtitle;

  /// The server's figure, shown and sent back unchanged.
  final Money amount;

  /// A number to offer first. The applicant's on a booking; the account's
  /// when there is nothing better.
  final String? phoneNumber;

  /// Raises the prompt on [phoneNumber], already in the `2547…` form.
  final Future<Result<PaymentPrompt>> Function(String phoneNumber) send;

  /// Re-reads the record and says whether the server now holds the money.
  /// `false` is "not yet", never "failed".
  final Future<Result<bool>> Function() confirmPaid;

  /// The tenant wants a fresh prompt. Whatever made the last one a single
  /// intent is let go before [send] is called again.
  final Future<void> Function() restart;
}

/// Opens the M-Pesa sheet and resolves to `true` once the server has
/// confirmed the payment, `false` or null when the tenant left before then.
///
/// Leaving is always allowed: the prompt is on the handset, not in this
/// sheet, and a tenant who closes it mid-payment has lost nothing. The
/// record they came from re-reads itself the next time it is opened.
Future<bool?> showMpesaPaymentSheet(
  BuildContext context,
  MpesaPaymentRequest request,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => MpesaPaymentSheet(request: request),
  );
}

/// The sheet behind every "Pay now" in the app.
///
/// Three states, in the order a payment happens: the handset to prompt, the
/// prompt being answered on that handset, and the server's word that the
/// money landed. The middle one is the honest one — this app never marks a
/// payment successful on its own (section 39). It asks the server, and it
/// shows what it is told.
class MpesaPaymentSheet extends ConsumerStatefulWidget {
  const MpesaPaymentSheet({required this.request, super.key});

  final MpesaPaymentRequest request;

  @override
  ConsumerState<MpesaPaymentSheet> createState() => _MpesaPaymentSheetState();
}

enum _Stage { form, sent, paid }

class _MpesaPaymentSheetState extends ConsumerState<MpesaPaymentSheet> {
  _Stage _stage = _Stage.form;
  PaymentPrompt? _prompt;

  late final TextEditingController _phoneController;

  /// The code the number is dialling on, read off whichever number seeded
  /// the field; Kenya when there is nothing to read.
  late Country _country;

  @override
  void initState() {
    super.initState();
    final seed =
        widget.request.phoneNumber ??
        ref.read(authControllerProvider).user?.phone;
    _country = PhoneNumber.countryOf(seed) ?? Countries.fallback;
    _phoneController = TextEditingController(
      text: PhoneNumber.nationalOf(seed),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// The handset the prompt goes to, as the gateway needs it written.
  String get _phoneNumber =>
      PhoneNumber.normalize(_phoneController.text, country: _country);

  bool get _canSend =>
      PhoneNumber.isValid(_phoneController.text, country: _country);

  Future<void> _send() async {
    final result = await widget.request.send(_phoneNumber);
    if (!mounted) return;

    switch (result) {
      case Ok(:final value):
        setState(() {
          _prompt = value;
          _stage = _Stage.sent;
        });
      case Err(:final failure):
        _notice(failure.message);
    }
  }

  Future<void> _check() async {
    final result = await widget.request.confirmPaid();
    if (!mounted) return;

    switch (result) {
      case Ok(value: true):
        setState(() => _stage = _Stage.paid);
      case Ok():
        _notice(
          'Not confirmed yet. If you have entered your PIN, give it a moment '
          'and check again.',
        );
      case Err(:final failure):
        _notice(failure.message);
    }
  }

  Future<void> _sendAgain() async {
    await widget.request.restart();
    if (!mounted) return;
    setState(() {
      _prompt = null;
      _stage = _Stage.form;
    });
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The keyboard rises under the sheet; the padding lifts the field above
    // it so what is being typed stays in view.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: AppMotion.fast,
      curve: AppMotion.enter,
      padding: EdgeInsets.only(bottom: keyboard),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.maxFormWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                switchInCurve: AppMotion.enter,
                switchOutCurve: AppMotion.exit,
                child: switch (_stage) {
                  _Stage.form => _Form(
                    key: const ValueKey('form'),
                    request: widget.request,
                    phoneController: _phoneController,
                    country: _country,
                    onCountryChanged: (country) =>
                        setState(() => _country = country),
                    onChanged: () => setState(() {}),
                    canSend: _canSend,
                    onSend: _send,
                  ),
                  _Stage.sent => _Sent(
                    key: const ValueKey('sent'),
                    request: widget.request,
                    prompt: _prompt!,
                    onCheck: _check,
                    onSendAgain: _sendAgain,
                    onLater: () => Navigator.of(context).pop(false),
                  ),
                  _Stage.paid => _Paid(
                    key: const ValueKey('paid'),
                    request: widget.request,
                    onDone: () => Navigator.of(context).pop(true),
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The figure and what it is for, at the top of every stage.
///
/// The one figure the sheet exists to collect, so it takes the hero scale —
/// size carries it, not weight. It is the server's number, not editable, and
/// not assembled here.
class _AmountBlock extends StatelessWidget {
  const _AmountBlock({required this.request});

  final MpesaPaymentRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.xl),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: AppRadius.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AMOUNT DUE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: AppTypography.extraBold,
              letterSpacing: 0.8,
            ),
          ),
          Gap.h8,
          AmountText(request.amount, scale: AmountScale.hero),
          Gap.h12,
          Text(
            [request.title, ?request.subtitle].join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.request,
    required this.phoneController,
    required this.country,
    required this.onCountryChanged,
    required this.onChanged,
    required this.canSend,
    required this.onSend,
    super.key,
  });

  final MpesaPaymentRequest request;
  final TextEditingController phoneController;
  final Country country;
  final ValueChanged<Country> onCountryChanged;
  final VoidCallback onChanged;
  final bool canSend;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Pay with M-Pesa',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: AppTypography.bold,
          ),
        ),
        Gap.h4,
        Text(
          'We will send a prompt to your phone. Enter your M-Pesa PIN there '
          'to pay.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Gap.h16,
        _AmountBlock(request: request),
        Gap.h16,
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          autofocus: phoneController.text.isEmpty,
          onChanged: (_) => onChanged(),
          onSubmitted: canSend ? (_) => onSend() : null,
          decoration: InputDecoration(
            labelText: 'M-Pesa number',
            hintText: country.example,
            prefixIcon: CountryCodeField(
              value: country,
              onChanged: onCountryChanged,
            ),
            prefixIconConstraints: CountryCodeField.constraints,
            helperText: 'The prompt is sent to this number',
          ),
        ),
        Gap.h16,
        Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: AppRadius.small,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              Gap.w12,
              Expanded(
                child: Text(
                  // Section 39, in plain language: the app does not get to
                  // decide the payment worked.
                  'Your payment is confirmed by M-Pesa and verified by us '
                  'before it is marked as paid.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        Gap.h24,
        AsyncButton(
          label: 'Send M-Pesa prompt',
          icon: Icons.phone_android_rounded,
          expand: true,
          enabled: canSend,
          onPressed: onSend,
        ),
      ],
    );
  }
}

/// The prompt is on the handset. Nothing here can hurry it, and nothing here
/// can tell how it went: the one button that matters asks the server.
class _Sent extends StatelessWidget {
  const _Sent({
    required this.request,
    required this.prompt,
    required this.onCheck,
    required this.onSendAgain,
    required this.onLater,
    super.key,
  });

  final MpesaPaymentRequest request;
  final PaymentPrompt prompt;
  final Future<void> Function() onCheck;
  final Future<void> Function() onSendAgain;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = context.statusColors.progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Gap.h8,
        Center(
          child: Container(
            height: 68,
            width: 68,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.phone_android_rounded, size: 34, color: color),
          ),
        ),
        Gap.h16,
        Text(
          'Check your phone',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: AppTypography.bold,
          ),
        ),
        Gap.h8,
        Text(
          // The server's own words when it gave any; otherwise the number and
          // the figure, which is what a tenant looking at their handset wants
          // to see matched.
          prompt.message ??
              'We have sent an M-Pesa prompt to '
                  '${PhoneNumber.display(prompt.phoneNumber)}. Enter your PIN '
                  'to pay ${prompt.amount.format()}.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Gap.h16,
        _AmountBlock(request: request),
        Gap.h24,
        AsyncButton(
          label: 'I have paid — check status',
          icon: Icons.refresh_rounded,
          expand: true,
          onPressed: onCheck,
        ),
        Gap.h8,
        AsyncButton(
          label: 'Send the prompt again',
          tonal: true,
          expand: true,
          onPressed: onSendAgain,
        ),
        Gap.h4,
        TextButton(onPressed: onLater, child: const Text('I will check later')),
      ],
    );
  }
}

/// Drawn only once the server has reported the money landed. This is the one
/// celebratory moment in the flow, and it is the server's to grant.
class _Paid extends StatelessWidget {
  const _Paid({required this.request, required this.onDone, super.key});

  final MpesaPaymentRequest request;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = context.statusColors.positive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Gap.h8,
        Center(child: AppSuccessMark(color: color)),
        Gap.h16,
        Text(
          'Payment received',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: AppTypography.bold,
          ),
        ),
        Gap.h8,
        Text(
          'Thank you. ${request.amount.format()} has been received for '
          '${request.title.toLowerCase()}.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Gap.h24,
        FilledButton(
          onPressed: onDone,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppLayout.controlHeight),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
