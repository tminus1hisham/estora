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
import '../../../domain/entities/property.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../owner/presentation/widgets/owner_form.dart';
import '../application/structure_controller.dart';

/// Creating a block, or amending one.
///
/// One screen for both, because they ask for exactly the same things and a
/// second screen would be the same fields with a different verb. Which one it
/// is shows in the title and the action, and in whether the fields arrive
/// filled in.
///
/// The counts are optional throughout. A wing under construction has a floor
/// count and no units yet, and refusing to save until somebody invents a
/// number would be worse than holding nothing.
class BlockFormScreen extends ConsumerStatefulWidget {
  const BlockFormScreen({required this.propertyId, this.blockId, super.key});

  final String propertyId;

  /// Null when creating.
  final String? blockId;

  @override
  ConsumerState<BlockFormScreen> createState() => _BlockFormScreenState();
}

class _BlockFormScreenState extends ConsumerState<BlockFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _areaController = TextEditingController();
  final _floorsController = TextEditingController();
  final _totalUnitsController = TextEditingController();
  final _leasableUnitsController = TextEditingController();

  BlockStatus _status = BlockStatus.active;

  /// Guards against the fields being refilled from the server every time the
  /// provider re-emits. Somebody halfway through an edit does not want their
  /// typing replaced by what they started from.
  bool _seeded = false;

  bool get _isEditing => widget.blockId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _areaController.dispose();
    _floorsController.dispose();
    _totalUnitsController.dispose();
    _leasableUnitsController.dispose();
    super.dispose();
  }

  void _seed(Building block) {
    if (_seeded) return;
    _seeded = true;
    _nameController.text = block.name;
    _descriptionController.text = block.description ?? '';
    _areaController.text = block.totalArea == null
        ? ''
        : _trim(block.totalArea!);
    _floorsController.text = block.numberOfFloors?.toString() ?? '';
    _totalUnitsController.text = block.totalUnits?.toString() ?? '';
    _leasableUnitsController.text = block.leasableUnits?.toString() ?? '';
    _status = block.status;
  }

  BuildingDraft _draft() => BuildingDraft(
    propertyId: widget.propertyId,
    name: _nameController.text.trim(),
    status: _status,
    description: _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim(),
    totalArea: NumberField.parse(_areaController.text)?.toDouble(),
    numberOfFloors: NumberField.parse(_floorsController.text)?.toInt(),
    totalUnits: NumberField.parse(_totalUnitsController.text)?.toInt(),
    leasableUnits: NumberField.parse(_leasableUnitsController.text)?.toInt(),
  );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final actions = ref.read(structureActionsProvider);
    final result = _isEditing
        ? await actions.updateBlock(blockId: widget.blockId!, draft: _draft())
        : await actions.createBlock(_draft());

    if (!mounted) return;

    switch (result) {
      case Ok():
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Block updated.' : 'Block added to the property.',
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = _isEditing
        ? ref.watch(blockProvider(widget.blockId!))
        : null;

    if (existing != null) {
      switch (existing) {
        case AsyncError(:final error):
          return Scaffold(
            appBar: AppBar(title: const Text('Edit block')),
            body: AppRefreshIndicator(
              onRefresh: () async {
                if (widget.blockId != null) {
                  await ref
                      .refresh(blockProvider(widget.blockId!).future)
                      .then<void>((_) {});
                }
              },
              child: ErrorView(
                failure: error is Failure
                    ? error
                    : UnknownFailure(error.toString()),
                onRetry: () async {
                  await ref
                      .refresh(blockProvider(widget.blockId!).future)
                      .then<void>((_) {});
                },
              ),
            ),
          );
        case AsyncData(:final value):
          _seed(value);
        default:
          return Scaffold(
            appBar: AppBar(title: const Text('Edit block')),
            body: AppRefreshIndicator(
              onRefresh: () async {
                if (widget.blockId != null) {
                  await ref
                      .refresh(blockProvider(widget.blockId!).future)
                      .then<void>((_) {});
                }
              },
              child: const LoadingView(),
            ),
          );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit block' : 'New block')),
      body: AppRefreshIndicator(
        onRefresh: () async {
          if (widget.blockId != null) {
            await ref
                .refresh(blockProvider(widget.blockId!).future)
                .then<void>((_) {});
          }
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
                    title: _isEditing ? 'Edit this block' : 'Add a block',
                    subtitle:
                        'A block is a wing or building within the property. Unit '
                        'numbers are read against it.',
                    compact: true,
                  ),
                  Gap.h16,
                  SectionCard(
                    title: 'Identity',
                    children: [
                      OwnerField(
                        label: 'Block name',
                        controller: _nameController,
                        hint: 'East Wing',
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? 'Give the block a name'
                            : null,
                      ),
                      Gap.h12,
                      OwnerField(
                        label: 'Description',
                        controller: _descriptionController,
                        maxLines: 3,
                        helper: 'Optional.',
                        validator: (_) => null,
                      ),
                      Gap.h12,
                      DropdownButtonFormField<BlockStatus>(
                        initialValue: _status,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: [
                          for (final status in BlockStatus.selectable)
                            DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                        ],
                        onChanged: (value) => setState(
                          () => _status = value ?? BlockStatus.active,
                        ),
                      ),
                    ],
                  ),
                  Gap.h12,
                  SectionCard(
                    title: 'Size',
                    children: [
                      Text(
                        'All optional. Leave a figure blank rather than guessing '
                        'at it.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Gap.h16,
                      NumberField(
                        label: 'Total area',
                        controller: _areaController,
                        suffix: 'sq ft',
                        allowDecimal: true,
                        validator: (_) => null,
                      ),
                      Gap.h12,
                      NumberField(
                        label: 'Number of floors',
                        controller: _floorsController,
                        validator: (_) => null,
                      ),
                      Gap.h12,
                      NumberField(
                        label: 'Total units',
                        controller: _totalUnitsController,
                        validator: (_) => null,
                      ),
                      Gap.h12,
                      NumberField(
                        label: 'Leasable units',
                        controller: _leasableUnitsController,
                        helper:
                            'Units that can be let, excluding service space.',
                        validator: (value) {
                          final leasable = NumberField.parse(value ?? '');
                          final total = NumberField.parse(
                            _totalUnitsController.text,
                          );
                          // The one arithmetic check worth making here: more
                          // lettable units than units at all is a typo, and it
                          // is cheaper to catch now than in a rent roll.
                          return (leasable != null &&
                                  total != null &&
                                  leasable > total)
                              ? 'Cannot exceed the total unit count'
                              : null;
                        },
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
          label: _isEditing ? 'Save changes' : 'Add block',
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
