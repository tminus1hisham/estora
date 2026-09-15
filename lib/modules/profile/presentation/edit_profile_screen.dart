import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/async_button.dart';
import '../../../components/country_code_field.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_number.dart';
import '../../../domain/entities/tenant.dart';
import '../../../services/providers.dart';
import '../../auth/application/auth_controller.dart';

/// Section 20's tenant profile, edited by the tenant.
///
/// Which fields appear depends on the tenant type: a business is asked for a
/// legal name, registration number and contact person; an individual is not.
///
/// Identity numbers already on file are shown masked on the profile screen and
/// are deliberately not editable here — changing a national ID that a lease was
/// issued against is a support matter with an audit trail (section 52), not a
/// self-service form field.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _legalName;
  late final TextEditingController _registrationNumber;
  late final TextEditingController _taxNumber;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _contactPerson;
  late final TextEditingController _contactPersonPhone;

  /// A code per number, each read off the number already on file so an
  /// existing entry comes back exactly as it was saved.
  late Country _phoneCountry;
  late Country _contactPersonPhoneCountry;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authControllerProvider).tenant?.profile;
    _legalName = TextEditingController(text: profile?.legalName ?? '');
    _registrationNumber = TextEditingController(
      text: profile?.registrationNumber ?? '',
    );
    _taxNumber = TextEditingController(text: profile?.taxNumber ?? '');
    _email = TextEditingController(text: profile?.email ?? '');
    _phoneCountry = PhoneNumber.countryOf(profile?.phone) ?? Countries.fallback;
    _phone = TextEditingController(
      text: PhoneNumber.nationalOf(profile?.phone),
    );
    _address = TextEditingController(text: profile?.address ?? '');
    _contactPerson = TextEditingController(text: profile?.contactPerson ?? '');
    _contactPersonPhoneCountry =
        PhoneNumber.countryOf(profile?.contactPersonPhone) ??
        Countries.fallback;
    _contactPersonPhone = TextEditingController(
      text: PhoneNumber.nationalOf(profile?.contactPersonPhone),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _legalName,
      _registrationNumber,
      _taxNumber,
      _email,
      _phone,
      _address,
      _contactPerson,
      _contactPersonPhone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final tenant = ref.read(authControllerProvider).tenant;
    if (tenant == null) return;

    setState(() => _saving = true);

    final existing = tenant.profile;
    final result = await ref
        .read(tenantRepositoryProvider)
        .updateProfile(
          TenantProfile(
            tenantId: tenant.id,
            legalName: _textOrNull(_legalName),
            registrationNumber: _textOrNull(_registrationNumber),
            taxNumber: _textOrNull(_taxNumber),
            // Carried through untouched — see the class doc.
            nationalId: existing?.nationalId,
            passportNumber: existing?.passportNumber,
            email: _textOrNull(_email),
            phone: _phoneOrNull(_phone, _phoneCountry),
            address: _textOrNull(_address),
            contactPerson: _textOrNull(_contactPerson),
            contactPersonPhone: _phoneOrNull(
              _contactPersonPhone,
              _contactPersonPhoneCountry,
            ),
          ),
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isErr) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.failureOrNull!.message)));
      return;
    }

    // Re-read the session so the profile screen reflects the change.
    await ref.read(authControllerProvider.notifier).restore();
    if (mounted) context.pop();
  }

  String? _textOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  /// A number joined to the code it was typed under. Both phone fields are
  /// optional, so an empty one stays absent rather than becoming a bare
  /// dialling code.
  String? _phoneOrNull(TextEditingController controller, Country country) {
    final text = controller.text.trim();
    return text.isEmpty ? null : PhoneNumber.normalize(text, country: country);
  }

  /// Optional, so blank passes; anything typed has to be a number the country
  /// on the selector actually issues.
  String? _validateOptionalPhone(String? value, Country country) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return PhoneNumber.isValid(text, country: country)
        ? null
        : 'Enter a valid ${country.name} number';
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(authControllerProvider).tenant;
    final isOrganisation = tenant?.tenantType.isOrganisation ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: AppRefreshIndicator(
        onRefresh: () async {
          await ref.read(authControllerProvider.notifier).refreshProfile();
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
            children: [
              if (isOrganisation) ...[
                TextFormField(
                  controller: _legalName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Legal name'),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Required' : null,
                ),
                Gap.h12,
                TextFormField(
                  controller: _registrationNumber,
                  decoration: const InputDecoration(
                    labelText: 'Registration number',
                  ),
                ),
                Gap.h12,
                TextFormField(
                  controller: _taxNumber,
                  decoration: const InputDecoration(labelText: 'Tax number'),
                ),
                Gap.h12,
              ],

              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email address'),
                validator: (v) {
                  final text = v?.trim() ?? '';
                  if (text.isEmpty) return null;
                  return text.contains('@') ? null : 'Enter a valid email';
                },
              ),
              Gap.h12,
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
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
                validator: (value) =>
                    _validateOptionalPhone(value, _phoneCountry),
              ),
              Gap.h12,
              TextFormField(
                controller: _address,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Postal address'),
              ),

              if (isOrganisation) ...[
                Gap.h12,
                TextFormField(
                  controller: _contactPerson,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Contact person',
                  ),
                ),
                Gap.h12,
                TextFormField(
                  controller: _contactPersonPhone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Contact person phone',
                    hintText: _contactPersonPhoneCountry.example,
                    prefixIcon: CountryCodeField(
                      value: _contactPersonPhoneCountry,
                      onChanged: (country) =>
                          setState(() => _contactPersonPhoneCountry = country),
                    ),
                    prefixIconConstraints: CountryCodeField.constraints,
                  ),
                  validator: (value) =>
                      _validateOptionalPhone(value, _contactPersonPhoneCountry),
                ),
              ],

              Gap.h24,
              AsyncButton(
                label: 'Save changes',
                enabled: !_saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
