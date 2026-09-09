import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/amount_text.dart';
import '../../../components/app_bottom_action_bar.dart';
import '../../../components/app_stepper.dart';
import '../../../components/async_button.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/booking.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../navigation/routes.dart';
import '../../auth/application/auth_controller.dart';
import '../application/booking_controller.dart';

/// Section 77's Booking screen.
///
/// Everything financial on this screen comes from a server-issued quote. There
/// is no arithmetic here: no summing of fee and tax into a total, no
/// multiplying rent by deposit months. Section 65 puts that on the server, and
/// section 84 rule 7 makes it a rule rather than a preference — so the screen
/// renders the server's numbers and sends back no amounts at all.
///
/// What it does send is who is asking. The published contract wants the
/// applicant on the booking request rather than read off the session, and it
/// is right to: the person holding the phone is not always the person whose
/// name goes on the lease, and a landlord agreeing to let a unit is agreeing
/// to a particular trade in it. The fields are prefilled from the signed-in
/// account, so the common case stays one confirmation.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({required this.unitId, super.key});

  final String unitId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final _applicantFormKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  final _companyController = TextEditingController();

  bool _acceptedTerms = false;
  bool _forBusiness = false;
  String? _businessType;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!(_applicantFormKey.currentState?.validate() ?? false)) {
      // The details sit above the fold on a long quote. Saying only "check the
      // form" would leave someone hunting for what is wrong.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check your details above before confirming.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await ref
        .read(bookingActionsProvider)
        .createBooking(
          widget.unitId,
          applicant: BookingApplicant(
            fullName: _nameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            email: _emailController.text.trim(),
            companyName: _forBusiness ? _companyController.text.trim() : null,
            businessType: _forBusiness ? _businessType : null,
          ),
        );

    if (!mounted) return;

    switch (result) {
      case Ok(:final value):
        // Replace rather than push: coming "back" to a booking confirmation
        // screen for a booking that now exists makes no sense.
        context.pushReplacementNamed(
          Routes.bookingStatus,
          pathParameters: {'bookingId': value.id},
        );
      case Err(:final failure):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // A conflict means the unit went while this screen was open
        // (section 48). Send them back to the list rather than leaving them on
        // a quote that can no longer be acted on.
        if (failure is ConflictFailure) {
          Navigator.of(context).pop();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = ref.watch(bookingQuoteProvider(widget.unitId));

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm your booking')),
      body: switch (quote) {
        AsyncLoading() => const LoadingView(message: 'Preparing your quote…'),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(bookingQuoteProvider(widget.unitId)),
        ),
        AsyncData(:final value) => _QuoteBody(
          quote: value,
          acceptedTerms: _acceptedTerms,
          onAcceptedChanged: (v) => setState(() => _acceptedTerms = v),
          applicant: _ApplicantSection(
            formKey: _applicantFormKey,
            nameController: _nameController,
            phoneController: _phoneController,
            emailController: _emailController,
            companyController: _companyController,
            forBusiness: _forBusiness,
            businessType: _businessType,
            onForBusinessChanged: (value) => setState(() {
              _forBusiness = value;
              if (!value) _businessType = null;
            }),
            onBusinessTypeChanged: (value) =>
                setState(() => _businessType = value),
          ),
        ),
      },
      // AppBottomActionBar keeps the height factor this screen needs: a bottom
      // navigation child receives the scaffold's full height as its upper
      // bound, and without one the bar expands to that bound and leaves almost
      // no viewport for the quote list above it.
      bottomNavigationBar: quote.hasValue
          ? AppBottomActionBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PayableSummary(amount: quote.requireValue.total),
                  Gap.h12,
                  AsyncButton(
                    label: 'Confirm booking',
                    icon: Icons.lock_outline_rounded,
                    expand: true,
                    enabled: _acceptedTerms,
                    onPressed: _confirm,
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class _QuoteBody extends StatelessWidget {
  const _QuoteBody({
    required this.quote,
    required this.acceptedTerms,
    required this.onAcceptedChanged,
    required this.applicant,
  });

  final BookingQuote quote;
  final bool acceptedTerms;
  final ValueChanged<bool> onAcceptedChanged;

  /// The applicant details, built by the stateful parent so the controllers
  /// outlive a rebuild of the quote.
  final Widget applicant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxReadingWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
          children: [
            const AppStepper.horizontal(steps: _bookingSteps, currentIndex: 0),
            Gap.h24,
            Text(
              'Secure this unit',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: AppTypography.bold,
              ),
            ),
            Gap.h4,
            Text(
              'Review the server-issued quote before confirming your booking.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Gap.h16,
            SectionCard(
              title: 'To pay now',
              children: [
                DetailRow(
                  label: 'Booking fee',
                  valueWidget: AmountText(
                    quote.bookingFee,
                    align: TextAlign.end,
                  ),
                ),
                if (quote.taxAmount != null && quote.taxAmount!.isPositive)
                  DetailRow(
                    label: quote.taxLabel ?? 'Tax',
                    valueWidget: AmountText(
                      quote.taxAmount!,
                      align: TextAlign.end,
                    ),
                  ),
                const Divider(),
                DetailRow(
                  label: 'Total',
                  // The server's total, rendered as received. Set at the scale
                  // that closes a group, which is what carries the emphasis
                  // here — the row does not need to shout as well.
                  valueWidget: AmountText(
                    quote.total,
                    scale: AmountScale.title,
                    align: TextAlign.end,
                  ),
                ),
                Gap.h8,
                Container(
                  padding: const EdgeInsets.all(Gap.md),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: AppRadius.small,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
                      Gap.w12,
                      Expanded(
                        child: Text(
                          'Paying the booking fee holds this unit for '
                          '${quote.expiryHours} hours while you complete the '
                          'requirements below.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Gap.h12,
            SectionCard(
              title: 'To pay before your lease starts',
              children: [
                DetailRow(
                  label: quote.depositMonths == null
                      ? 'Security deposit'
                      : 'Security deposit (${quote.depositMonths} months)',
                  valueWidget: AmountText(
                    quote.depositAmount,
                    align: TextAlign.end,
                  ),
                ),
                Gap.h8,
                Text(
                  'Invoiced once your booking is confirmed. Refundable at the end '
                  'of your lease, less any deductions.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            Gap.h12,
            SectionCard(
              title: 'Your rent',
              children: [
                DetailRow(
                  label: 'Monthly rent',
                  valueWidget: AmountText(
                    quote.monthlyRent,
                    scale: AmountScale.title,
                    align: TextAlign.end,
                  ),
                ),
                Gap.h8,
                Text(
                  // Section 21, stated to the tenant because it is a commitment
                  // being made to them, not just an implementation detail.
                  'This is the rent your booking is held at. If the listed price '
                  'changes later, your booking and lease keep this figure.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            if (quote.requirements.isNotEmpty) ...[
              Gap.h12,
              SectionCard(
                title: 'What you will need to provide',
                children: [
                  for (final requirement in quote.requirements)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            requirement.requirementType ==
                                    RequirementType.payment
                                ? Icons.payments_outlined
                                : Icons.description_outlined,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          ),
                          Gap.w12,
                          Expanded(
                            child: Text(
                              requirement.isMandatory
                                  ? requirement.name
                                  : '${requirement.name} (optional)',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],

            Gap.h12,
            applicant,

            Gap.h16,
            Card(
              color: acceptedTerms
                  ? scheme.primaryContainer.withValues(alpha: 0.35)
                  : scheme.surfaceContainerLow,
              child: CheckboxListTile(
                value: acceptedTerms,
                onChanged: (value) => onAcceptedChanged(value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: Gap.xs,
                ),
                title: Text(
                  'I understand the booking fee is payable now and that this hold '
                  'expires after ${quote.expiryHours} hours if the requirements are '
                  'not met.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayableSummary extends StatelessWidget {
  const _PayableSummary({required this.amount});

  final Money amount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stack = MediaQuery.textScalerOf(context).scale(1) > 1.2;

    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payable now',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        Text(
          'Secure checkout',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
    final value = AmountText(
      amount,
      scale: AmountScale.title,
      // Trails the label when the two sit across, leads when they stack.
      align: stack ? TextAlign.start : TextAlign.end,
    );

    return stack
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label, Gap.h8, value],
          )
        : Row(
            children: [
              Expanded(child: label),
              Gap.w12,
              Flexible(child: value),
            ],
          );
  }
}

const _bookingSteps = <AppStep>[
  AppStep(label: 'Review', icon: Icons.receipt_long_outlined),
  AppStep(label: 'Confirm', icon: Icons.payments_outlined),
  AppStep(label: 'Complete', icon: Icons.check_circle_outline_rounded),
];

/// Who the unit is being taken by.
///
/// Prefilled from the signed-in account and still editable, because the two
/// are not always the same person. The business half only appears once someone
/// says the letting is for a business — asking a sole trader for a company
/// registration they do not have is how a form loses somebody.
class _ApplicantSection extends StatelessWidget {
  const _ApplicantSection({
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.companyController,
    required this.forBusiness,
    required this.businessType,
    required this.onForBusinessChanged,
    required this.onBusinessTypeChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController companyController;
  final bool forBusiness;
  final String? businessType;
  final ValueChanged<bool> onForBusinessChanged;
  final ValueChanged<String?> onBusinessTypeChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Form(
      key: formKey,
      child: SectionCard(
        title: 'Who this booking is for',
        children: [
          Text(
            'The landlord agrees the letting with the person named here.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Gap.h16,
          TextFormField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) => (value?.trim().isEmpty ?? true)
                ? 'Enter the name for the booking'
                : null,
          ),
          Gap.h12,
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Enter a phone number';
              // Deliberately loose. Numbers arrive with and without a country
              // code and with spaces in them, and a stricter rule here would
              // reject valid numbers the server accepts.
              return text.replaceAll(RegExp(r'\D'), '').length < 9
                  ? 'Enter a valid phone number'
                  : null;
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
          Gap.h8,
          SwitchListTile(
            value: forBusiness,
            onChanged: onForBusinessChanged,
            contentPadding: EdgeInsets.zero,
            title: const Text('This unit is for a business'),
            subtitle: Text(
              'Adds the trading name and what will trade from the unit.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          if (forBusiness) ...[
            Gap.h8,
            TextFormField(
              controller: companyController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Trading name',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              validator: (value) =>
                  forBusiness && (value?.trim().isEmpty ?? true)
                  ? 'Enter the trading name'
                  : null,
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
              validator: (value) => forBusiness && (value == null)
                  ? 'Choose what will trade from the unit'
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
