/// Who may do what.
///
/// The contract carries a full identity surface — accounts, roles, and the
/// individual claims attached to either — that the app had no model for. These
/// types describe it without inventing anything: a role is a name, a claim is a
/// type and a value, and an account is the join between them.
///
/// Nothing here decides an outcome. Authorisation is the server's judgement;
/// these records exist so an administrator can *see* and *change* the grants,
/// not so the client can evaluate them.
library;

/// An account on the platform, as an administrator sees it.
///
/// Distinct from `AppUser`, which is the signed-in person as the app knows
/// them. This is somebody else's account, listed for administration, and it
/// carries the fields that only matter in that context — whether it is
/// disabled, who created it, when it last signed in.
class PlatformUser {
  const PlatformUser({
    required this.id,
    required this.fullName,
    required this.isActive,
    this.userId,
    this.phoneNumber,
    this.emailAddress,
    this.role,
    this.profileImage,
    this.roles = const <String>[],
    this.isDeleted = false,
    this.emailConfirmed = false,
    this.phoneConfirmed = false,
    this.twoFactorEnabled = false,
    this.lockoutEnabled = false,
    this.lockedOutUntil,
    this.createdByName,
    this.lastLoginAt,
    this.createdAt,
  });

  final String id;

  /// The identity provider's own id, where it differs from the record id. Role
  /// and claim operations key on the phone number rather than either, which is
  /// the contract's choice, not the app's.
  final String? userId;

  final String fullName;
  final String? phoneNumber;
  final String? emailAddress;

  /// The single role stamped on the account record, which is not necessarily
  /// the whole story — [roles] is what the role service actually holds.
  final String? role;

  final String? profileImage;

  /// Every role granted through the role service.
  final List<String> roles;

  final bool isActive;
  final bool isDeleted;
  final bool emailConfirmed;
  final bool phoneConfirmed;
  final bool twoFactorEnabled;
  final bool lockoutEnabled;
  final DateTime? lockedOutUntil;

  final String? createdByName;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;

  /// Role and claim operations address a user by phone number. An account
  /// without one cannot be granted anything, and the UI says so rather than
  /// offering a control that would fail.
  bool get isAddressable =>
      phoneNumber != null && phoneNumber!.trim().isNotEmpty;

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get contactLabel => [
    phoneNumber,
    emailAddress,
  ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');
}

/// A named role.
class AccessRole {
  const AccessRole({required this.name, this.id});

  final String? id;
  final String name;
}

/// One claim: a typed permission with a value.
class AccessClaim {
  const AccessClaim({required this.type, required this.value, this.issuer});

  /// The claim type, e.g. `permission` or a schema URI the identity provider
  /// chose. Shown verbatim — abbreviating it would make two different claims
  /// look like one.
  final String type;

  final String value;
  final String? issuer;

  /// The tail of a URI-shaped claim type, for a list that has to stay legible.
  /// The full [type] is always available beside it.
  String get shortType {
    final trimmed = type.trim();
    if (trimmed.isEmpty) return trimmed;
    final separator = trimmed.lastIndexOf(RegExp(r'[/#]'));
    if (separator == -1 || separator == trimmed.length - 1) return trimmed;
    return trimmed.substring(separator + 1);
  }
}
