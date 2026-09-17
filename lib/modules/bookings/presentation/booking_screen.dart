import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_bottom_action_bar.dart';
import '../../../components/app_stepper.dart';
import '../../../components/async_button.dart';
import '../../../components/country_code_field.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_number.dart';
import '../../../domain/entities/booking.dart';
import '../../../domain/entities/unit.dart';
import '../../../navigation/routes.dart';
import '../../auth/application/auth_controller.dart';
import '../../units/application/unit_controller.dart';
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
  const BookingScreen({required this.target, super.key});

  /// The space being booked, as the engine named it: a size in a block.
  final SpaceTarget target;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final _applicantFormKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  final _companyController = TextEditingController();

  /// The code the applicant's number is dialling on, read off the account's
  /// own number and Kenya when there is none.
  late Country _country;

  bool _acceptedTerms = false;
  bool _forBusiness = false;
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
          widget.target,
          applicant: BookingApplicant(
            fullName: _nameController.text.trim(),
            phoneNumber: PhoneNumber.normalize(
              _phoneController.text,
              country: _country,
            ),
            email: _emailController.text.trim(),
            companyName: _forBusiness ? _companyController.text.trim() : null,
            businessType: _forBusiness ? _businessType : null,
          ),
        );

    if (!mounted) return;

    switch (result) {
      case Ok(:final value):
        // Replace rather than push: coming "back" to a booking confirmation
        // screen for a booking that now exists makes no sense. The status
        // screen is where the fee gets paid, and the message says so —
        // nothing on the way here asked for money.
        context.pushReplacementNamed(
          Routes.bookingStatus,
          pathParameters: {'bookingId': value.id},
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Booking made. Pay the booking fee when you are ready to hold '
              'the unit.',
            ),
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
    // The same route Browse read, so the space is described in the engine's
    // own words and nothing else is fetched on the way to a booking.
    final availability = ref.watch(availabilityProvider);
    final block = availability.whenData(
      (blocks) => blocks
          .where(
            (b) =>
                b.propertyId == widget.target.propertyId &&
                b.blockId == widget.target.blockId,
          )
          .firstOrNull,
    );
    final canBook = block.value != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm your booking')),
      body: AppRefreshIndicator(
        onRefresh: () => ref.read(availabilityProvider.notifier).refresh(),
        child: switch (availability) {
          AsyncLoading() when !availability.hasValue => const LoadingView(
            message: 'Checking availability…',
          ),
          AsyncError(:final error) => ErrorView(
            failure: error is Failure
                ? error
                : UnknownFailure(error.toString()),
            onRetry: () => ref.read(availabilityProvider.notifier).refresh(),
          ),
          _ when block.value == null => EmptyState(
            onRefresh: () async {
              await ref.read(availabilityProvider.notifier).refresh();
            },
            icon: Icons.storefront_outlined,
            title: 'This space has been taken',
            message:
                'Nothing is left to book in this block. Pull down to check '
                'again, or choose another space.',
            action: FilledButton.tonal(
              onPressed: () => context.goNamed(Routes.browse),
              child: const Text('Back to browse'),
            ),
          ),
          _ => _TermsBody(
            block: block.value!,
            size: widget.target.size,
            acceptedTerms: _acceptedTerms,
            onAcceptedChanged: (v) => setState(() => _acceptedTerms = v),
            applicant: _ApplicantSection(
              formKey: _applicantFormKey,
              nameController: _nameController,
              phoneController: _phoneController,
              country: _country,
              onCountryChanged: (country) => setState(() => _country = country),
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
      ),
      // AppBottomActionBar keeps the height factor this screen needs: a bottom
      // navigation child receives the scaffold's full height as its upper
      // bound, and without one the bar expands to that bound and leaves almost
      // no viewport for the list above it.
      bottomNavigationBar: canBook
          ? AppBottomActionBar(
              child: AsyncButton(
                label: 'Confirm booking',
                icon: Icons.event_available_outlined,
                expand: true,
                enabled: _acceptedTerms,
                onPressed: _confirm,
              ),
            )
          : null,
    );
  }
}

/// Who is booking, and what: the space as the engine described it.
///
/// Nothing on this screen is paid, and nothing on it is priced. The engine
/// names blocks and sizes, not rents; the server sets the rent, the deposit
/// and the booking fee on the booking when it is made (section 21), and the
/// booking is where they are read. So the screen says what is being asked
/// for, who is asking, and what happens next — and does not guess a figure.
class _TermsBody extends StatelessWidget {
  const _TermsBody({
    required this.block,
    required this.size,
    required this.acceptedTerms,
    required this.onAcceptedChanged,
    required this.applicant,
  });

  final UnitAvailability block;

  /// The size chosen, or null for any the block has.
  final double? size;
  final bool acceptedTerms;
  final ValueChanged<bool> onAcceptedChanged;

  /// The applicant details, built by the stateful parent so the controllers
  /// outlive a rebuild of the availability.
  final Widget applicant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chosen = size == null
        ? null
        : block.bySize.where((s) => s.size == size).firstOrNull;
    final sizeLabel = size == null
        ? 'Any size'
        : UnitAvailabilitySize(size: size!, count: chosen?.count ?? 0).label;
    final left = chosen?.count ?? block.count;
    final blockName = block.blockName.isEmpty
        ? 'Unnamed block'
        : block.blockName;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxReadingWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
          children: [
            const AppStepper.horizontal(steps: _bookingSteps, currentIndex: 0),
            Gap.h24,
            Text(
              'Book a space in $blockName',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: AppTypography.bold,
              ),
            ),
            Gap.h4,
            Text(
              'Confirm who is booking. Nothing is paid now — the booking fee '
              'is due once your booking is in.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),

            Gap.h16,
            SectionCard(
              title: 'Your space',
              children: [
                DetailRow(label: 'Property', value: block.propertyName),
                DetailRow(label: 'Block', value: blockName),
                DetailRow(label: 'Size', value: sizeLabel),
                DetailRow(
                  label: 'Available',
                  value: '$left ${left == 1 ? 'unit' : 'units'}',
                ),
                Gap.h8,
                Text(
                  'The unit itself is allocated when you book, and your '
                  'booking is held at the rent in force when it is made. If '
                  'the listed price changes later, your booking and lease '
                  'keep that figure.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            Gap.h12,
            applicant,

            Gap.h12,
            SectionCard(
              title: 'After you book',
              children: [
                // Every figure is set on the booking by the server. The
                // engine states none, and one read off the booking is the
                // only one worth quoting.
                const DetailRow(
                  label: 'Monthly rent',
                  value: 'Set on your booking',
                ),
                const DetailRow(
                  label: 'Booking fee',
                  value: 'Set on your booking',
                ),
                const DetailRow(
                  label: 'Security deposit',
                  value: 'Set on your booking',
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
                          'Pay the booking fee from My bookings to hold the '
                          'unit. The deposit is invoiced once the unit is '
                          'held, and is refundable at the end of your lease, '
                          'less any deductions.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

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
                  'I understand the booking fee is due after booking to hold '
                  'this unit, and that the hold lapses if the requirements are '
                  'not completed in time.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _bookingSteps = <AppStep>[
  AppStep(label: 'Book', icon: Icons.event_available_outlined),
  AppStep(label: 'Pay fee', icon: Icons.payments_outlined),
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
    required this.country,
    required this.onCountryChanged,
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
  final Country country;
  final ValueChanged<Country> onCountryChanged;
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
