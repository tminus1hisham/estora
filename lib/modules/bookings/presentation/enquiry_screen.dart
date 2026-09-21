import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_bottom_action_bar.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/async_button.dart';
import '../../../components/section_card.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_number.dart';
import '../../../domain/entities/booking.dart';
import '../../../domain/entities/unit.dart';
import '../../auth/application/auth_controller.dart';
import '../../units/application/unit_controller.dart';
import '../application/booking_controller.dart';
import 'widgets/applicant_fields.dart';

/// An enquiry about a property — the tenant's opening move.
///
/// This is what the property's main action leads to. Nothing here books,
/// prices or pays: the tenant says who they are, what they trade and what
/// they are after, and the request goes to the landlord as
/// `POST /payments/book/unit`. The server acknowledges and the rest happens
/// between the two of them. So the screen asks for exactly the contract's
/// fields and nothing it would have to guess, and the details are prefilled
/// from the signed-in account so the common case is one message and a tap.
class EnquiryScreen extends ConsumerStatefulWidget {
  const EnquiryScreen({required this.propertyId, super.key});

  final String propertyId;

  @override
  ConsumerState<EnquiryScreen> createState() => _EnquiryScreenState();
}

class _EnquiryScreenState extends ConsumerState<EnquiryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  final _companyController = TextEditingController();
  final _messageController = TextEditingController();

  /// The code the applicant's number is dialling on, read off the account's
  /// own number and Kenya when there is none.
  late Country _country;

  String? _businessType;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _country = PhoneNumber.countryOf(user?.phone) ?? Countries.fallback;
    _phoneController = TextEditingController(
      text: PhoneNumber.nationalOf(user?.phone),
    );
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check your details above before sending.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await ref
        .read(bookingActionsProvider)
        .sendEnquiry(
          PropertyEnquiry(
            propertyId: widget.propertyId,
            applicant: BookingApplicant(
              fullName: _nameController.text.trim(),
              phoneNumber: PhoneNumber.normalize(
                _phoneController.text,
                country: _country,
              ),
              email: _emailController.text.trim(),
              companyName: _companyController.text.trim(),
              businessType: _businessType,
            ),
            message: _messageController.text.trim(),
          ),
        );

    if (!mounted) return;

    switch (result) {
      case Ok(:final value):
        // Not awaited: the button is busy for as long as this future runs,
        // and the dialog should open over a settled screen, not a spinner.
        unawaited(_announce(value));
      case Err(:final failure):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  /// Says the enquiry is with the landlord, then returns to the property.
  ///
  /// A dialog rather than a snackbar: sending is the whole point of this
  /// screen, and a strip at the bottom is easy to miss under the keyboard.
  /// There is no record to go and look at afterwards — the landlord replies
  /// to the contact details given — so the way out is back to where the
  /// tenant was.
  Future<void> _announce(EnquiryReceipt receipt) async {
    final propertyName = _propertyName(ref.read(availabilityProvider));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.mark_email_read_outlined),
        title: const Text('Enquiry sent'),
        content: Text(
          'Your enquiry about ${propertyName ?? 'this property'} is with the '
          'landlord. They will reach you on the phone number or email you '
          'gave.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    context.pop();
  }

  /// The property's name as the availability engine gives it: the one
  /// route Browse reads, already read by the screen this was opened from.
  /// Null when the engine no longer lists the property.
  String? _propertyName(AsyncValue<List<UnitAvailability>> availability) =>
      availability.value
          ?.where((block) => block.propertyId == widget.propertyId)
          .firstOrNull
          ?.propertyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final availability = ref.watch(availabilityProvider);
    final propertyName = _propertyName(availability);

    return Scaffold(
      appBar: AppBar(title: const Text('Send an enquiry')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.sm,
                Gap.lg,
                Gap.xxl,
              ),
              children: [
                if (propertyName == null && availability.isLoading)
                  const AppSkeleton(height: 28, width: 220)
                else
                  Text(
                    propertyName == null
                        ? 'Ask about this property'
                        : 'Ask about $propertyName',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                Gap.h4,
                Text(
                  'Tell the landlord what you are looking for. Nothing is '
                  'booked or paid now — they will get back to you.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),

                Gap.h16,
                SectionCard(
                  title: 'About you',
                  children: [
                    Text(
                      'The landlord replies to the details given here.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Gap.h16,
                    ApplicantFields(
                      nameController: _nameController,
                      phoneController: _phoneController,
                      country: _country,
                      onCountryChanged: (country) =>
                          setState(() => _country = country),
                      emailController: _emailController,
                      companyController: _companyController,
                      businessType: _businessType,
                      onBusinessTypeChanged: (value) =>
                          setState(() => _businessType = value),
                    ),
                  ],
                ),

                Gap.h12,
                SectionCard(
                  title: 'Your enquiry',
                  children: [
                    Text(
                      'The size you need, when you want to move in, and '
                      'anything else the landlord should know.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Gap.h16,
                    TextFormField(
                      controller: _messageController,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        alignLabelWithHint: true,
                        hintText:
                            'e.g. Looking for around 480 sq ft on the ground '
                            'floor for a coffee shop, from November.',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'Say what you are looking for';
                        }
                        if (text.length < 10) {
                          return 'Give the landlord a little more to go on';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      // AppBottomActionBar keeps the height factor this screen needs: a bottom
      // navigation child receives the scaffold's full height as its upper
      // bound, and without one the bar expands to that bound and leaves almost
      // no viewport for the list above it.
      bottomNavigationBar: AppBottomActionBar(
        child: AsyncButton(
          label: 'Send enquiry',
          loadingLabel: 'Sending…',
          icon: Icons.send_outlined,
          expand: true,
          onPressed: _send,
        ),
      ),
    );
  }
}
