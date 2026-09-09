import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_bottom_action_bar.dart';
import '../../../components/async_button.dart';
import '../../../components/page_header.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/surface_atoms.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/owner.dart';
import '../application/owner_controller.dart';
import 'widgets/owner_form.dart';

/// Section 88. Moving what a property asks per square metre.
///
/// The screen exists mostly to be honest about what a repricing does. It moves
/// the asking rent on units that are free to move, and it does not touch a unit
/// someone has signed for or one that was priced by hand — so it says so, with
/// the counts, before the owner commits. The counts come from the server for
/// the same reason the rents do: working them out here would be a second
/// implementation of the rule, free to disagree with the one that runs.
class OwnerPropertyRateScreen extends ConsumerStatefulWidget {
  const OwnerPropertyRateScreen({required this.propertyId, super.key});

  final String propertyId;

  @override
  ConsumerState<OwnerPropertyRateScreen> createState() =>
      _OwnerPropertyRateScreenState();
}

class _OwnerPropertyRateScreenState
    extends ConsumerState<OwnerPropertyRateScreen> {
  final _rate = TextEditingController();
  bool _reprice = true;
  bool _seeded = false;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  Money? get _parsed => MoneyField.parse(_rate.text, _currency);
  String _currency = 'KES';

  Future<void> _submit() async {
    final rate = _parsed;
    if (rate == null || !rate.isPositive) return;

    final result = await ref
        .read(ownerActionsProvider)
        .setRatePerSqm(
          propertyId: widget.propertyId,
          rate: rate,
          repriceExistingUnits: _reprice,
        );

    if (!mounted) return;

    switch (result) {
      case Err(:final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ownerFailureMessage(failure))));
      case Ok():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _reprice
                  ? 'Rate updated and unlet units repriced.'
                  : 'Rate updated. Existing units keep their rents.',
            ),
          ),
        );
        context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final performance = ref.watch(
      propertyPerformanceProvider(widget.propertyId),
    );
    final impact = ref.watch(repricingImpactProvider(widget.propertyId));

    // Seeded once, so typing is never overwritten by a rebuild.
    if (!_seeded && performance.hasValue) {
      _seeded = true;
      _currency = performance.requireValue.currency;
      final current = performance.requireValue.rentRatePerSqm;
      if (current != null) _rate.text = current.formatBare();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Asking rate')),
      body: switch (performance) {
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () =>
              ref.invalidate(propertyPerformanceProvider(widget.propertyId)),
        ),
        AsyncData(:final value) => _Body(
          performance: value,
          impact: impact.value,
          rateController: _rate,
          currency: _currency,
          parsed: _parsed,
          reprice: _reprice,
          onRateChanged: () => setState(() {}),
          onRepriceChanged: (value) => setState(() => _reprice = value),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: AppBottomActionBar(
        child: AsyncButton(
          label: 'Update rate',
          expand: true,
          enabled: _parsed != null && _parsed!.isPositive,
          onPressed: _submit,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.performance,
    required this.impact,
    required this.rateController,
    required this.currency,
    required this.parsed,
    required this.reprice,
    required this.onRateChanged,
    required this.onRepriceChanged,
  });

  final PropertyPerformance performance;
  final RepricingImpact? impact;
  final TextEditingController rateController;
  final String currency;
  final Money? parsed;
  final bool reprice;
  final VoidCallback onRateChanged;
  final ValueChanged<bool> onRepriceChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxReadingWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
          children: [
            PageHeader(
              compact: true,
              eyebrow: performance.propertyName,
              title: 'What the property asks',
              subtitle: performance.rateLabel == null
                  ? 'Not currently priced by area.'
                  : 'Currently ${performance.rateLabel}.',
            ),
            Gap.h24,
            MoneyField(
              label: 'Rate',
              controller: rateController,
              currency: currency,
              suffix: 'per m²',
              onChanged: (_) => onRateChanged(),
            ),
            Gap.h16,
            RatePreview(rate: parsed, area: 5000),
            Gap.h24,
            SectionCard(
              title: 'Apply to existing units',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    impact == null
                        ? 'Reprice existing units'
                        : 'Reprice ${impact!.repriceable} unit'
                              '${impact!.repriceable == 1 ? '' : 's'}',
                  ),
                  subtitle: const Text(
                    'Units that are free to move take the new rate.',
                  ),
                  value: reprice,
                  onChanged: onRepriceChanged,
                ),
                if (impact != null && impact!.untouched > 0) ...[
                  Gap.h12,
                  const Hairline(),
                  Gap.h12,
                  Text(
                    'WHAT WILL NOT MOVE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Gap.h8,
                  if (impact!.let > 0)
                    _Note(
                      icon: Icons.lock_outline_rounded,
                      // The rule the whole feature turns on, stated where the
                      // decision is being made rather than buried in a help
                      // page.
                      text:
                          '${impact!.let} let unit'
                          '${impact!.let == 1 ? '' : 's'}. A signed lease keeps '
                          'the rent it was agreed at; the new rate applies when '
                          'the unit next comes free.',
                    ),
                  if (impact!.overridden > 0)
                    _Note(
                      icon: Icons.edit_outlined,
                      text:
                          '${impact!.overridden} unit'
                          '${impact!.overridden == 1 ? '' : 's'} priced by hand. '
                          'Clear the override on a unit to put it back on the '
                          'rate.',
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          Gap.w12,
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
