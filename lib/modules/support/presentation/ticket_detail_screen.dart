import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_bottom_action_bar.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/page_empty_state.dart';
import '../../../components/section_card.dart';
import '../../../components/status_chip.dart';
import '../../../components/surface_atoms.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../navigation/routes.dart';
import '../application/support_controller.dart';
import '../application/support_models.dart';

/// One ticket, read as a conversation.
///
/// The header answers "where has this got to"; the thread answers "what was
/// said". Both are on one screen because a tenant chasing an issue wants the
/// last reply and the status in the same glance.
class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({required this.reference, super.key});

  /// The ticket reference from the path, e.g. `TKT-2041`.
  final String reference;

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _replyController = TextEditingController();
  final _replyFocus = FocusNode();

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  void _sendReply() {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    ref.read(supportTicketsProvider.notifier).reply(widget.reference, text);
    _replyController.clear();
    _replyFocus.unfocus();
  }

  Future<void> _resolve(SupportTicket ticket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.task_alt_rounded),
        title: const Text('Mark as resolved?'),
        content: Text(
          'This tells the desk that ${ticket.reference} is sorted. The thread '
          'stays here, and you can raise a new ticket if it comes back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Mark resolved'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    ref.read(supportTicketsProvider.notifier).resolve(ticket.reference);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${ticket.reference} is marked resolved.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(supportTicketsProvider);
    final ticket = tickets
        .where((candidate) => candidate.reference == widget.reference)
        .firstOrNull;

    if (ticket == null) return _NotFound(reference: widget.reference);

    return Scaffold(
      appBar: AppBar(title: Text(widget.reference)),
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
                    for (final message in ticket.thread)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.md),
                        child: _MessageBubble(message: message),
                      ),
                    if (ticket.status.isLive)
                      Text(
                        'The desk usually answers within one working day.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (ticket.status.isLive) ...[
                Gap.h12,
                AppReveal(
                  index: 2,
                  child: OutlinedButton.icon(
                    onPressed: () => _resolve(ticket),
                    icon: const Icon(Icons.task_alt_rounded),
                    label: const Text('Mark as resolved'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      // The composer lives in the bottom bar so the scaffold lifts it above the
      // keyboard; a reply field at the end of a long thread would be typed at
      // blind otherwise.
      bottomNavigationBar: ticket.status.isLive
          ? AppBottomActionBar(
              child: _ReplyComposer(
                controller: _replyController,
                focusNode: _replyFocus,
                onSend: _sendReply,
              ),
            )
          : _ClosedNote(ticket: ticket),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ToneIconTile(icon: ticket.category.icon, color: tone, size: 44),
              Gap.w12,
              Expanded(
                child: Text(
                  ticket.subject,
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
          DetailRow(label: 'Category', value: ticket.category.label),
          DetailRow(label: 'Priority', value: ticket.priority.label),
          if (ticket.location != null)
            DetailRow(label: 'Where', value: ticket.location!),
          DetailRow(label: 'Raised', value: AppDate.dateTime(ticket.raisedAt)),
          DetailRow(
            label: 'Last update',
            value: AppDate.dateTime(ticket.updatedAt),
          ),
        ],
      ),
    );
  }
}

/// One message in the thread.
///
/// The desk's messages are the ones that carry news, so they get the tinted
/// surface and sit to the left; the tenant's own words are set quieter and to
/// the right. Alignment alone is not enough at large text sizes, where a
/// bubble fills the width either way — hence the colour difference too.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final TicketMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fromSupport = message.fromSupport;

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
            message.author,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: AppTypography.bold,
              color: fromSupport
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
          Gap.h4,
          Text(
            message.body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          Gap.h4,
          Text(
            AppDate.dateTime(message.sentAt),
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

class _ReplyComposer extends StatelessWidget {
  const _ReplyComposer({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            minLines: 1,
            maxLines: 4,
            maxLength: 600,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Write a reply',
              counterText: '',
            ),
          ),
        ),
        Gap.w8,
        // Listens to the field rather than calling setState on every keystroke,
        // which would rebuild the whole thread above it to grey out one button.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final canSend = value.text.trim().isNotEmpty;
            return IconButton.filled(
              onPressed: canSend ? onSend : null,
              icon: const Icon(Icons.send_rounded),
              tooltip: 'Send reply',
            );
          },
        ),
      ],
    );
  }
}

/// What stands in for the composer once a ticket is done.
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

/// A reference that matches nothing — a stale link, or a ticket raised in a
/// session that has since been restarted, which the in-memory store forgets.
class _NotFound extends StatelessWidget {
  const _NotFound({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket')),
      body: PageEmptyState(
        icon: Icons.search_off_rounded,
        caption: 'Support',
        title: 'We cannot find $reference',
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
