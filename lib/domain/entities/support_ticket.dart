import '../../core/theme/status_palette.dart';

/// What a ticket is about.
///
/// The contract carries this as a free string (`ticketType`). The app sends
/// [api] and reads back leniently — see [fromApi] — so a type the desk
/// invents on its side still lands somewhere rather than failing the list.
enum SupportCategory {
  maintenance,
  billing,
  utilities,
  security,
  access,
  other;

  /// What goes on the wire. Title case, like the contract's other names.
  String get api => switch (this) {
    SupportCategory.maintenance => 'Maintenance',
    SupportCategory.billing => 'Billing',
    SupportCategory.utilities => 'Utilities',
    SupportCategory.security => 'Security',
    SupportCategory.access => 'Access',
    SupportCategory.other => 'Other',
  };

  String get label => switch (this) {
    SupportCategory.maintenance => 'Maintenance',
    SupportCategory.billing => 'Billing',
    SupportCategory.utilities => 'Utilities',
    SupportCategory.security => 'Security',
    SupportCategory.access => 'Access',
    SupportCategory.other => 'Something else',
  };

  static SupportCategory fromApi(String? raw) {
    final needle = raw?.trim().toLowerCase();
    for (final value in values) {
      if (value.api.toLowerCase() == needle) return value;
    }
    return SupportCategory.other;
  }
}

/// Where a ticket has got to.
///
/// `status` is a free string on the wire too, and the contract lists no
/// values. [fromApi] folds the likely spellings onto four states; anything it
/// does not recognise reads as [open], which is the one state that promises
/// nothing.
enum TicketStatus {
  open,
  inProgress,
  resolved,
  closed;

  /// What the app sends to `tickets/close/{id}`.
  String get api => switch (this) {
    TicketStatus.open => 'Open',
    TicketStatus.inProgress => 'InProgress',
    TicketStatus.resolved => 'Resolved',
    TicketStatus.closed => 'Closed',
  };

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

  /// Whether the ticket can still be edited or closed.
  bool get isLive =>
      this == TicketStatus.open || this == TicketStatus.inProgress;

  static TicketStatus fromApi(String? raw) {
    final needle = (raw ?? '').toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    return switch (needle) {
      'inprogress' ||
      'approved' ||
      'assigned' ||
      'acknowledged' => TicketStatus.inProgress,
      'resolved' || 'completed' || 'done' || 'fixed' => TicketStatus.resolved,
      'closed' ||
      'rejected' ||
      'declined' ||
      'cancelled' ||
      'canceled' => TicketStatus.closed,
      _ => TicketStatus.open,
    };
  }
}

/// A support request raised about a unit — the contract's `Tickets`.
///
/// There is no subject line, priority or message thread on the wire: a
/// ticket is one [comment] from whoever raised it, and at most one answer
/// from the desk in [approvalRemarks].
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.category,
    required this.comment,
    required this.status,
    required this.propertyId,
    required this.unitId,
    required this.createdAt,
    required this.updatedAt,
    this.propertyName,
    this.attachments,
    this.approvalRemarks,
    this.approvedByName,
    this.approvedById,
    this.createdById,
    this.createdByName,
  });

  final String id;
  final SupportCategory category;
  final String comment;
  final TicketStatus status;
  final String propertyId;
  final String? propertyName;
  final String unitId;

  /// Whatever the server stores against the ticket — the contract types it
  /// as a single string. Carried so an edit sends it back untouched.
  final String? attachments;

  /// The desk's answer, and who gave it.
  final String? approvalRemarks;
  final String? approvedByName;
  final String? approvedById;

  final String? createdById;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether [approvalRemarks] came from someone other than the author —
  /// a tenant who closes their own ticket leaves the remark themselves.
  bool get remarksFromSupport =>
      approvedById == null || approvedById != createdById;

  /// The handle a tenant quotes, e.g. `TKT-12`.
  String get reference => 'TKT-$id';

  /// The request that would recreate this ticket as it stands — the base
  /// for an edit, which the contract sends as the whole record.
  TicketDraft toDraft() => TicketDraft(
    category: category,
    comment: comment,
    propertyId: propertyId,
    propertyName: propertyName ?? '',
    unitId: unitId,
    attachments: attachments ?? '',
  );
}

/// The contract's `CreateTicketRequest`, used to raise and to edit.
///
/// Property and unit are required on the wire: a ticket is always about a
/// space, and the tenant's lease is where the app finds which.
class TicketDraft {
  const TicketDraft({
    required this.category,
    required this.comment,
    required this.propertyId,
    required this.propertyName,
    required this.unitId,
    this.attachments = '',
  });

  final SupportCategory category;
  final String comment;
  final String propertyId;
  final String propertyName;
  final String unitId;
  final String attachments;

  TicketDraft copyWith({SupportCategory? category, String? comment}) =>
      TicketDraft(
        category: category ?? this.category,
        comment: comment ?? this.comment,
        propertyId: propertyId,
        propertyName: propertyName,
        unitId: unitId,
        attachments: attachments,
      );
}
