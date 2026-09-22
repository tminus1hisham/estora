import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/app_surface_card.dart';
import '../../../../components/status_chip.dart';
import '../../../../components/surface_atoms.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../application/utility_controller.dart';
import '../../application/utility_models.dart';

/// How each service is drawn.
///
/// The colours come from the status palette rather than from new constants, so
/// water and electricity stay legible in both themes without this module
/// owning any colour of its own. They are used as identity, not as judgement —
/// what a meter is, never how worried to be about it, which is what the status
/// chip beside them is for.
extension UtilityVisuals on UtilityKind {
  IconData get icon => switch (this) {
    UtilityKind.water => Icons.water_drop_outlined,
    UtilityKind.electricity => Icons.bolt_outlined,
  };

  StatusTone get tone => switch (this) {
    UtilityKind.water => StatusTone.progress,
    UtilityKind.electricity => StatusTone.warning,
  };

  Color colorIn(BuildContext context) => context.statusColors.resolve(tone);
}

/// The one line that says what this screen is.
///
/// Deliberately a line of body text with an icon rather than a tinted banner:
/// nothing is wrong, nothing needs doing, and a warning-coloured box would
/// have a tenant reading the page for a problem that is not there.
class UtilityPreviewNote extends StatelessWidget {
  const UtilityPreviewNote({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        Gap.w8,
        Expanded(
          child: Text(
            'Your meters are not connected yet — these are sample figures so '
            'you can see how this will work.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// One meter, as a card on the overview.
class UtilityAccountCard extends StatelessWidget {
  const UtilityAccountCard({
    required this.account,
    required this.onTap,
    super.key,
  });

  final UtilityAccount account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kind = account.kind;
    final color = kind.colorIn(context);

    return AppSurfaceCard(
      onTap: onTap,
      semanticLabel: '${kind.label} meter',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BadgedHeader(
            badge: StatusChip(
              label: account.status.label,
              tone: account.status.tone,
              dense: true,
            ),
            child: Row(
              children: [
                ToneIconTile(icon: kind.icon, color: color, size: 40),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        kind.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                      Gap.h4,
                      Text(
                        '${account.supplier} · ${account.meterNumber}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Gap.h16,
          const Hairline(),
          Gap.h16,
          UtilityUsageSummary(account: account),
          Gap.h16,
          StatRow(
            left: Stat(
              'Amount due',
              builder: (context, align) => AmountText(
                account.amountDue,
                scale: AmountScale.title,
                align: align,
                color: account.status == UtilityBillStatus.overdue
                    ? scheme.error
                    : scheme.onSurface,
              ),
            ),
            right: Stat(
              'Latest reading',
              value: kind.formatQuantity(account.latestReading),
            ),
          ),
          Gap.h8,
          Text(
            'Read ${AppDate.relativeDays(account.readingDate)} · '
            '${AppDate.short(account.readingDate)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// This month's use against last month's.
///
/// The bar is a genuine proportion — the smaller month as a fraction of the
/// larger — so a month that is running ahead fills it and a quiet month does
/// not. The sentence underneath carries the direction, because a bar alone
/// cannot say which way round the two months are.
class UtilityUsageSummary extends StatelessWidget {
  const UtilityUsageSummary({required this.account, super.key});

  final UtilityAccount account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kind = account.kind;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Gap.md,
          runSpacing: Gap.xs,
          children: [
            Text(
              'This month',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Text(
              kind.formatQuantity(account.consumption),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: AppTypography.semibold,
              ),
            ),
          ],
        ),
        Gap.h8,
        LinearMeter(
          value: account.consumptionRatio,
          color: kind.colorIn(context),
        ),
        Gap.h8,
        Text(
          _comparison(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _comparison() {
    final kind = account.kind;
    final last = kind.formatQuantity(account.previousConsumption);
    final change = account.consumptionChange;
    if (change == null) return 'Last month $last';

    final percent = (change.abs() * 100).round();
    if (percent == 0) return 'Last month $last · about the same';
    return 'Last month $last · ${change > 0 ? 'up' : 'down'} $percent%';
  }
}

/// One month of the history, on the detail screen.
class UtilityUsageBar extends StatelessWidget {
  const UtilityUsageBar({
    required this.kind,
    required this.reading,
    required this.peak,
    super.key,
  });

  final UtilityKind kind;
  final UtilityReading reading;

  /// The tallest month in the run. Every bar is drawn against it so the six
  /// months can be compared by eye, which is the only reason to draw them.
  final double peak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Gap.md,
            runSpacing: Gap.xs,
            children: [
              Text(
                AppDate.monthYear(reading.period),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: AppTypography.semibold,
                ),
              ),
              Text(
                '${kind.formatQuantity(reading.consumption)} · '
                '${reading.cost.format()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Gap.h8,
          LinearMeter(
            value: peak <= 0 ? 0 : reading.consumption / peak,
            color: kind.colorIn(context),
          ),
        ],
      ),
    );
  }
}

/// One bill.
///
/// [onMarkPaid] is only offered where settling a bill is part of what the
/// screen is for; the overview lists bills to be read, not acted on.
class UtilityBillTile extends StatelessWidget {
  const UtilityBillTile({
    required this.bill,
    this.showKind = true,
    this.onMarkPaid,
    super.key,
  });

  final UtilityBill bill;
  final bool showKind;
  final VoidCallback? onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settled = bill.status.isSettled;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BadgedHeader(
            badge: StatusChip(
              label: bill.status.label,
              tone: bill.status.tone,
              dense: true,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppDate.monthYear(bill.period),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: AppTypography.semibold,
                  ),
                ),
                Gap.h4,
                Text(
                  [
                    if (showKind) bill.kind.label,
                    bill.reference,
                    settled ? 'Settled' : 'Due ${AppDate.short(bill.dueOn)}',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Gap.h8,
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Gap.md,
            runSpacing: Gap.xs,
            children: [
              AmountText(
                bill.amount,
                color: bill.status == UtilityBillStatus.overdue
                    ? scheme.error
                    : scheme.onSurface,
              ),
              if (onMarkPaid != null && !settled)
                TextButton(
                  onPressed: onMarkPaid,
                  child: const Text('Mark paid'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opens the reading form.
///
/// [kind] pins the sheet to one meter, which is what the detail screen wants.
/// Opened from the overview it is left null and the tenant picks, rather than
/// the sheet guessing and quietly filing a reading against the wrong service.
Future<void> showSubmitReadingSheet(BuildContext context, {UtilityKind? kind}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _SubmitReadingSheet(initialKind: kind),
  );
}

class _SubmitReadingSheet extends ConsumerStatefulWidget {
  const _SubmitReadingSheet({this.initialKind});

  final UtilityKind? initialKind;

  @override
  ConsumerState<_SubmitReadingSheet> createState() =>
      _SubmitReadingSheetState();
}

class _SubmitReadingSheetState extends ConsumerState<_SubmitReadingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reading = TextEditingController();

  late UtilityKind _kind = widget.initialKind ?? UtilityKind.water;

  bool get _locked => widget.initialKind != null;

  @override
  void dispose() {
    _reading.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final value = double.parse(_reading.text.trim());
    final messenger = ScaffoldMessenger.of(context);
    ref.read(utilityAccountsProvider.notifier).submitReading(_kind, value);
    Navigator.of(context).pop();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          '${_kind.label} reading of ${_kind.formatQuantity(value)} recorded '
          'in this preview. Nothing was sent to your supplier.',
        ),
      ),
    );
  }

  String? _validate(String? input, UtilityAccount account) {
    final text = input?.trim() ?? '';
    if (text.isEmpty) return 'Enter the figure showing on your meter.';

    final value = double.tryParse(text);
    if (value == null) return 'Use digits only, like 1420.5';

    // A dial only counts up. A figure below the one the month opened at is a
    // misread or a fault — either way it is not a reading to file.
    if (value < account.previousReading) {
      return 'This month opened at '
          '${_kind.formatQuantity(account.previousReading)}. A meter cannot '
          'read lower than that.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final account = ref.watch(utilityAccountProvider(_kind));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Submit a meter reading',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                Gap.h8,
                Text(
                  'Read the figure off the dial and enter it here. It updates '
                  'this preview only — nothing reaches your supplier yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Gap.h16,
                if (!_locked) ...[
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.sm,
                    children: [
                      for (final kind in UtilityKind.values)
                        ChoiceChip(
                          label: Text(kind.label),
                          avatar: Icon(kind.icon, size: 18),
                          selected: _kind == kind,
                          onSelected: (selected) {
                            if (!selected) return;
                            setState(() => _kind = kind);
                            // The validator reads the newly chosen meter's
                            // opening figure, so anything already typed is
                            // re-checked against it rather than left standing.
                            _formKey.currentState?.validate();
                          },
                        ),
                    ],
                  ),
                  Gap.h16,
                ],
                TextFormField(
                  controller: _reading,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Current reading',
                    suffixText: _kind.unit,
                    helperText:
                        'Last read ${_kind.formatQuantity(account.latestReading)} '
                        'on ${AppDate.short(account.readingDate)}',
                    helperMaxLines: 3,
                    errorMaxLines: 3,
                  ),
                  validator: (value) => _validate(value, account),
                  onFieldSubmitted: (_) => _submit(),
                ),
                Gap.h24,
                SurfaceAction(
                  label: 'Submit reading',
                  icon: Icons.speed_rounded,
                  primary: true,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
