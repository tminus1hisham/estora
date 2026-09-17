import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/app_glass.dart';
import '../../../../components/app_surface_card.dart';
import '../../../../components/surface_atoms.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/billing.dart';
import '../../../../navigation/routes.dart';
import 'pay_invoice.dart';

/// The invoice the tenant is going to have to deal with next.
///
/// The screen used to open on a count — "3 outstanding" — which is a fact about
/// the list rather than about the tenant's week. The soonest-due payable
/// invoice is the thing they came to find, so it is lifted out of the list,
/// given the figure at reading size and a way to pay it.
///
/// Nothing here is summed. Section 84 rule 7 puts totalling on the server and
/// section 65 keeps payable amounts off the client, so the card shows one
/// server-supplied `amountDue` rather than a total it worked out itself. The
/// tab counts below say how many others there are.
class InvoiceFocusCard extends StatelessWidget {
  const InvoiceFocusCard({required this.invoices, super.key});

  final List<Invoice> invoices;

  /// The soonest-due invoice the tenant can actually pay, if there is one.
  static Invoice? focusOf(List<Invoice> invoices) {
    final payable = invoices.where((invoice) => invoice.isPayable).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return payable.isEmpty ? null : payable.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focus = focusOf(invoices);

    return AppSurfaceCard(
      gradient: AppGradients.brandHero,
      borderColor: Colors.transparent,
      // Zero so the glows can run off the edges; the content brings its own.
      padding: EdgeInsets.zero,
      shadows: AppElevation.lifted(
        AppPalette.navy950,
        level: 3,
        brightness: theme.brightness,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: SoftGlow(
              color:
                  (focus?.isOverdue ?? false
                          ? AppPalette.red300
                          : AppPalette.azure500)
                      .withValues(alpha: 0.34),
              size: 220,
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: SoftGlow(
              color: AppPalette.brass500.withValues(alpha: 0.1),
              size: 240,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: focus == null
                ? const _SettledBody()
                : _DueBody(invoice: focus),
          ),
        ],
      ),
    );
  }
}

/// The card when something is owed.
class _DueBody extends StatelessWidget {
  const _DueBody({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = invoice.daysUntilDue;
    final tone = invoice.isOverdue
        ? StatusTone.danger
        : days <= 3
        ? StatusTone.warning
        : StatusTone.progress;
    final toneColor = StatusColors.dark.resolve(tone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BadgedHeader(
          badge: TonePill(
            label: invoice.status.label,
            tone: invoice.status.tone,
          ),
          child: Text(
            invoice.isOverdue ? 'PAST DUE' : 'DUE NEXT',
            style: theme.textTheme.labelSmall?.copyWith(
              color: kOnDark.withValues(alpha: 0.62),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Gap.h12,
        AmountText(
          invoice.amountDue,
          scale: AmountScale.hero,
          color: invoice.isOverdue ? AppPalette.red300 : kOnDark,
        ),
        Gap.h8,
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: _urgency(days, invoice.isOverdue),
                style: TextStyle(
                  color: toneColor,
                  fontWeight: AppTypography.semibold,
                ),
              ),
              TextSpan(
                text: ' · ${AppDate.full(invoice.dueDate)}',
                style: TextStyle(color: kOnDark.withValues(alpha: 0.62)),
              ),
            ],
          ),
          style: theme.textTheme.bodyMedium,
        ),
        Gap.h16,
        GlassSurface(
          onDark: true,
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatRow(
                onDark: true,
                left: Stat('Invoice', value: invoice.invoiceNumber),
                right: Stat('For', value: _period(invoice)),
              ),
              Gap.h16,
              // Time used up rather than time left, so a nearly full bar always
              // means "act soon". Overdue reads as full.
              LinearMeter(
                value: 1 - (days.clamp(0, 30) / 30),
                color: toneColor,
                trackColor: kOnDark.withValues(alpha: 0.16),
              ),
            ],
          ),
        ),
        Gap.h24,
        _Actions(invoice: invoice),
      ],
    );
  }

  static String _urgency(int days, bool overdue) {
    if (overdue || days < 0) {
      final late = days.abs();
      return late == 0
          ? 'Payment overdue'
          : 'Overdue by $late ${late == 1 ? 'day' : 'days'}';
    }
    return switch (days) {
      0 => 'Due today',
      1 => 'Due tomorrow',
      _ => 'Due in $days days',
    };
  }

  /// What the invoice is for, in as few words as it can be said.
  static String _period(Invoice invoice) {
    if (invoice.hasBillingPeriod) {
      return AppDate.monthYear(invoice.billingPeriodStart!);
    }
    if (invoice.lines.isNotEmpty) return invoice.lines.first.lineType.label;
    return invoice.unitNumber == null ? '—' : 'Unit ${invoice.unitNumber}';
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pay = OnDarkAction(
      label: 'Pay now',
      icon: Icons.phone_android_rounded,
      style: OnDarkActionStyle.primary,
      onPressed: () => payInvoice(context, ref, invoice),
    );
    final open = OnDarkAction(
      label: 'View invoice',
      onPressed: () => context.pushNamed(
        Routes.invoiceDetail,
        pathParameters: {'invoiceId': invoice.id},
      ),
    );

    return ActionRow(actions: [pay, open]);
  }
}

/// The card when nothing is owed.
///
/// Kept on the same dark surface as the due state rather than swapped for a
/// cheerful green panel: a tenant who is up to date should recognise the same
/// object, holding better news.
class _SettledBody extends StatelessWidget {
  const _SettledBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = StatusColors.dark.positive;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ToneIconTile(
          icon: Icons.check_rounded,
          color: positive,
          size: 44,
          onDark: true,
        ),
        Gap.w16,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nothing outstanding',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: kOnDark,
                  fontWeight: AppTypography.semibold,
                ),
              ),
              Gap.h4,
              Text(
                'Every invoice raised against your lease has been settled. '
                'The next one will appear here when it is issued.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: kOnDark.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
