import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_reveal.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/page_empty_state.dart';
import '../../../components/page_header.dart';
import '../../../components/status_chip.dart';
import '../../../components/surface_atoms.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../navigation/routes.dart';
import '../application/support_controller.dart';
import '../application/support_models.dart';

/// Everything the tenant has raised about their space, and where it has got to.
///
/// The screen is honest about being a preview: there is no support endpoint
/// yet, so the list is seeded sample data plus whatever is raised in-session.
/// Saying so once, calmly, near the top is better than letting a tenant file a
/// real problem into a notebook that nobody reads.
class SupportTicketsScreen extends ConsumerWidget {
  const SupportTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(supportTicketsProvider);
    final filter = ref.watch(ticketFilterProvider);
    final visible = filter == null
        ? tickets
        : tickets.where((ticket) => ticket.status == filter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Support tickets')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
            child: _Intro(),
          ),
          _StatusFilters(filter: filter),
          Expanded(
            child: visible.isEmpty
                ? _NoMatches(filter: filter)
                : _TicketList(tickets: visible),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(Routes.newTicket),
        icon: const Icon(Icons.support_agent_outlined),
        label: const Text('Raise a ticket'),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
          compact: true,
          title: 'How can we help?',
          subtitle:
              'Raise an issue with your space and follow it to an answer.',
        ),
        Gap.h12,
        // Set as a quiet row rather than a banner: it is a caveat, not news.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            Gap.w8,
            Expanded(
              child: Text(
                'A preview with sample tickets until the support desk is '
                'connected.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The status chips. `closed` has no chip of its own — nothing seeds one and a
/// tenant never closes a ticket from here — but "All" still shows it if the
/// desk ever sends one down.
class _StatusFilters extends ConsumerWidget {
  const _StatusFilters({required this.filter});

  final TicketStatus? filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void select(TicketStatus? status) =>
        ref.read(ticketFilterProvider.notifier).select(status);

    // A scroll view rather than a fixed-height strip: at large text sizes a
    // chip is taller than any height worth hard-coding.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: Gap.sm),
            child: FilterChip(
              label: const Text('All'),
              selected: filter == null,
              onSelected: (_) => select(null),
            ),
          ),
          for (final status in const [
            TicketStatus.open,
            TicketStatus.inProgress,
            TicketStatus.resolved,
          ])
            Padding(
              padding: const EdgeInsets.only(right: Gap.sm),
              child: FilterChip(
                label: Text(status.label),
                selected: filter == status,
                onSelected: (selected) => select(selected ? status : null),
              ),
            ),
        ],
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  const _TicketList({required this.tickets});

  final List<SupportTicket> tickets;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // Room for the extended action button to sit over the last card.
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 104),
      itemCount: tickets.length,
      itemBuilder: (context, index) => AppReveal(
        index: index,
        child: Padding(
          padding: const EdgeInsets.only(bottom: Gap.md),
          child: _TicketCard(ticket: tickets[index]),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = context.statusColors.resolve(ticket.status.tone);
    final latest = ticket.latestMessage;

    return AppSurfaceCard(
      onTap: () => context.pushNamed(
        Routes.ticketDetail,
        pathParameters: {'reference': ticket.reference},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ToneIconTile(icon: ticket.category.icon, color: tone),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.reference,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Gap.h4,
                    Text(
                      ticket.subject,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: AppTypography.semibold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap.h12,
          // Wrap, not Row: at 320 with large text the chip and the category
          // will not share a line, and they should stack instead of clipping.
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(label: ticket.status.label, tone: ticket.status.tone),
              Text(
                ticket.category.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (latest != null) ...[
            Gap.h12,
            Text(
              '${latest.fromSupport ? 'Support' : 'You'}: ${latest.body}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          Gap.h8,
          Text(
            'Raised ${AppDate.short(ticket.raisedAt)} · '
            'updated ${AppDate.relativeDays(ticket.updatedAt)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoMatches extends ConsumerWidget {
  const _NoMatches({required this.filter});

  final TicketStatus? filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = filter;

    return PageEmptyState(
      icon: status == null
          ? Icons.support_agent_outlined
          : Icons.filter_alt_off_outlined,
      caption: 'Support',
      title: status == null
          ? 'No tickets yet'
          : 'Nothing ${status.label.toLowerCase()}',
      message: status == null
          ? 'Anything you raise about your space will be tracked here, with '
                'every reply kept in one thread.'
          : 'No tickets are sitting at this status. Clear the filter to see '
                'everything you have raised.',
      action: status != null
          ? FilledButton.tonalIcon(
              onPressed: () =>
                  ref.read(ticketFilterProvider.notifier).select(null),
              icon: const Icon(Icons.clear_rounded),
              label: const Text('Show all tickets'),
            )
          : FilledButton.icon(
              onPressed: () => context.pushNamed(Routes.newTicket),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Raise a ticket'),
            ),
    );
  }
}
