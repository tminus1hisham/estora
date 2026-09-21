import 'package:flutter/material.dart';

import '../../../../components/country_code_field.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../domain/entities/booking.dart';

/// The fields that name a [BookingApplicant]: who is asking, how to reach
/// them, and what they trade.
///
/// Shared by the booking and enquiry screens, because the landlord wants the
/// same things known in both cases — a letting is agreed with a named person
/// and a named trade, and an enquiry is the start of one. The caller owns the
/// controllers and wraps this in a [Form], so the fields outlive a rebuild
/// and validate with whatever else the screen asks.
class ApplicantFields extends StatelessWidget {
  const ApplicantFields({
    required this.nameController,
    required this.phoneController,
    required this.country,
    required this.onCountryChanged,
    required this.emailController,
    required this.companyController,
    required this.businessType,
    required this.onBusinessTypeChanged,
    super.key,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final Country country;
  final ValueChanged<Country> onCountryChanged;
  final TextEditingController emailController;
  final TextEditingController companyController;
  final String? businessType;
  final ValueChanged<String?> onBusinessTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Full name',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          validator: (value) =>
              (value?.trim().isEmpty ?? true) ? 'Enter your name' : null,
        ),
        Gap.h12,
        TextFormField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Phone number',
            hintText: country.example,
            prefixIcon: CountryCodeField(
              value: country,
              onChanged: onCountryChanged,
            ),
            prefixIconConstraints: CountryCodeField.constraints,
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return 'Enter a phone number';
            // The selector says which country the digits belong to, so the
            // count they are held to is that country's own.
            return PhoneNumber.isValid(text, country: country)
                ? null
                : 'Enter a valid ${country.name} number';
          },
        ),
        Gap.h12,
        TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return 'Enter an email address';
            return text.contains('@') && text.contains('.')
                ? null
                : 'Enter a valid email address';
          },
        ),
        Gap.h12,
        TextFormField(
          controller: companyController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Trading name',
            prefixIcon: Icon(Icons.storefront_outlined),
          ),
          validator: (value) =>
              (value?.trim().isEmpty ?? true) ? 'Enter the trading name' : null,
        ),
        Gap.h12,
        DropdownButtonFormField<String>(
          initialValue: businessType,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Type of business',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: [
            for (final type in BookingApplicant.businessTypes)
              DropdownMenuItem(value: type, child: Text(type)),
          ],
          onChanged: onBusinessTypeChanged,
          validator: (value) =>
              value == null ? 'Choose what will trade from the unit' : null,
        ),
      ],
    );
  }
}
