import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'support_models.dart';

/// The status filter on the tickets screen. Null is "All".
final ticketFilterProvider =
    NotifierProvider<TicketFilterController, TicketStatus?>(
      TicketFilterController.new,
    );

class TicketFilterController extends Notifier<TicketStatus?> {
  @override
  TicketStatus? build() => null;

  void select(TicketStatus? status) => state = status;
}

/// Every ticket the tenant has, newest first.
///
/// There is no support endpoint yet, so this notifier *is* the store: the seed
/// below is the whole history, and anything raised in-session lives beside it
/// until the app is restarted. It is a plain `NotifierProvider` rather than the
/// `AsyncNotifierProvider` the API-backed features use, because pretending to
/// load would mean pretending to fail, and the screens would grow error and
/// retry paths that can never fire. When the desk is connected this becomes an
/// AsyncNotifier and the screens gain those states then, honestly.
final supportTicketsProvider =
    NotifierProvider<SupportTicketController, List<SupportTicket>>(
      SupportTicketController.new,
    );

class SupportTicketController extends Notifier<List<SupportTicket>> {
  @override
  List<SupportTicket> build() => _seed();

  /// Files a new ticket and returns it, so the caller can show the reference it
  /// was given without going looking for it in the new state.
  SupportTicket raise({
    required String subject,
    required String description,
    required SupportCategory category,
    required TicketPriority priority,
    String? location,
  }) {
    final now = DateTime.now();
    final ticket = SupportTicket(
      reference: _nextReference(),
      subject: subject,
      description: description,
      category: category,
      priority: priority,
      status: TicketStatus.open,
      location: location,
      raisedAt: now,
      updatedAt: now,
      // The description opens the conversation rather than sitting outside it.
      // A tenant reading the thread later should find the first thing they
      // said in its proper place, not only in a header above it.
      thread: [TicketMessage(author: 'You', body: description, sentAt: now)],
    );
    state = [ticket, ...state];
    return ticket;
  }

  void reply(String reference, String body) {
    final text = body.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    // Status is left alone: a reply to a ticket nobody has picked up yet does
    // not move it along, and only the desk can say that it has. The fresh
    // timestamp is the honest signal that something happened.
    _update(
      reference,
      (ticket) => ticket.copyWith(
        thread: [
          ...ticket.thread,
          TicketMessage(author: 'You', body: text, sentAt: now),
        ],
        updatedAt: now,
      ),
    );
  }

  void resolve(String reference) {
    final now = DateTime.now();
    _update(
      reference,
      (ticket) => ticket.copyWith(
        status: TicketStatus.resolved,
        updatedAt: now,
        // The thread carries the reason it closed, so the ticket still reads
        // as a conversation rather than a record that changed on its own.
        thread: [
          ...ticket.thread,
          TicketMessage(
            author: 'You',
            body: 'Marked this as resolved.',
            sentAt: now,
          ),
        ],
      ),
    );
  }

  /// Rebuilds the list with one ticket replaced. Order is left alone on
  /// purpose: a list that reshuffled itself under a tenant's thumb because
  /// they answered a message is a list they would lose their place in.
  void _update(
    String reference,
    SupportTicket Function(SupportTicket ticket) change,
  ) {
    state = [
      for (final ticket in state)
        if (ticket.reference == reference) change(ticket) else ticket,
    ];
  }

  /// The next reference, one past the highest already in hand.
  ///
  /// The real desk will allocate these server-side. Counting locally is enough
  /// for the references to read as a sequence rather than as random numbers.
  String _nextReference() {
    final digits = RegExp(r'(\d+)$');
    var highest = 2040;
    for (final ticket in state) {
      final match = digits.firstMatch(ticket.reference);
      final value = int.tryParse(match?.group(1) ?? '');
      if (value != null && value > highest) highest = value;
    }
    return 'TKT-${highest + 1}';
  }
}

/// Four tickets that read like a real year of tenancy: one live maintenance
/// job, a billing question nobody has answered yet, a request being worked
/// through, and one long since put to bed.
///
/// The dates hang off [DateTime.now] so the list still reads as recent
/// whenever the app is opened, rather than ageing into obvious fiction.
List<SupportTicket> _seed() {
  final now = DateTime.now();
  DateTime ago(Duration duration) => now.subtract(duration);

  return [
    SupportTicket(
      reference: 'TKT-2046',
      subject: 'Leaking tap in the wash area',
      description:
          'The mixer tap at the rear wash area drips steadily overnight and '
          'the floor is wet by the time we open. We have put a bucket under it '
          'for now.',
      category: SupportCategory.maintenance,
      priority: TicketPriority.high,
      status: TicketStatus.inProgress,
      location: 'Rear wash area',
      raisedAt: ago(const Duration(days: 2, hours: 3)),
      updatedAt: ago(const Duration(hours: 5)),
      thread: [
        TicketMessage(
          author: 'You',
          body:
              'The mixer tap at the rear wash area drips steadily overnight '
              'and the floor is wet by the time we open. We have put a bucket '
              'under it for now.',
          sentAt: ago(const Duration(days: 2, hours: 3)),
        ),
        TicketMessage(
          author: 'Wanjiru, support desk',
          body:
              'Thank you for flagging this. A plumber is booked for tomorrow '
              'morning between 8 and 10. Please keep the area clear for them.',
          sentAt: ago(const Duration(days: 1, hours: 20)),
          fromSupport: true,
        ),
        TicketMessage(
          author: 'You',
          body: 'Noted, someone will be here from half seven.',
          sentAt: ago(const Duration(hours: 5)),
        ),
      ],
    ),
    SupportTicket(
      reference: 'TKT-2045',
      subject: 'Service charge on this month invoice',
      description:
          'The service charge line is higher than last month and I cannot see '
          'what changed. Could you send the breakdown?',
      category: SupportCategory.billing,
      priority: TicketPriority.normal,
      status: TicketStatus.open,
      raisedAt: ago(const Duration(days: 4, hours: 6)),
      updatedAt: ago(const Duration(days: 4, hours: 6)),
      thread: [
        TicketMessage(
          author: 'You',
          body:
              'The service charge line is higher than last month and I cannot '
              'see what changed. Could you send the breakdown?',
          sentAt: ago(const Duration(days: 4, hours: 6)),
        ),
      ],
    ),
    SupportTicket(
      reference: 'TKT-2044',
      subject: 'Two more access cards for evening staff',
      description:
          'We have taken on two evening staff and need cards that work with '
          'the service lift after six. Names and ID copies are ready.',
      category: SupportCategory.access,
      priority: TicketPriority.low,
      status: TicketStatus.inProgress,
      location: 'Service lift lobby',
      raisedAt: ago(const Duration(days: 9)),
      updatedAt: ago(const Duration(days: 8)),
      thread: [
        TicketMessage(
          author: 'You',
          body:
              'We have taken on two evening staff and need cards that work '
              'with the service lift after six. Names and ID copies are ready.',
          sentAt: ago(const Duration(days: 9)),
        ),
        TicketMessage(
          author: 'David, support desk',
          body:
              'Received. Cards take about a week to issue once the ID copies '
              'are with us — please leave them at the management office.',
          sentAt: ago(const Duration(days: 8)),
          fromSupport: true,
        ),
      ],
    ),
    SupportTicket(
      reference: 'TKT-2041',
      subject: 'Corridor lights out near the service lift',
      description:
          'Three of the ceiling lights in the corridor outside our door have '
          'been out since the weekend. It is dark for deliveries.',
      category: SupportCategory.utilities,
      priority: TicketPriority.normal,
      status: TicketStatus.resolved,
      location: 'Ground floor corridor',
      raisedAt: ago(const Duration(days: 27)),
      updatedAt: ago(const Duration(days: 22)),
      thread: [
        TicketMessage(
          author: 'You',
          body:
              'Three of the ceiling lights in the corridor outside our door '
              'have been out since the weekend. It is dark for deliveries.',
          sentAt: ago(const Duration(days: 27)),
        ),
        TicketMessage(
          author: 'Wanjiru, support desk',
          body:
              'The fittings were replaced on Thursday and the corridor is lit '
              'again. Closing this off — do reopen it if anything flickers.',
          sentAt: ago(const Duration(days: 22)),
          fromSupport: true,
        ),
      ],
    ),
  ];
}
