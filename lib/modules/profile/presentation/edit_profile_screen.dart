import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/async_button.dart';
import '../../../core/theme/app_theme.dart';
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
    _phone = TextEditingController(text: profile?.phone ?? '');
    _address = TextEditingController(text: profile?.address ?? '');
    _contactPerson = TextEditingController(text: profile?.contactPerson ?? '');
    _contactPersonPhone = TextEditingController(
      text: profile?.contactPersonPhone ?? '',
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
            phone: _textOrNull(_phone),
            address: _textOrNull(_address),
            contactPerson: _textOrNull(_contactPerson),
            contactPersonPhone: _textOrNull(_contactPersonPhone),
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

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(authControllerProvider).tenant;
    final isOrganisation = tenant?.tenantType.isOrganisation ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
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
              decoration: const InputDecoration(labelText: 'Phone number'),
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
                decoration: const InputDecoration(labelText: 'Contact person'),
              ),
              Gap.h12,
              TextFormField(
                controller: _contactPersonPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact person phone',
                ),
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
    );
  }
}
