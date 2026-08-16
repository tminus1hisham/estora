import '../enums/domain_enums.dart';

/// Section 88. The individual or company that owns a property and lets it.
///
/// The counterpart to [Tenant]. Where a tenant occupies one unit under one
/// lease, an owner holds a portfolio: properties, the units inside them, and
/// the money those units bring in. The two never share a screen — an account is
/// one or the other, decided by [AccountRole] and enforced once in the router.
///
/// Ownership itself lives on the property, not here. `Property.ownerId` is the
/// edge, so a property can change hands without rewriting the owner.
class PropertyOwner {
  const PropertyOwner({
    required this.id,
    required this.userId,
    required this.ownerType,
    required this.displayName,
    required this.status,
    this.legalName,
    this.registrationNumber,
    this.taxNumber,
    this.payoutAccountNumber,
  });

  final String id;
  final String userId;
  final OwnerType ownerType;

  /// What the owner is called on screen. A trading name for a company, a
  /// person's name for an individual.
  final String displayName;

  final String status;

  final String? legalName;
  final String? registrationNumber;
  final String? taxNumber;

  /// Where collected rent is paid out to. Held in full only on the server;
  /// render [maskedPayoutAccount] rather than this.
  final String? payoutAccountNumber;

  /// The last four digits only, e.g. `••••4821`.
  ///
  /// The same treatment [TenantProfile] gives identification numbers, for the
  /// same reason: enough to confirm the right account is on file without
  /// putting it on a screen someone could be reading over your shoulder.
  String? get maskedPayoutAccount {
    final value = payoutAccountNumber;
    if (value == null || value.isEmpty) return null;
    if (value.length <= 4) return '•' * value.length;
    return '${'•' * (value.length - 4)}${value.substring(value.length - 4)}';
  }

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
