import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_bottom_action_bar.dart';
import '../../../components/async_button.dart';
import '../../../components/page_header.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/property.dart';
import '../../../domain/entities/unit.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../owner/presentation/widgets/owner_form.dart';
import '../../units/application/unit_controller.dart';
import '../application/structure_controller.dart';

/// Creating a single unit, or amending one.
///
/// The batch form elsewhere builds a floor of identical shops in one go. This
/// is the other half of the job: the corner unit that is not like the others,
/// and the correction to a unit that already exists.
///
/// Deposit and booking fee can each be a cash amount *or* a percentage of
/// rent, because the contract accepts both and back offices use both. Nothing
/// here converts between them — whichever the owner enters is what is sent,
/// and the other stays empty.
class UnitFormScreen extends ConsumerStatefulWidget {
  const UnitFormScreen({
    required this.propertyId,
    this.unitId,
    this.blockId,
    super.key,
  });

  final String propertyId;

  /// Null when creating.
  final String? unitId;

  /// Preselected when the form was opened from inside a block.
  final String? blockId;

  @override
  ConsumerState<UnitFormScreen> createState() => _UnitFormScreenState();
}

class _UnitFormScreenState extends ConsumerState<UnitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _areaController = TextEditingController();
  final _rentController = TextEditingController();
  final _depositController = TextEditingController();
  final _depositPercentController = TextEditingController();
  final _serviceChargeController = TextEditingController();
  final _bookingFeePercentController = TextEditingController();
  final _wingController = TextEditingController();
  final _sectionController = TextEditingController();
  final _floorController = TextEditingController();

  UnitCategory _category = UnitCategory.shop;
  String? _blockId;
  bool _depositAsPercentage = false;
  bool _seeded = false;

  /// The contract states no currency outside the invoice, so the platform's
  /// own is what a new figure is entered in.
  static const String _currency = 'KES';

  bool get _isEditing => widget.unitId != null;

  @override
  void initState() {
    super.initState();
    _blockId = widget.blockId;
  }

  @override
  void dispose() {
    for (final controller in [
      _numberController,
      _descriptionController,
      _lengthController,
      _widthController,
      _areaController,
      _rentController,
      _depositController,
      _depositPercentController,
      _serviceChargeController,
      _bookingFeePercentController,
      _wingController,
      _sectionController,
      _floorController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _seed(Unit unit) {
    if (_seeded) return;
    _seeded = true;
    _numberController.text = unit.unitNumber;
    _descriptionController.text = unit.description ?? '';
    _lengthController.text = unit.length == null ? '' : _trim(unit.length!);
    _widthController.text = unit.width == null ? '' : _trim(unit.width!);
    _areaController.text = unit.area == null ? '' : _trim(unit.area!);
    _rentController.text = unit.baseRent.majorUnits.toStringAsFixed(0);
    _depositController.text = unit.depositAmount == null
        ? ''
        : unit.depositAmount!.majorUnits.toStringAsFixed(0);
    _serviceChargeController.text = unit.serviceCharge == null
        ? ''
        : unit.serviceCharge!.majorUnits.toStringAsFixed(0);
    _wingController.text = unit.wing ?? '';
    _sectionController.text = unit.section ?? '';
    _floorController.text = unit.floorNumber?.toString() ?? '';
    _category = unit.category == UnitCategory.unknown
        ? UnitCategory.shop
        : unit.category;
    _blockId ??= unit.buildingId;
  }

  /// Area follows the dimensions unless it was typed directly.
  ///
  /// A 50 by 100 shop is 5,000 square feet, and making somebody work that out
  /// on a phone invites a transposed digit into a rent. The field stays
  /// editable — an irregular unit is not its bounding box.
  void _recomputeArea() {
    final length = NumberField.parse(_lengthController.text);
    final width = NumberField.parse(_widthController.text);
    if (length == null || width == null) return;
    _areaController.text = _trim((length * width).toDouble());
    setState(() {});
  }

  UnitDraft _draft() => UnitDraft(
    propertyId: widget.propertyId,
    blockId: _blockId,
    unitNumber: _numberController.text.trim(),
    category: _category,
    monthlyRent:
        MoneyField.parse(_rentController.text, _currency) ??
        Money.zero(_currency),
    description: _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim(),
    length: NumberField.parse(_lengthController.text)?.toDouble(),
    width: NumberField.parse(_widthController.text)?.toDouble(),
    area: NumberField.parse(_areaController.text)?.toDouble(),
    depositAmount: _depositAsPercentage
        ? null
        : MoneyField.parse(_depositController.text, _currency),
    depositPercentage: _depositAsPercentage
        ? NumberField.parse(_depositPercentController.text)?.toDouble()
        : null,
    serviceCharge: MoneyField.parse(_serviceChargeController.text, _currency),
    bookingFeePercentage: NumberField.parse(
      _bookingFeePercentController.text,
    )?.toDouble(),
    wing: _wingController.text.trim().isEmpty
        ? null
        : _wingController.text.trim(),
    section: _sectionController.text.trim().isEmpty
        ? null
        : _sectionController.text.trim(),
    floorNumber: int.tryParse(_floorController.text.trim()),
  );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final actions = ref.read(structureActionsProvider);
    final result = _isEditing
        ? await actions.updateUnit(unitId: widget.unitId!, draft: _draft())
        : await actions.createUnit(_draft());

    if (!mounted) return;

    switch (result) {
      case Ok():
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Unit updated.' : 'Unit created.'),
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

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${_numberController.text}?'),
        content: const Text(
          'The unit stops being listed. Its past invoices and leases are kept, '
          'and a unit that is currently let cannot be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(structureActionsProvider)
        .deleteUnit(
          unitId: widget.unitId!,
          propertyId: widget.propertyId,
          blockId: _blockId,
        );
    if (!mounted) return;

    switch (result) {
      case Ok():
        Navigator.of(context).pop();
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
    final scheme = Theme.of(context).colorScheme;
    final blocks = ref.watch(propertyBlocksProvider(widget.propertyId));
    final existing = _isEditing
        ? ref.watch(unitDetailProvider(widget.unitId!))
        : null;

    if (existing != null) {
      switch (existing) {
        case AsyncError(:final error):
          return Scaffold(
            appBar: AppBar(title: const Text('Edit unit')),
            body: AppRefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  ref.refresh(propertyBlocksProvider(widget.propertyId).future),
                  if (widget.unitId != null)
                    ref.refresh(unitDetailProvider(widget.unitId!).future),
                ]);
              },
              child: ErrorView(
                failure: error is Failure
                    ? error
                    : UnknownFailure(error.toString()),
                onRetry: () =>
                    ref.invalidate(unitDetailProvider(widget.unitId!)),
              ),
            ),
          );
        case AsyncData(:final value):
          _seed(value);
        default:
          return Scaffold(
            appBar: AppBar(title: const Text('Edit unit')),
            body: AppRefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  ref.refresh(propertyBlocksProvider(widget.propertyId).future),
                  if (widget.unitId != null)
                    ref.refresh(unitDetailProvider(widget.unitId!).future),
                ]);
              },
              child: const LoadingView(),
            ),
          );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit unit' : 'New unit'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Remove unit',
            ),
        ],
      ),
      body: AppRefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(propertyBlocksProvider(widget.propertyId).future),
            if (widget.unitId != null)
              ref.refresh(unitDetailProvider(widget.unitId!).future),
          ]);
        },
        child: Form(
          key: _formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.maxReadingWidth,
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Gap.lg,
                  Gap.sm,
                  Gap.lg,
                  Gap.xxl,
                ),
                children: [
                  PageHeader(
                    title: _isEditing ? 'Edit this unit' : 'Add a unit',
                    subtitle:
                        'One unit at a time. To build a whole floor of identical '
                        'shops, use the batch on the property screen.',
                    compact: true,
                  ),
                  Gap.h16,
                  SectionCard(
                    title: 'Identity',
                    children: [
                      OwnerField(
                        label: 'Unit number',
                        controller: _numberController,
                        hint: 'SHOP-102',
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? 'Give the unit a number'
                            : null,
                      ),
                      Gap.h12,
                      DropdownButtonFormField<UnitCategory>(
                        initialValue: _category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Type of space',
                        ),
                        items: [
                          for (final category in UnitCategory.selectable)
                            DropdownMenuItem(
                              value: category,
                              child: Text(category.label),
                            ),
                        ],
                        onChanged: (value) => setState(
                          () => _category = value ?? UnitCategory.shop,
                        ),
                      ),
                      Gap.h12,
                      _BlockPicker(
                        blocks: blocks,
                        selected: _blockId,
                        onChanged: (value) => setState(() => _blockId = value),
                      ),
                      Gap.h12,
                      OwnerField(
                        label: 'Description',
                        controller: _descriptionController,
                        maxLines: 3,
                        helper: 'Optional.',
                        validator: (_) => null,
                      ),
                    ],
                  ),
                  Gap.h12,
                  SectionCard(
                    title: 'Where it is',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OwnerField(
                              label: 'Wing',
                              controller: _wingController,
                              textCapitalization: TextCapitalization.words,
                              validator: (_) => null,
                            ),
                          ),
                          Gap.w12,
                          Expanded(
                            child: OwnerField(
                              label: 'Section',
                              controller: _sectionController,
                              textCapitalization: TextCapitalization.words,
                              validator: (_) => null,
                            ),
                          ),
                        ],
                      ),
                      Gap.h12,
                      NumberField(
                        label: 'Floor number',
                        controller: _floorController,
                        helper: 'Ground floor is 0.',
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return null;
                          return int.tryParse(text) == null
                              ? 'Enter a floor number'
                              : null;
                        },
                      ),
                    ],
                  ),
                  Gap.h12,
                  SectionCard(
                    title: 'Size',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: NumberField(
                              label: 'Length',
                              controller: _lengthController,
                              suffix: 'ft',
                              allowDecimal: true,
                              onChanged: (_) => _recomputeArea(),
                              validator: (_) => null,
                            ),
                          ),
                          Gap.w12,
                          Expanded(
                            child: NumberField(
                              label: 'Width',
                              controller: _widthController,
                              suffix: 'ft',
                              allowDecimal: true,
                              onChanged: (_) => _recomputeArea(),
                              validator: (_) => null,
                            ),
                          ),
                        ],
                      ),
                      Gap.h12,
                      NumberField(
                        label: 'Area',
                        controller: _areaController,
                        suffix: 'sq ft',
                        allowDecimal: true,
                        helper:
                            'Filled in from the dimensions, and editable — an '
                            'irregular unit is not its bounding box.',
                        validator: (_) => null,
                      ),
                    ],
                  ),
                  Gap.h12,
                  SectionCard(
                    title: 'Money',
                    children: [
                      MoneyField(
                        label: 'Monthly rent',
                        controller: _rentController,
                        currency: _currency,
                        validator: (value) =>
                            MoneyField.parse(value ?? '', _currency) == null
                            ? 'Enter the monthly rent'
                            : null,
                      ),
                      Gap.h12,
                      MoneyField(
                        label: 'Service charge',
                        controller: _serviceChargeController,
                        currency: _currency,
                        helper: 'Optional, per month.',
                        validator: (_) => null,
                      ),
                      Gap.h16,
                      SwitchListTile(
                        value: _depositAsPercentage,
                        onChanged: (value) =>
                            setState(() => _depositAsPercentage = value),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Set the deposit as a percentage'),
                        subtitle: Text(
                          'Otherwise it is a cash amount. Only the one you enter '
                          'is sent.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      Gap.h8,
                      if (_depositAsPercentage)
                        NumberField(
                          label: 'Deposit',
                          controller: _depositPercentController,
                          suffix: '% of rent',
                          allowDecimal: true,
                          validator: (_) => null,
                        )
                      else
                        MoneyField(
                          label: 'Deposit',
                          controller: _depositController,
                          currency: _currency,
                          helper: 'Optional.',
                          validator: (_) => null,
                        ),
                      Gap.h12,
                      NumberField(
                        label: 'Booking fee',
                        controller: _bookingFeePercentController,
                        suffix: '% of rent',
                        allowDecimal: true,
                        helper: 'Optional.',
                        validator: (_) => null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomActionBar(
        child: AsyncButton(
          label: _isEditing ? 'Save changes' : 'Create unit',
          icon: Icons.check_rounded,
          expand: true,
          onPressed: _save,
        ),
      ),
    );
  }

  static String _trim(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

/// Which block the unit sits in.
///
/// "Not in a block" stays available: a standalone kiosk in a forecourt belongs
/// to the property and to no wing, and forcing a choice would mean inventing
/// one.
class _BlockPicker extends StatelessWidget {
  const _BlockPicker({
    required this.blocks,
    required this.selected,
    required this.onChanged,
  });

  final AsyncValue<List<Building>> blocks;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final available = blocks.hasValue
        ? blocks.requireValue
        : const <Building>[];
    // A selection that is not in the list would throw. It can happen while the
    // blocks are still loading, or if the block was removed elsewhere.
    final value = available.any((block) => block.id == selected)
        ? selected
        : null;

    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Block',
        helperText: blocks.isLoading
            ? 'Loading blocks…'
            : 'Leave unset for a unit that belongs to no wing.',
      ),
      items: [
        const DropdownMenuItem<String?>(child: Text('No block')),
        for (final block in available)
          DropdownMenuItem<String?>(value: block.id, child: Text(block.name)),
      ],
      onChanged: onChanged,
    );
  }
}
