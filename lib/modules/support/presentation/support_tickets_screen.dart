import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/page_empty_state.dart';
import '../../../components/page_header.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../components/surface_atoms.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../navigation/routes.dart';
import '../application/support_controller.dart';
import '../application/support_models.dart';

/// Everything the tenant has raised, and where it has got to, read from
/// `tickets/get/all`.
class SupportTicketsScreen extends ConsumerWidget {
  const SupportTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(supportTicketsProvider);
    final filter = ref.watch(ticketFilterProvider);
    Future<void> refresh() =>
        ref.read(supportTicketsProvider.notifier).refresh();

    return Scaffold(
      appBar: AppBar(title: const Text('Support tickets')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
            child: PageHeader(
              compact: true,
              title: 'How can we help?',
              subtitle:
                  'Raise an issue with your space and follow it to an answer.',
            ),
          ),
          _StatusFilters(filter: filter),
          Expanded(
            child: switch (tickets) {
              AsyncLoading() when !tickets.hasValue => const AppSkeletonList(),
              AsyncError(:final error) when !tickets.hasValue => ErrorView(
                failure: error is Failure
                    ? error
                    : UnknownFailure(error.toString()),
                onRetry: refresh,
              ),
              _ => _TicketBody(
                tickets: tickets.requireValue,
                filter: filter,
                onRefresh: refresh,
              ),
            },
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

class _TicketBody extends StatelessWidget {
  const _TicketBody({
    required this.tickets,
    required this.filter,
    required this.onRefresh,
  });

  final List<SupportTicket> tickets;
  final TicketStatus? filter;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final visible = filter == null
        ? tickets
        : tickets.where((ticket) => ticket.status == filter).toList();

    if (visible.isEmpty) {
      return _NoMatches(filter: filter, onRefresh: onRefresh);
    }
    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: _TicketList(tickets: visible),
    );
  }
}

/// The status chips, one per state a ticket can be in.
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
          for (final status in TicketStatus.values)
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

    return AppSurfaceCard(
      onTap: () => context.pushNamed(
        Routes.ticketDetail,
        pathParameters: {'ticketId': ticket.id},
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
                      ticket.category.label,
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
          // Wrap, not Row: at 320 with large text the chip and the property
          // will not share a line, and they should stack instead of clipping.
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(label: ticket.status.label, tone: ticket.status.tone),
              if (ticket.propertyName case final property?)
                Text(
                  property,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          Gap.h12,
          // The desk's answer, when there is one, is the news; otherwise the
          // tenant's own words remind them which ticket this is.
          Text(
            switch (ticket.approvalRemarks) {
              final remarks? when ticket.remarksFromSupport =>
                'Support: $remarks',
              _ => ticket.comment,
            },
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          Gap.h8,
          Text(
            'Raised ${AppDate.short(ticket.createdAt)} · '
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
  const _NoMatches({required this.filter, required this.onRefresh});

  final TicketStatus? filter;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = filter;

    return PageEmptyState(
      icon: status == null
          ? Icons.support_agent_outlined
          : Icons.filter_alt_off_outlined,
      caption: 'Support',
      onRefresh: onRefresh,
      title: status == null
          ? 'No tickets yet'
          : 'Nothing ${status.label.toLowerCase()}',
      message: status == null
          ? 'Anything you raise about your space will be tracked here, '
                'along with the answer from the desk.'
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
