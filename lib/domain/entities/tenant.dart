import '../enums/domain_enums.dart';

/// Section 20. The individual or company leasing a unit.
class Tenant {
  const Tenant({
    required this.id,
    required this.userId,
    required this.tenantType,
    required this.displayName,
    required this.status,
    this.profile,
  });

  final String id;
  final String userId;
  final TenantType tenantType;
  final String displayName;
  final String status;
  final TenantProfile? profile;
}

/// Section 20.
///
/// Identification numbers are sensitive and must be encrypted at rest
/// (sections 20 and 74). That is a server obligation; the client's part is to
/// avoid putting them on screen in full — see [maskedNationalId].
class TenantProfile {
  const TenantProfile({
    required this.tenantId,
    this.legalName,
    this.registrationNumber,
    this.taxNumber,
    this.nationalId,
    this.passportNumber,
    this.email,
    this.phone,
    this.address,
    this.contactPerson,
    this.contactPersonPhone,
  });

  final String tenantId;
  final String? legalName;
  final String? registrationNumber;
  final String? taxNumber;
  final String? nationalId;
  final String? passportNumber;
  final String? email;
  final String? phone;
  final String? address;
  final String? contactPerson;
  final String? contactPersonPhone;

  String? get maskedNationalId => _mask(nationalId);
  String? get maskedPassportNumber => _mask(passportNumber);
  String? get maskedTaxNumber => _mask(taxNumber);

  /// Shows the last four characters only, e.g. `••••4821`. Enough for the
  /// tenant to confirm the right document is on file without rendering the
  /// full number on a screen someone could be looking over.
  static String? _mask(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.length <= 4) return '•' * value.length;
    return '${'•' * (value.length - 4)}${value.substring(value.length - 4)}';
  }
}

/// Section 9. The authenticated user behind the tenant.
class AppUser {
  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.status,
    this.email,
    this.phone,
    this.organizationId,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.lastLoginAt,
  });

  final String id;
  final String? organizationId;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String status;
  final bool emailVerified;
  final bool phoneVerified;
  final DateTime? lastLoginAt;

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = lastName.isNotEmpty ? lastName[0] : '';
    final value = '$first$last'.trim();
    return value.isEmpty ? '?' : value.toUpperCase();
  }
}

/// What the app holds after a successful sign-in.
class AuthSession {
  const AuthSession({required this.user, required this.tenant});

  final AppUser user;

  /// Null if the account exists but no tenant record has been created yet —
  /// possible right after registration, before the first booking.
  final Tenant? tenant;
}

/// Section 51. A stored file.
class Document {
  const Document({
    required this.id,
    required this.documentType,
    required this.fileName,
    required this.createdAt,
    this.ownerType,
    this.ownerId,
    this.fileUrl,
    this.mimeType,
    this.fileSize,
    this.version = 1,
    this.hash,
    this.status,
  });

  final String id;
  final String? ownerType;
  final String? ownerId;

  final DocumentType documentType;
  final String fileName;

  /// Preferably a short-lived signed URL (section 75), not a public link.
  final String? fileUrl;

  final String? mimeType;
  final int? fileSize;

  /// Generated documents are versioned and immutable (section 28).
  final int version;
  final String? hash;

  final String? status;
  final DateTime createdAt;

  bool get isPdf => mimeType == 'application/pdf' ||
      fileName.toLowerCase().endsWith('.pdf');

  String get sizeLabel {
    final size = fileSize;
    if (size == null) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Section 49.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.target = NotificationTarget.none,
    this.targetId,
  });

  final String id;
  final NotificationType type;
  final String title;

  /// Rendered from a server-side template (section 50), so notification copy
  /// can change without an app release.
  final String body;

  final DateTime createdAt;
  final bool isRead;

  /// Where tapping the notification should navigate.
  final NotificationTarget target;
  final String? targetId;
}
