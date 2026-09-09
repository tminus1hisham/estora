import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/amount_text.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/record_group.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/owner.dart';
import '../../../domain/enums/domain_enums.dart';
import '../application/owner_controller.dart';
import 'widgets/owner_form.dart';

/// Section 88. Every unit in a property, and what it earns.
///
/// A ledger, so it is a `RecordGroup` — the same anatomy as the invoice list a
/// tenant reads, for the reason `RecordRow` gives: someone who has learned that
/// shape once should not have to learn it again. Grouped by state rather than
/// by number, because "what is empty" is the question this screen is opened to
/// answer.
class OwnerRentRollScreen extends ConsumerWidget {
  const OwnerRentRollScreen({required this.propertyId, super.key});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roll = ref.watch(rentRollProvider(propertyId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Rent roll'),
        backgroundColor: Colors.transparent,
      ),
      body: switch (roll) {
        AsyncLoading() when !roll.hasValue => const AppSkeletonList(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(rentRollProvider(propertyId)),
        ),
        _ => _Roll(
          entries: roll.requireValue,
          propertyId: propertyId,
          onRefresh: () async => ref.invalidate(rentRollProvider(propertyId)),
        ),
      },
    );
  }
}

class _Roll extends StatelessWidget {
  const _Roll({
    required this.entries,
    required this.propertyId,
    required this.onRefresh,
  });

  final List<RentRollEntry> entries;
  final String propertyId;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.meeting_room_outlined,
                title: 'No units yet',
                message: 'Add units to this property to start letting space.',
              ),
            ),
          ],
        ),
      );
    }

    final let = entries.where((entry) => entry.isLet).toList();
    final available = entries
        .where((entry) => !entry.isLet && entry.status == UnitStatus.available)
        .toList();
    final other = entries
        .where((entry) => !entry.isLet && entry.status != UnitStatus.available)
        .toList();

    final groups = <Widget>[
      if (let.isNotEmpty)
        _Group(heading: 'Let', entries: let, propertyId: propertyId),
      if (available.isNotEmpty)
        _Group(
          heading: 'Available',
          entries: available,
          propertyId: propertyId,
        ),
      if (other.isNotEmpty)
        _Group(heading: 'Held', entries: other, propertyId: propertyId),
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            itemCount: groups.length,
            separatorBuilder: (_, _) => Gap.h24,
            itemBuilder: (context, index) =>
                AppReveal(index: index, child: groups[index]),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.heading,
    required this.entries,
    required this.propertyId,
  });

  final String heading;
  final List<RentRollEntry> entries;
  final String propertyId;

  @override
  Widget build(BuildContext context) {
    final statuses = context.statusColors;

    return RecordGroup(
      heading: heading,
      trailing: Text(
        '${entries.length}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      children: [
        for (final entry in entries)
          RecordRow(
            icon: entry.isLet
                ? Icons.storefront_outlined
                : Icons.meeting_room_outlined,
            iconColor: statuses.resolve(entry.status.tone),
            title: entry.unitNumber,
            subtitle: entry.isLet
                ? entry.tenantName
                : (entry.areaLabelOrNull ?? entry.status.label),
            amount: AmountText(
              entry.baseRent,
              color: entry.isInArrears ? statuses.danger : null,
            ),
            caption: entry.rateLabel ?? entry.status.label,
            onTap: () => _editRent(context, entry),
          ),
      ],
    );
  }

  Future<void> _editRent(BuildContext context, RentRollEntry entry) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _RentSheet(entry: entry, propertyId: propertyId),
      );
}

extension on RentRollEntry {
  String? get areaLabelOrNull {
    final area = this.area;
    if (area == null) return null;
    final trimmed = area == area.roundToDouble()
        ? area.toInt().toString()
        : area.toString();
    return '$trimmed $areaUnit';
  }
}

/// Pricing one unit by hand, or putting it back on the rate.
class _RentSheet extends ConsumerStatefulWidget {
  const _RentSheet({required this.entry, required this.propertyId});

  final RentRollEntry entry;
  final String propertyId;

  @override
  ConsumerState<_RentSheet> createState() => _RentSheetState();
}

class _RentSheetState extends ConsumerState<_RentSheet> {
  late final TextEditingController _rent = TextEditingController(
    text: widget.entry.baseRent.formatBare(),
  );

  bool _busy = false;

  @override
  void dispose() {
    _rent.dispose();
    super.dispose();
  }

  String get _currency => widget.entry.baseRent.currency;

  Future<void> _apply({required bool clear}) async {
    final override = clear ? null : MoneyField.parse(_rent.text, _currency);
    if (!clear && override == null) return;

    setState(() => _busy = true);
    final result = await ref
        .read(ownerActionsProvider)
        .setUnitRent(
          unitId: widget.entry.unitId,
          propertyId: widget.propertyId,
          override: override,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case Err(:final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ownerFailureMessage(failure))));
      case Ok():
        Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        Gap.lg,
        Gap.lg,
        MediaQuery.viewInsetsOf(context).bottom + Gap.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(entry.unitNumber, style: theme.textTheme.titleLarge),
          Gap.h4,
          Text(
            entry.isLet
                ? 'Let to ${entry.tenantName}. Changing this moves the asking '
                      'price, not the rent on the signed lease.'
                : entry.rateLabel ?? 'Priced by hand.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Gap.h24,
          MoneyField(
            label: 'Monthly rent',
            controller: _rent,
            currency: _currency,
          ),
          Gap.h24,
          FilledButton(
            onPressed: _busy ? null : () => _apply(clear: false),
            child: const Text('Set this rent'),
          ),
          if (entry.rentOverridden) ...[
            Gap.h8,
            TextButton(
              onPressed: _busy ? null : () => _apply(clear: true),
              child: const Text('Put back on the property rate'),
            ),
          ],
          if (entry.leaseEndDate != null) ...[
            Gap.h16,
            Text(
              'Lease ends ${AppDate.short(entry.leaseEndDate!)}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
