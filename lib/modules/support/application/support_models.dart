import 'package:flutter/material.dart';

import '../../../domain/entities/support_ticket.dart';

export '../../../domain/entities/support_ticket.dart';

extension SupportCategoryIcon on SupportCategory {
  IconData get icon => switch (this) {
    SupportCategory.maintenance => Icons.handyman_outlined,
    SupportCategory.billing => Icons.receipt_long_outlined,
    SupportCategory.utilities => Icons.bolt_outlined,
    SupportCategory.security => Icons.shield_outlined,
    SupportCategory.access => Icons.badge_outlined,
    SupportCategory.other => Icons.help_outline_rounded,
  };
}

/// A space a ticket can be raised about, taken off one of the tenant's
/// leases. The contract wants property and unit on every ticket, and the
/// lease is the only place the app learns which the tenant occupies.
@immutable
class TicketSpace {
  const TicketSpace({
    required this.propertyId,
    required this.propertyName,
    required this.unitId,
    this.unitNumber,
  });

  final String propertyId;
  final String propertyName;
  final String unitId;
  final String? unitNumber;

  String get label =>
      unitNumber == null ? propertyName : 'Unit $unitNumber · $propertyName';
}
