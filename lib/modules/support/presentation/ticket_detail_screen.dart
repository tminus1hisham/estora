import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_bottom_action_bar.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/async_button.dart';
import '../../../components/page_empty_state.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../components/surface_atoms.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../navigation/routes.dart';
import '../application/support_controller.dart';
import '../application/support_models.dart';
import 'new_ticket_screen.dart';

/// One ticket: where it has got to, what the tenant reported, and what the
/// desk said back.
///
/// The contract keeps one comment per ticket and one answer from the desk
/// (`approvalRemarks`) — there is no reply route. So the tenant's side of the
/// conversation is edited rather than added to, and closing is theirs to do.
class TicketDetailScreen extends ConsumerWidget {
  const TicketDetailScreen({required this.ticketId, super.key});

  /// The ticket's id from the path.
  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(supportTicketsProvider);

    return switch (tickets) {
      AsyncLoading() when !tickets.hasValue => Scaffold(
        appBar: AppBar(title: const Text('Ticket')),
        body: const LoadingView(),
      ),
      AsyncError(:final error) when !tickets.hasValue => Scaffold(
        appBar: AppBar(title: const Text('Ticket')),
        body: ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.read(supportTicketsProvider.notifier).refresh(),
        ),
      ),
      _ => switch (tickets.requireValue
          .where((candidate) => candidate.id == ticketId)
          .firstOrNull) {
        null => _NotFound(ticketId: ticketId),
        final ticket => _TicketView(ticket: ticket),
      },
    };
  }
}

class _TicketView extends ConsumerWidget {
  const _TicketView({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final remarks = ticket.approvalRemarks;

    return Scaffold(
      appBar: AppBar(title: Text(ticket.reference)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
            children: [
              AppReveal(child: _TicketHeader(ticket: ticket)),
              Gap.h12,
              AppReveal(
                index: 1,
                child: SectionCard(
                  title: 'Conversation',
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.md),
                      child: _MessageBubble(
                        author: ticket.createdByName ?? 'You',
                        body: ticket.comment,
                        sentAt: ticket.createdAt,
                      ),
                    ),
                    if (remarks != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.md),
                        child: _MessageBubble(
                          author:
                              ticket.approvedByName ??
                              (ticket.remarksFromSupport
                                  ? 'Support desk'
                                  : 'You'),
                          body: remarks,
                          sentAt: ticket.updatedAt,
                          fromSupport: ticket.remarksFromSupport,
                        ),
                      )
                    else if (ticket.status.isLive)
                      Text(
                        'The desk usually answers within one working day.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ticket.status.isLive
          ? AppBottomActionBar(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _edit(context, ticket),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                  Gap.w12,
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _close(context, ref, ticket),
                      icon: const Icon(Icons.task_alt_rounded),
                      label: const Text('Close ticket'),
                    ),
                  ),
                ],
              ),
            )
          : _ClosedNote(ticket: ticket),
    );
  }

  Future<void> _edit(BuildContext context, SupportTicket ticket) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditSheet(ticket: ticket),
    );
    if (saved != true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${ticket.reference} is updated.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _close(
    BuildContext context,
    WidgetRef ref,
    SupportTicket ticket,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    // Null is "Not yet"; a string, possibly empty, is the note to send.
    final remarks = await showDialog<String>(
      context: context,
      builder: (_) => _CloseDialog(reference: ticket.reference),
    );
    if (remarks == null) return;

    final result = await ref
        .read(supportTicketsProvider.notifier)
        .close(ticket.id, remarks: remarks);
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (result) {
          Ok() => '${ticket.reference} is closed.',
          Err(:final failure) => failure.message,
        }),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _TicketHeader extends StatelessWidget {
  const _TicketHeader({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = context.statusColors.resolve(ticket.status.tone);

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ToneIconTile(icon: ticket.category.icon, color: tone, size: 44),
              Gap.w12,
              Expanded(
                child: Text(
                  ticket.category.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
            ],
          ),
          Gap.h12,
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(label: ticket.status.label, tone: ticket.status.tone),
              Text(
                ticket.reference,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          Gap.h8,
          if (ticket.propertyName case final property?)
            DetailRow(label: 'Property', value: property),
          DetailRow(label: 'Raised', value: AppDate.dateTime(ticket.createdAt)),
          DetailRow(
            label: 'Last update',
            value: AppDate.dateTime(ticket.updatedAt),
          ),
        ],
      ),
    );
  }
}

/// One side of the conversation.
///
/// The desk's answer is the one that carries news, so it gets the tinted
/// surface and sits to the left; the tenant's own words are set quieter and
/// to the right. Alignment alone is not enough at large text sizes, where a
/// bubble fills the width either way — hence the colour difference too.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.author,
    required this.body,
    required this.sentAt,
    this.fromSupport = false,
  });

  final String author;
  final String body;
  final DateTime sentAt;
  final bool fromSupport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final bubble = Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: fromSupport
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.md),
          topRight: const Radius.circular(AppRadius.md),
          bottomLeft: Radius.circular(
            fromSupport ? AppRadius.xs : AppRadius.md,
          ),
          bottomRight: Radius.circular(
            fromSupport ? AppRadius.md : AppRadius.xs,
          ),
        ),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            author,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: AppTypography.bold,
              color: fromSupport
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
          Gap.h4,
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
          Gap.h4,
          Text(
            AppDate.dateTime(sentAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    return Row(
      mainAxisAlignment: fromSupport
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      children: [
        // Flexible, not a fraction of the width: the bubble takes what it
        // needs up to the full column and never overflows a narrow screen.
        Flexible(child: bubble),
      ],
    );
  }
}

/// Edits the ticket's category and comment. The contract's update takes the
/// whole request, so property, unit and attachments go back as they were.
class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.ticket});

  final SupportTicket ticket;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _comment = TextEditingController(text: widget.ticket.comment);
  late SupportCategory _category = widget.ticket.category;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final result = await ref
        .read(supportTicketsProvider.notifier)
        .edit(
          widget.ticket.id,
          widget.ticket.toDraft().copyWith(
            category: _category,
            comment: _comment.text.trim(),
          ),
        );
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop(true);
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
    return Padding(
      // Lifts the sheet clear of the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
          children: [
            Text(
              'Edit ${widget.ticket.reference}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Gap.h16,
            CategoryChips(
              selected: _category,
              onSelected: (category) => setState(() => _category = category),
            ),
            Gap.h16,
            TicketCommentField(controller: _comment),
            Gap.h8,
            AsyncButton(
              label: 'Save changes',
              loadingLabel: 'Saving…',
              icon: Icons.check_rounded,
              expand: true,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirms a close, with room for a note to the desk. Stateful so the note's
/// controller lives exactly as long as the dialog does, exit animation
/// included.
class _CloseDialog extends StatefulWidget {
  const _CloseDialog({required this.reference});

  final String reference;

  @override
  State<_CloseDialog> createState() => _CloseDialogState();
}

class _CloseDialogState extends State<_CloseDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.task_alt_rounded),
      title: const Text('Close this ticket?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This tells the desk that ${widget.reference} is sorted. You can '
            'raise a new ticket if it comes back.',
          ),
          Gap.h12,
          TextField(
            controller: _note,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'A note for the desk (optional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not yet'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_note.text),
          child: const Text('Close ticket'),
        ),
      ],
    );
  }
}

/// What stands in for the actions once a ticket is done.
class _ClosedNote extends StatelessWidget {
  const _ClosedNote({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppBottomActionBar(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, color: scheme.primary),
          Gap.w12,
          Expanded(
            child: Text(
              'This ticket is ${ticket.status.label.toLowerCase()}. Raise a new '
              'one if the problem returns.',
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

/// An id that matches nothing in the list — a stale link, or a ticket that
/// belongs to another account.
class _NotFound extends StatelessWidget {
  const _NotFound({required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket')),
      body: PageEmptyState(
        icon: Icons.search_off_rounded,
        caption: 'Support',
        title: 'We cannot find TKT-$ticketId',
        message:
            'This ticket is not in your list. It may have been raised on '
            'another account, or the link may be out of date.',
        action: FilledButton.tonalIcon(
          onPressed: () => context.goNamed(Routes.support),
          icon: const Icon(Icons.list_alt_rounded),
          label: const Text('See all tickets'),
        ),
      ),
    );
  }
}
