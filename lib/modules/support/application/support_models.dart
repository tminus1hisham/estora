import 'package:flutter/material.dart';

import '../../../core/theme/status_palette.dart';

/// What the ticket is about.
///
/// Deliberately short. A tenant picking from six plain words gets to the
/// description faster than one reading a taxonomy, and the support desk can
/// route on six as well as it can on twenty.
enum SupportCategory {
  maintenance,
  billing,
  utilities,
  security,
  access,
  other;

  String get label => switch (this) {
    SupportCategory.maintenance => 'Maintenance',
    SupportCategory.billing => 'Billing',
    SupportCategory.utilities => 'Utilities',
    SupportCategory.security => 'Security',
    SupportCategory.access => 'Access',
    SupportCategory.other => 'Something else',
  };

  IconData get icon => switch (this) {
    SupportCategory.maintenance => Icons.handyman_outlined,
    SupportCategory.billing => Icons.receipt_long_outlined,
    SupportCategory.utilities => Icons.bolt_outlined,
    SupportCategory.security => Icons.shield_outlined,
    SupportCategory.access => Icons.badge_outlined,
    SupportCategory.other => Icons.help_outline_rounded,
  };
}

/// Where a ticket has got to.
enum TicketStatus {
  open,
  inProgress,
  resolved,
  closed;

  String get label => switch (this) {
    TicketStatus.open => 'Open',
    TicketStatus.inProgress => 'In progress',
    TicketStatus.resolved => 'Resolved',
    TicketStatus.closed => 'Closed',
  };

  /// An open ticket is warning rather than danger: it is waiting, not wrong.
  /// Danger is reserved across the app for money that is late and requests
  /// that failed, and spending it here would cheapen it.
  StatusTone get tone => switch (this) {
    TicketStatus.open => StatusTone.warning,
    TicketStatus.inProgress => StatusTone.progress,
    TicketStatus.resolved => StatusTone.positive,
    TicketStatus.closed => StatusTone.neutral,
  };

  /// Whether the ticket can still be replied to or resolved.
  bool get isLive =>
      this == TicketStatus.open || this == TicketStatus.inProgress;
}

/// How urgently the tenant needs an answer.
enum TicketPriority {
  low,
  normal,
  high,
  urgent;

  String get label => switch (this) {
    TicketPriority.low => 'Low',
    TicketPriority.normal => 'Normal',
    TicketPriority.high => 'High',
    TicketPriority.urgent => 'Urgent',
  };
}

/// One message in a ticket's conversation.
///
/// [author] is a display name rather than a user id because nothing here is
/// resolved against an account — the thread is read, never joined.
@immutable
class TicketMessage {
  const TicketMessage({
    required this.author,
    required this.body,
    required this.sentAt,
    this.fromSupport = false,
  });

  final String author;
  final String body;
  final DateTime sentAt;

  /// Drives which side of the thread the message is drawn on. Kept as a flag
  /// rather than inferred from [author] so a renamed support agent cannot
  /// quietly turn into the tenant.
  final bool fromSupport;
}

/// A support request raised by a tenant about their space.
@immutable
class SupportTicket {
  const SupportTicket({
    required this.reference,
    required this.subject,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.raisedAt,
    required this.updatedAt,
    this.location,
    this.thread = const <TicketMessage>[],
  });

  /// The human handle for the ticket, e.g. `TKT-2041`. It is also the path
  /// parameter the detail route is addressed by, so it has to be stable and
  /// URL-safe — which a short prefixed number is, and a subject line is not.
  final String reference;

  final String subject;
  final String description;
  final SupportCategory category;
  final TicketPriority priority;
  final TicketStatus status;

  /// The unit or area the issue is in, when the tenant named one.
  final String? location;

  final DateTime raisedAt;
  final DateTime updatedAt;

  /// The conversation, oldest first — the order it is read in.
  final List<TicketMessage> thread;

  /// The last thing said, whoever said it. Null only for a ticket with no
  /// conversation at all, which a raised ticket never is.
  TicketMessage? get latestMessage => thread.isEmpty ? null : thread.last;

  SupportTicket copyWith({
    String? reference,
    String? subject,
    String? description,
    SupportCategory? category,
    TicketPriority? priority,
    TicketStatus? status,
    String? location,
    DateTime? raisedAt,
    DateTime? updatedAt,
    List<TicketMessage>? thread,
  }) {
    return SupportTicket(
      reference: reference ?? this.reference,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      location: location ?? this.location,
      raisedAt: raisedAt ?? this.raisedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      thread: thread ?? this.thread,
    );
  }
}
