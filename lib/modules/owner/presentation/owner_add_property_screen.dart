import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_bottom_action_bar.dart';
import '../../../components/app_stepper.dart';
import '../../../components/async_button.dart';
import '../../../components/page_header.dart';
import '../../../components/surface_atoms.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/owner.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../navigation/routes.dart';
import '../application/owner_controller.dart';
import 'widgets/owner_form.dart';

/// Section 88. Registering a property and filling it with units.
///
/// Four steps, because the decisions are of four different kinds and mixing
/// them makes a form nobody reads: what the property is, where it is, what it
/// asks per square metre, and what is in it. The rate step carries a live
/// preview of what a unit would ask, which is the only place in the app the
/// client multiplies money — it is labelled indicative, and the figures that
/// get saved come back from the server.
class OwnerAddPropertyScreen extends ConsumerStatefulWidget {
  const OwnerAddPropertyScreen({super.key});

  @override
  ConsumerState<OwnerAddPropertyScreen> createState() =>
      _OwnerAddPropertyScreenState();
}

class _OwnerAddPropertyScreenState
    extends ConsumerState<OwnerAddPropertyScreen> {
  static const _currency = 'KES';

  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController(text: 'Nairobi');
  final _county = TextEditingController();
  final _country = TextEditingController(text: 'Kenya');
  final _totalArea = TextEditingController();
  final _rate = TextEditingController();

  final _typeName = TextEditingController(text: 'Retail Unit');
  final _unitArea = TextEditingController();
  final _quantity = TextEditingController(text: '4');
  final _prefix = TextEditingController(text: 'SHOP');
  final _startNumber = TextEditingController(text: '101');
  final _buildingName = TextEditingController();
  final _floorName = TextEditingController();

  PropertyType _type = PropertyType.mall;
  int _step = 0;
  bool _addUnits = true;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _address,
      _city,
      _county,
      _country,
      _totalArea,
      _rate,
      _typeName,
      _unitArea,
      _quantity,
      _prefix,
      _startNumber,
      _buildingName,
      _floorName,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  static const _steps = [
    AppStep(label: 'Identity'),
    AppStep(label: 'Location'),
    AppStep(label: 'Rate'),
    AppStep(label: 'Units'),
  ];

  Money? get _parsedRate => MoneyField.parse(_rate.text, _currency);
  num? get _parsedUnitArea => NumberField.parse(_unitArea.text);

  bool get _canAdvance => switch (_step) {
    0 => _name.text.trim().isNotEmpty,
    1 => _city.text.trim().isNotEmpty && _country.text.trim().isNotEmpty,
    2 => _parsedRate != null && _parsedRate!.isPositive,
    _ => true,
  };

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _submit() async {
    final rate = _parsedRate;
    if (rate == null) return;

    final actions = ref.read(ownerActionsProvider);
    final result = await actions.createProperty(
      PropertyDraft(
        name: _name.text.trim(),
        propertyType: _type,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        city: _city.text.trim(),
        county: _county.text.trim().isEmpty ? null : _county.text.trim(),
        country: _country.text.trim(),
        totalArea: NumberField.parse(_totalArea.text)?.toDouble(),
        rentRatePerSqm: rate,
      ),
    );

    if (!mounted) return;

    switch (result) {
      case Err(:final failure):
        _complain(ownerFailureMessage(failure));
      case Ok(:final value):
        var created = 0;
        if (_addUnits && _parsedUnitArea != null) {
          final batch = await actions.createUnits(
            propertyId: value.id,
            draft: UnitBatchDraft(
              typeName: _typeName.text.trim().isEmpty
                  ? 'Unit'
                  : _typeName.text.trim(),
              area: _parsedUnitArea!.toDouble(),
              quantity: (NumberField.parse(_quantity.text) ?? 1).toInt(),
              numberPrefix: _prefix.text.trim().isEmpty
                  ? 'UNIT'
                  : _prefix.text.trim(),
              startNumber: (NumberField.parse(_startNumber.text) ?? 1).toInt(),
              buildingName: _buildingName.text.trim().isEmpty
                  ? null
                  : _buildingName.text.trim(),
              floorName: _floorName.text.trim().isEmpty
                  ? null
                  : _floorName.text.trim(),
            ),
          );
          if (batch case Ok(:final value)) created = value;
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              created == 0
                  ? '${value.name} added.'
                  : '${value.name} added with $created unit'
                        '${created == 1 ? '' : 's'}.',
            ),
          ),
        );
        context.pushReplacementNamed(
          Routes.ownerProperty,
          pathParameters: {'propertyId': value.id},
        );
    }
  }

  void _complain(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == _steps.length - 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Add a property')),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.maxReadingWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.lg,
                Gap.lg,
                Gap.xxl,
              ),
              children: [
                AppStepper.horizontal(steps: _steps, currentIndex: _step),
                Gap.h24,
                switch (_step) {
                  0 => _identity(),
                  1 => _location(),
                  2 => _rateStep(),
                  _ => _units(),
                },
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomActionBar(
        child: Row(
          children: [
            if (_step > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _back,
                  child: const Text('Back'),
                ),
              ),
              Gap.w12,
            ],
            Expanded(
              flex: 2,
              child: isLast
                  ? AsyncButton(
                      label: 'Add property',
                      expand: true,
                      onPressed: _submit,
                    )
                  : FilledButton(
                      onPressed: _canAdvance ? _next : null,
                      child: const Text('Continue'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _identity() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageHeader(
        compact: true,
        title: 'What is it?',
        subtitle: 'The name tenants will see when they browse.',
      ),
      Gap.h24,
      OwnerField(
        label: 'Property name',
        controller: _name,
        hint: 'Riverside Court',
        onChanged: (_) => setState(() {}),
      ),
      Gap.h16,
      DropdownButtonFormField<PropertyType>(
        initialValue: _type,
        decoration: const InputDecoration(labelText: 'Type'),
        items: [
          for (final type in PropertyType.values)
            if (type != PropertyType.unknown)
              DropdownMenuItem(value: type, child: Text(type.label)),
        ],
        onChanged: (value) => setState(() => _type = value ?? _type),
      ),
      Gap.h16,
      OwnerField(
        label: 'Description',
        controller: _description,
        maxLines: 3,
        helper: 'Optional. What makes the place worth renting.',
      ),
    ],
  );

  Widget _location() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageHeader(
        compact: true,
        title: 'Where is it?',
        subtitle: 'Used for the listing and on the lease agreement.',
      ),
      Gap.h24,
      OwnerField(
        label: 'Street address',
        controller: _address,
        hint: 'Karuna Road, Westlands',
      ),
      Gap.h16,
      OwnerField(
        label: 'City',
        controller: _city,
        onChanged: (_) => setState(() {}),
      ),
      Gap.h16,
      OwnerField(label: 'County', controller: _county),
      Gap.h16,
      OwnerField(
        label: 'Country',
        controller: _country,
        onChanged: (_) => setState(() {}),
      ),
    ],
  );

  Widget _rateStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageHeader(
        compact: true,
        title: 'What does it ask?',
        subtitle:
            'Every unit takes its rent from this rate and its own area. You '
            'can price an individual unit differently later.',
      ),
      Gap.h24,
      NumberField(
        label: 'Total area',
        controller: _totalArea,
        suffix: 'm²',
        helper: 'Optional. The whole property, lettable or not.',
      ),
      Gap.h16,
      MoneyField(
        label: 'Rate',
        controller: _rate,
        currency: _currency,
        suffix: 'per m²',
        hint: '30',
        onChanged: (_) => setState(() {}),
      ),
      Gap.h16,
      RatePreview(rate: _parsedRate, area: _parsedUnitArea ?? 5000),
    ],
  );

  Widget _units() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageHeader(
        compact: true,
        title: 'What is in it?',
        subtitle: 'Generate a run of units now, or add them later.',
      ),
      Gap.h24,
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Add units now'),
        value: _addUnits,
        onChanged: (value) => setState(() => _addUnits = value),
      ),
      if (_addUnits) ...[
        Gap.h16,
        OwnerField(label: 'Unit type name', controller: _typeName),
        Gap.h16,
        NumberField(
          label: 'Area of each unit',
          controller: _unitArea,
          suffix: 'm²',
          hint: '5000',
          onChanged: (_) => setState(() {}),
        ),
        Gap.h16,
        // Three numbering fields, and two location ones. Both fall to one
        // column once the platform text size means they would truncate —
        // `prefersStacked` is the same gate the shared two-up widgets use, and
        // there are tests at 320 wide and textScale 2 that catch a Row without
        // it.
        _Fields(
          children: [
            NumberField(
              label: 'How many',
              controller: _quantity,
              allowDecimal: false,
            ),
            OwnerField(
              label: 'Prefix',
              controller: _prefix,
              textCapitalization: TextCapitalization.characters,
            ),
            NumberField(
              label: 'From',
              controller: _startNumber,
              allowDecimal: false,
            ),
          ],
        ),
        Gap.h16,
        _Fields(
          children: [
            OwnerField(label: 'Building', controller: _buildingName),
            OwnerField(label: 'Floor', controller: _floorName),
          ],
        ),
        Gap.h16,
        RatePreview(
          rate: _parsedRate,
          area: _parsedUnitArea,
          caption: _parsedRate == null || _parsedUnitArea == null
              ? null
              : 'Each of these units would ask '
                    '${_parsedRate!.scaledBy(_parsedUnitArea!).format()} '
                    'a month.',
        ),
      ],
    ],
  );
}

/// Fields laid out across the width, or down it when the text is too large for
/// them to share a line.
class _Fields extends StatelessWidget {
  const _Fields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (prefersStacked(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) Gap.h16,
            child,
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) Gap.w12,
          Expanded(child: child),
        ],
      ],
    );
  }
}
