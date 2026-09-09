import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_bottom_action_bar.dart';
import '../../../components/async_button.dart';
import '../../../components/page_header.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/owner.dart';
import '../../../domain/entities/property.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../owner/presentation/widgets/owner_form.dart';
import '../../properties/application/property_controller.dart';
import '../application/structure_controller.dart';

/// Amending a property, and archiving or restoring it.
///
/// Archiving is on this screen rather than behind a separate one because it is
/// the same decision as the rest of it — what this property is and whether it
/// is still trading — and because a destructive action is safer where its
/// consequences are visible than where it stands alone.
class PropertyEditScreen extends ConsumerStatefulWidget {
  const PropertyEditScreen({required this.propertyId, super.key});

  final String propertyId;

  @override
  ConsumerState<PropertyEditScreen> createState() => _PropertyEditScreenState();
}

class _PropertyEditScreenState extends ConsumerState<PropertyEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countyController = TextEditingController();
  final _countryController = TextEditingController();
  final _areaController = TextEditingController();
  final _rateController = TextEditingController();

  PropertyType _type = PropertyType.mall;
  String _currency = 'KES';
  bool _seeded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countyController.dispose();
    _countryController.dispose();
    _areaController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _seed(Property property) {
    if (_seeded) return;
    _seeded = true;
    _nameController.text = property.name;
    _descriptionController.text = property.description ?? '';
    _addressController.text = property.address ?? '';
    _cityController.text = property.city;
    _countyController.text = property.county ?? '';
    _countryController.text = property.country;
    _areaController.text = property.totalArea == null
        ? ''
        : _trim(property.totalArea!);
    final rate = property.rentRatePerSqm;
    if (rate != null) {
      _currency = rate.currency;
      _rateController.text = rate.majorUnits.toStringAsFixed(0);
    }
    _type = property.propertyType == PropertyType.unknown
        ? PropertyType.mall
        : property.propertyType;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await ref
        .read(structureActionsProvider)
        .updateProperty(
          propertyId: widget.propertyId,
          draft: PropertyDraft(
            name: _nameController.text.trim(),
            propertyType: _type,
            city: _cityController.text.trim(),
            country: _countryController.text.trim(),
            rentRatePerSqm:
                MoneyField.parse(_rateController.text, _currency) ??
                Money.zero(_currency),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            address: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
            county: _countyController.text.trim().isEmpty
                ? null
                : _countyController.text.trim(),
            totalArea: NumberField.parse(_areaController.text)?.toDouble(),
          ),
        );

    if (!mounted) return;

    switch (result) {
      case Ok():
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property updated.'),
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

  Future<void> _setArchived(Property property, {required bool archived}) async {
    if (archived) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Archive ${property.name}?'),
          content: const Text(
            'It stops being listed to tenants. Nothing is deleted, and it can '
            'be restored from this screen. A property with live tenancies '
            'cannot be archived.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final result = await ref
        .read(structureActionsProvider)
        .setArchived(propertyId: widget.propertyId, archived: archived);
    if (!mounted) return;

    if (result case Err(:final failure)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(archived ? 'Property archived.' : 'Property restored.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final property = ref.watch(propertyDetailProvider(widget.propertyId));

    return switch (property) {
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(title: const Text('Edit property')),
        body: ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () =>
              ref.invalidate(propertyDetailProvider(widget.propertyId)),
        ),
      ),
      AsyncData(:final value) => _form(value.property),
      _ => Scaffold(
        appBar: AppBar(title: const Text('Edit property')),
        body: const LoadingView(),
      ),
    };
  }

  Widget _form(Property property) {
    _seed(property);
    final archived = property.status == PropertyStatus.archived;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit property')),
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
                Gap.sm,
                Gap.lg,
                Gap.xxl,
              ),
              children: [
                PageHeader(
                  title: property.name,
                  subtitle: 'What this property is, and where.',
                  compact: true,
                ),
                Gap.h16,
                SectionCard(
                  title: 'Identity',
                  children: [
                    OwnerField(
                      label: 'Property name',
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Give the property a name'
                          : null,
                    ),
                    Gap.h12,
                    DropdownButtonFormField<PropertyType>(
                      initialValue: _type,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: [
                        for (final type in PropertyType.values)
                          if (type != PropertyType.unknown)
                            DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                      ],
                      onChanged: (value) =>
                          setState(() => _type = value ?? PropertyType.mall),
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
                    OwnerField(
                      label: 'Street address',
                      controller: _addressController,
                      textCapitalization: TextCapitalization.words,
                      helper:
                          'Held by this app. The published API records only '
                          'the city and country.',
                      validator: (_) => null,
                    ),
                    Gap.h12,
                    OwnerField(
                      label: 'City',
                      controller: _cityController,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Enter the city'
                          : null,
                    ),
                    Gap.h12,
                    OwnerField(
                      label: 'County',
                      controller: _countyController,
                      textCapitalization: TextCapitalization.words,
                      helper: 'Optional.',
                      validator: (_) => null,
                    ),
                    Gap.h12,
                    OwnerField(
                      label: 'Country',
                      controller: _countryController,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Enter the country'
                          : null,
                    ),
                  ],
                ),
                Gap.h12,
                SectionCard(
                  title: 'Size and rate',
                  children: [
                    NumberField(
                      label: 'Total area',
                      controller: _areaController,
                      suffix: 'sq ft',
                      allowDecimal: true,
                      validator: (_) => null,
                    ),
                    Gap.h12,
                    MoneyField(
                      label: 'Asking rate',
                      controller: _rateController,
                      currency: _currency,
                      suffix: 'per sq ft',
                      helper:
                          'New units take their rent from this. It never '
                          'reaches a lease already signed.',
                      validator: (_) => null,
                    ),
                  ],
                ),
                Gap.h12,
                SectionCard(
                  title: archived ? 'Archived' : 'Archive',
                  children: [
                    Text(
                      archived
                          ? 'This property is not listed to tenants. Restoring '
                                'it puts it back exactly as it was.'
                          : 'Archiving takes the property off the listings '
                                'without deleting anything.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Gap.h12,
                    AsyncButton(
                      label: archived ? 'Restore property' : 'Archive property',
                      icon: archived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      tonal: true,
                      expand: true,
                      onPressed: () =>
                          _setArchived(property, archived: !archived),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomActionBar(
        child: AsyncButton(
          label: 'Save changes',
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
