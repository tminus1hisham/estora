import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_bottom_action_bar.dart';
import '../../../components/app_refresh_indicator.dart';
import '../../../components/async_button.dart';
import '../../../components/country_code_field.dart';
import '../../../components/page_header.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_number.dart';
import '../../../domain/entities/access.dart';
import '../../auth/application/auth_controller.dart';
import '../application/account_controller.dart';

/// The name, email and phone on the signed-in account, edited by its owner.
///
/// This is the account record itself, not the tenant profile, so it serves
/// both sides of the platform: a tenant and a manager reach it from the same
/// security screen. It lives on the root navigator next to change-password
/// for that reason — the tenant profile editor sits inside the tenant shell,
/// which a manager is redirected out of.
class EditContactScreen extends ConsumerStatefulWidget {
  const EditContactScreen({super.key});

  @override
  ConsumerState<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends ConsumerState<EditContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  Country _phoneCountry = Countries.fallback;

  /// Which account the fields were last filled from, so a refresh that
  /// returns the same record does not wipe what is being typed.
  String? _filledFrom;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _fill(PlatformUser account) {
    if (_filledFrom == account.id) return;
    _filledFrom = account.id;
    _name.text = account.fullName;
    _email.text = account.emailAddress ?? '';
    _phoneCountry =
        PhoneNumber.countryOf(account.phoneNumber) ?? Countries.fallback;
    _phone.text = PhoneNumber.nationalOf(account.phoneNumber);
  }

  Future<void> _save(PlatformUser account) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await ref
        .read(accountActionsProvider)
        .updateAccount(
          userId: account.id,
          fullName: _name.text.trim(),
          emailAddress: _email.text.trim(),
          phoneNumber: PhoneNumber.normalize(
            _phone.text.trim(),
            country: _phoneCountry,
          ),
        );

    if (!mounted) return;

    switch (result) {
      case Ok():
        // The profile screen reads the session's copy of the user, which the
        // account provider does not refresh.
        await ref
            .read(authControllerProvider.notifier)
            .refreshProfile()
            .catchError((_) {});
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact details saved.'),
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
    if (account.hasValue) _fill(account.requireValue);

    return Scaffold(
      appBar: AppBar(title: const Text('Contact details')),
      body: AppRefreshIndicator(
        onRefresh: () async {
          await ref.refresh(myAccountProvider.future).then<void>((_) {});
        },
        child: switch (account) {
          AsyncLoading() when !account.hasValue => const LoadingView(),
          AsyncError(:final error) => ErrorView(
            failure: error is Failure
                ? error
                : UnknownFailure(error.toString()),
            onRetry: () async {
              await ref.refresh(myAccountProvider.future).then<void>((_) {});
            },
          ),
          _ => _form(),
        },
      ),
      bottomNavigationBar: account.hasValue
          ? AppBottomActionBar(
              child: AsyncButton(
                label: 'Save',
                icon: Icons.check_rounded,
                expand: true,
                onPressed: () => _save(account.requireValue),
              ),
            )
          : null,
    );
  }

  Widget _form() {
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
              const PageHeader(
                title: 'How we reach you',
                subtitle:
                    'Used for payment notices and for resetting your password.',
                compact: true,
              ),
              Gap.h16,
              SectionCard(
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter your name'
                        : null,
                  ),
                  Gap.h12,
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Enter your email address';
                      return text.contains('@') ? null : 'Enter a valid email';
                    },
                  ),
                  Gap.h12,
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: InputDecoration(
                      labelText: 'Phone number',
                      hintText: _phoneCountry.example,
                      prefixIcon: CountryCodeField(
                        value: _phoneCountry,
                        onChanged: (country) =>
                            setState(() => _phoneCountry = country),
                      ),
                      prefixIconConstraints: CountryCodeField.constraints,
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Enter your phone number';
                      return PhoneNumber.isValid(text, country: _phoneCountry)
                          ? null
                          : 'Enter a valid ${_phoneCountry.name} number';
                    },
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
