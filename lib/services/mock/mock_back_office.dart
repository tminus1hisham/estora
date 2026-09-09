/// The back-office half of the mock server.
///
/// Two areas of the published contract have no tenant-facing home: the raw
/// money the platform received — M-Pesa callbacks and hand-keyed bank
/// transfers — and the identity surface of accounts, roles and claims. Both
/// are stateful, both are written to, and neither belongs in the middle of
/// `MockServer`'s booking and billing logic. So they live here, constructed by
/// and reading from that server.
///
/// The same rule applies as everywhere else in the mock: this behaves like a
/// server. It refuses what a server would refuse, it derives what a server
/// would derive, and it does not quietly succeed at something the real API
/// would reject.
library;

import '../../core/utils/money.dart';
import '../../domain/entities/access.dart';
import '../../domain/entities/treasury.dart';
import '../../domain/enums/domain_enums.dart';
import 'mock_server.dart';

class MockBackOffice {
  MockBackOffice(this._server) {
    _seed();
  }

  final MockServer _server;

  final List<MpesaTransaction> mpesa = [];
  final List<BankPayment> bankPayments = [];
  final List<PlatformUser> users = [];
  final List<AccessRole> roles = [];

  /// Claims granted directly to an account, keyed by phone number — which is
  /// how the contract addresses them.
  final Map<String, List<AccessClaim>> userClaims = {};

  /// Claims granted to a role, keyed by role name.
  final Map<String, List<AccessClaim>> roleClaims = {};

  /// Roles granted to an account, keyed by phone number.
  final Map<String, List<String>> userRoles = {};

  int _sequence = 0;

  String _nextId(String prefix) => '$prefix${++_sequence}';

  // -------------------------------------------------------------------------
  // Seeding
  // -------------------------------------------------------------------------

  void _seed() {
    _seedRoles();
    _seedUsers();
    _seedTreasury();
  }

  void _seedRoles() {
    roles.addAll(const [
      AccessRole(id: 'role-tenant', name: 'Tenant'),
      AccessRole(id: 'role-owner', name: 'Owner'),
      AccessRole(id: 'role-manager', name: 'PropertyManager'),
      AccessRole(id: 'role-finance', name: 'FinanceOfficer'),
      AccessRole(id: 'role-admin', name: 'Administrator'),
    ]);

    roleClaims['Administrator'] = const [
      AccessClaim(type: 'permission', value: 'users.manage'),
      AccessClaim(type: 'permission', value: 'roles.manage'),
    ];
    roleClaims['FinanceOfficer'] = const [
      AccessClaim(type: 'permission', value: 'payments.reconcile'),
      AccessClaim(type: 'permission', value: 'invoices.settle'),
    ];
    roleClaims['PropertyManager'] = const [
      AccessClaim(type: 'permission', value: 'properties.edit'),
      AccessClaim(type: 'permission', value: 'units.edit'),
    ];
  }

  /// Builds the account list from the sessions the server already knows about,
  /// plus the back-office staff who never sign in to this app but who an
  /// administrator still has to be able to see and disable.
  void _seedUsers() {
    final seen = <String>{};

    for (final entry in _server.accountsByPhone.entries) {
      final session = entry.value;
      final user = session.user;
      final phone = user.phone ?? entry.key;
      if (!seen.add(phone)) continue;

      final role = user.role.isOwner ? 'Owner' : 'Tenant';
      users.add(
        PlatformUser(
          id: user.id,
          userId: user.id,
          fullName: user.fullName,
          phoneNumber: phone,
          emailAddress: user.email,
          role: role,
          roles: [role],
          isActive: true,
          emailConfirmed: user.emailVerified,
          phoneConfirmed: user.phoneVerified,
          lastLoginAt: user.lastLoginAt,
        ),
      );
      userRoles[phone] = [role];
    }

    const staff = [
      (
        'Wanjiru Kamau',
        '254712000101',
        'wanjiru.kamau@estatic.live',
        'FinanceOfficer',
      ),
      (
        'Peter Otieno',
        '254712000102',
        'peter.otieno@estatic.live',
        'PropertyManager',
      ),
      (
        'Fatuma Hassan',
        '254712000103',
        'fatuma.hassan@estatic.live',
        'Administrator',
      ),
    ];

    for (final (name, phone, email, role) in staff) {
      users.add(
        PlatformUser(
          id: _nextId('user-'),
          userId: _nextId('uid-'),
          fullName: name,
          phoneNumber: phone,
          emailAddress: email,
          role: role,
          roles: [role],
          isActive: true,
          emailConfirmed: true,
          phoneConfirmed: true,
        ),
      );
      userRoles[phone] = [role];
    }

    userClaims['254712000101'] = const [
      AccessClaim(type: 'permission', value: 'payments.refund'),
    ];
  }

  /// Turns the payments the mock has already taken into the raw records a
  /// treasury would hold, and adds the two cases the screens exist for: money
  /// that arrived against the wrong account number, and a transfer somebody
  /// keyed in by hand.
  void _seedTreasury() {
    for (final payment in _server.payments.values) {
      if (payment.paymentMethod != PaymentMethod.mpesa) continue;
      if (payment.status != PaymentStatus.success) continue;

      mpesa.add(
        MpesaTransaction(
          id: _nextId('mpesa-'),
          transactionId:
              payment.providerTransactionId ?? payment.paymentReference,
          amount: payment.amount,
          processed: true,
          transactionType: 'Pay Bill',
          transactedAt: payment.paidAt ?? payment.createdAt,
          businessShortCode: '400200',
          accountNumber: payment.invoiceNumber,
          invoiceNumber: payment.invoiceNumber,
          payerPhone: '254722000001',
          payerName: _server.currentTenant?.displayName ?? 'Tenant',
          propertyId: payment.propertyId,
        ),
      );
    }

    // The whole reason the correction screen exists: money in the account with
    // nothing to match it to, because the payer typed the wrong reference.
    mpesa.add(
      MpesaTransaction(
        id: _nextId('mpesa-'),
        transactionId: 'SFH4KQ2WMR',
        amount: Money.fromMajor(45000, 'KES'),
        processed: false,
        transactionType: 'Pay Bill',
        transactedAt: _server.now.subtract(const Duration(days: 2)),
        businessShortCode: '400200',
        accountNumber: 'SHOP12',
        payerPhone: '254733112233',
        payerName: 'JOSEPH',
      ),
    );

    bankPayments.add(
      BankPayment(
        id: _nextId('bank-'),
        amount: Money.fromMajor(177000, 'KES'),
        paidAt: _server.now.subtract(const Duration(days: 5)),
        paymentMethod: 'RTGS',
        paymentReference: 'FT24099KX41M',
        purpose: 'February rent',
        paidByName: 'Nyota Retail Ltd',
        bankName: 'Equity Bank',
        branchName: 'Westlands',
        bankAccountNumber: '0170294857361',
        status: 'Pending review',
        createdByName: 'Wanjiru Kamau',
        createdAt: _server.now.subtract(const Duration(days: 5)),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // The signed-in account
  // -------------------------------------------------------------------------

  /// The verification code every confirmation flow accepts.
  ///
  /// The same one the sign-in OTP uses. A mock that generated a code nobody
  /// could read would make its own screens untestable.
  String get verificationCode => MockServer.demoOtp;

  PlatformUser currentAccount() {
    final user = _server.currentUser;
    if (user == null) throw const MockNotFound('Not signed in');

    final phone = user.phone;
    final index = _indexOfAccount(user.id);
    if (index != -1) {
      return _withRoles(
        users[index],
        userRoles[users[index].phoneNumber] ?? users[index].roles,
      );
    }

    return PlatformUser(
      id: user.id,
      userId: user.id,
      fullName: user.fullName,
      phoneNumber: phone,
      emailAddress: user.email,
      role: user.role.label,
      roles: userRoles[phone] ?? const <String>[],
      isActive: true,
      emailConfirmed: user.emailVerified,
      phoneConfirmed: user.phoneVerified,
      lastLoginAt: user.lastLoginAt,
    );
  }

  int _indexOfAccount(String userId) =>
      users.indexWhere((user) => user.id == userId || user.userId == userId);

  /// Changes the signed-in account's password.
  ///
  /// The mock accepts any password at sign-in *until* one has been set here,
  /// after which the new one is required — so a change made on this screen is
  /// something the next sign-in actually notices, rather than a form that
  /// congratulates you and does nothing.
  void changePassword({
    required String phoneNumber,
    required String currentPassword,
    required String newPassword,
  }) {
    final stored = _server.passwords[MockServer.normalisePhone(phoneNumber)];
    if (stored != null && stored != currentPassword) {
      throw const MockConflict('That is not your current password.');
    }
    _requireStrongEnough(newPassword);
    if (currentPassword == newPassword) {
      throw const MockConflict(
        'The new password has to differ from the current one.',
      );
    }
    _server.passwords[MockServer.normalisePhone(phoneNumber)] = newPassword;
  }

  void resetPassword({
    required String phoneNumber,
    required String resetToken,
    required String newPassword,
  }) {
    if (resetToken.trim() != verificationCode) {
      throw const MockConflict(
        'That reset code is not right. Check the message and try again.',
      );
    }
    _requireStrongEnough(newPassword);
    _server.passwords[MockServer.normalisePhone(phoneNumber)] = newPassword;
  }

  /// The one rule worth enforcing client-side, because it is the one a server
  /// would enforce and the one a person can act on before submitting.
  static void _requireStrongEnough(String password) {
    if (password.trim().length < 8) {
      throw const MockConflict(
        'Use at least 8 characters for your new password.',
      );
    }
  }

  void enableTwoFactor() {
    final index = _indexOfAccount(_server.currentUser?.id ?? '');
    if (index == -1) throw const MockNotFound('Not signed in');
    if (users[index].twoFactorEnabled) {
      throw const MockConflict(
        'Two-factor authentication is already switched on.',
      );
    }
    users[index] = _copyVerification(users[index], twoFactorEnabled: true);
  }

  void verifyTwoFactor({required String email, required String code}) {
    _requireCode(code);
    final index = _indexOfAccount(_server.currentUser?.id ?? '');
    if (index == -1) throw const MockNotFound('Not signed in');
    users[index] = _copyVerification(users[index], twoFactorEnabled: true);
  }

  void confirmEmail({required String email, required String token}) {
    _requireCode(token);
    final index = users.indexWhere(
      (user) => user.emailAddress?.toLowerCase() == email.trim().toLowerCase(),
    );
    if (index == -1) {
      throw const MockNotFound('No account uses that email address.');
    }
    users[index] = _copyVerification(users[index], emailConfirmed: true);
  }

  void confirmPhoneNumber({
    required String email,
    required String phoneNumber,
    required String token,
  }) {
    _requireCode(token);
    final normalised = MockServer.normalisePhone(phoneNumber);
    final index = users.indexWhere(
      (user) =>
          user.phoneNumber != null &&
          MockServer.normalisePhone(user.phoneNumber!) == normalised,
    );
    if (index == -1) {
      throw const MockNotFound('No account uses that phone number.');
    }
    users[index] = _copyVerification(users[index], phoneConfirmed: true);
  }

  void _requireCode(String code) {
    if (code.trim() != verificationCode) {
      throw const MockConflict(
        'That code is not right. Check the message and try again.',
      );
    }
  }

  void updateProfilePicture(String encodedImage) {
    if (encodedImage.trim().isEmpty) {
      throw const MockConflict('Choose a picture first.');
    }
    final index = _indexOfAccount(_server.currentUser?.id ?? '');
    if (index == -1) throw const MockNotFound('Not signed in');
    users[index] = _copyVerification(users[index], profileImage: encodedImage);
  }

  void updateAccount({
    required String userId,
    required String fullName,
    required String emailAddress,
    required String phoneNumber,
  }) {
    if (fullName.trim().isEmpty) throw const MockConflict('Enter a name.');
    final index = _indexOfAccount(userId);
    if (index == -1) throw const MockNotFound('Account not found');

    final existing = users[index];
    users[index] = PlatformUser(
      id: existing.id,
      userId: existing.userId,
      fullName: fullName.trim(),
      phoneNumber: phoneNumber.trim(),
      emailAddress: emailAddress.trim(),
      role: existing.role,
      profileImage: existing.profileImage,
      roles: existing.roles,
      isActive: existing.isActive,
      isDeleted: existing.isDeleted,
      // Changing a contact detail un-verifies it. The old confirmation was of
      // a different address.
      emailConfirmed:
          existing.emailConfirmed &&
          existing.emailAddress == emailAddress.trim(),
      phoneConfirmed:
          existing.phoneConfirmed && existing.phoneNumber == phoneNumber.trim(),
      twoFactorEnabled: existing.twoFactorEnabled,
      lockoutEnabled: existing.lockoutEnabled,
      lockedOutUntil: existing.lockedOutUntil,
      createdByName: existing.createdByName,
      lastLoginAt: existing.lastLoginAt,
      createdAt: existing.createdAt,
    );
  }

  static PlatformUser _copyVerification(
    PlatformUser user, {
    bool? emailConfirmed,
    bool? phoneConfirmed,
    bool? twoFactorEnabled,
    String? profileImage,
  }) => PlatformUser(
    id: user.id,
    userId: user.userId,
    fullName: user.fullName,
    phoneNumber: user.phoneNumber,
    emailAddress: user.emailAddress,
    role: user.role,
    profileImage: profileImage ?? user.profileImage,
    roles: user.roles,
    isActive: user.isActive,
    isDeleted: user.isDeleted,
    emailConfirmed: emailConfirmed ?? user.emailConfirmed,
    phoneConfirmed: phoneConfirmed ?? user.phoneConfirmed,
    twoFactorEnabled: twoFactorEnabled ?? user.twoFactorEnabled,
    lockoutEnabled: user.lockoutEnabled,
    lockedOutUntil: user.lockedOutUntil,
    createdByName: user.createdByName,
    lastLoginAt: user.lastLoginAt,
    createdAt: user.createdAt,
  );

  // -------------------------------------------------------------------------
  // Treasury
  // -------------------------------------------------------------------------

  List<MpesaTransaction> listMpesa({String? propertyId}) {
    final rows = mpesa
        .where((row) => propertyId == null || row.propertyId == propertyId)
        .toList();
    rows.sort((a, b) => _whenOf(b).compareTo(_whenOf(a)));
    return List.unmodifiable(rows);
  }

  /// Matched case-insensitively and on either reference the gateway carries.
  /// A person reading a code off a phone screen types it how they see it.
  List<MpesaTransaction> findMpesa(String transactionId) {
    final needle = transactionId.trim().toUpperCase();
    if (needle.isEmpty) return const <MpesaTransaction>[];
    return List.unmodifiable(
      mpesa.where(
        (row) =>
            row.transactionId.toUpperCase() == needle ||
            (row.thirdPartyTransactionId?.toUpperCase() == needle),
      ),
    );
  }

  static DateTime _whenOf(MpesaTransaction row) =>
      row.transactedAt ?? row.createdAt ?? DateTime(1970);

  /// Corrects the account a payment was credited against.
  ///
  /// The transaction is marked edited and, having somewhere to go, processed.
  /// The amount is untouched: correcting a reference is not a licence to
  /// change what arrived (section 84 rule 1).
  MpesaTransaction setAccountNumber({
    required String transactionId,
    required String accountNumber,
  }) {
    final index = mpesa.indexWhere((row) => row.id == transactionId);
    if (index == -1) throw const MockNotFound('Transaction not found');

    final trimmed = accountNumber.trim();
    if (trimmed.isEmpty) {
      throw const MockConflict('Enter the account number to credit.');
    }

    final existing = mpesa[index];
    final updated = MpesaTransaction(
      id: existing.id,
      transactionId: existing.transactionId,
      amount: existing.amount,
      processed: true,
      transactionType: existing.transactionType,
      transactedAt: existing.transactedAt,
      businessShortCode: existing.businessShortCode,
      accountNumber: trimmed,
      invoiceNumber: trimmed,
      payerPhone: existing.payerPhone,
      payerName: existing.payerName,
      propertyId: existing.propertyId,
      blockId: existing.blockId,
      thirdPartyTransactionId: existing.thirdPartyTransactionId,
      organisationBalance: existing.organisationBalance,
      isReissued: existing.isReissued,
      isEdited: true,
      isSplit: existing.isSplit,
      createdAt: existing.createdAt,
    );
    mpesa[index] = updated;
    return updated;
  }

  List<BankPayment> listBankPayments() {
    final rows = [...bankPayments]
      ..sort((a, b) => b.paidAt.compareTo(a.paidAt));
    return List.unmodifiable(rows);
  }

  BankPayment recordBankPayment({
    required BankPaymentDraft draft,
    required String idempotencyKey,
  }) {
    final replayed = _bankIdempotency[idempotencyKey];
    if (replayed != null) {
      return bankPayments.firstWhere((row) => row.id == replayed);
    }

    if (draft.paymentReference.trim().isEmpty) {
      throw const MockConflict(
        'A bank reference is required — it is what the payment is matched on.',
      );
    }
    if (!draft.amount.isPositive) {
      throw const MockConflict('Enter the amount that was transferred.');
    }
    final duplicate = bankPayments.any(
      (row) =>
          row.paymentReference.trim().toLowerCase() ==
          draft.paymentReference.trim().toLowerCase(),
    );
    if (duplicate) {
      throw const MockConflict(
        'That bank reference has already been recorded.',
      );
    }

    final payment = BankPayment(
      id: _nextId('bank-'),
      amount: draft.amount,
      paidAt: draft.paidAt,
      paymentMethod: draft.paymentMethod,
      paymentReference: draft.paymentReference.trim(),
      invoiceId: draft.invoiceId,
      tenantId: draft.tenantId ?? _server.currentTenant?.id,
      purpose: draft.purpose,
      paidByName: draft.paidByName,
      bankAccountNumber: draft.bankAccountNumber,
      bankName: draft.bankName,
      branchName: draft.branchName,
      proofOfPaymentUrl: draft.proofOfPaymentUrl,
      // Recorded, not reconciled. Somebody still has to check it against the
      // statement, and the invoice is not paid until they have.
      status: 'Pending review',
      createdByName: _server.currentUser?.fullName,
      createdAt: _server.now,
    );

    bankPayments.add(payment);
    _bankIdempotency[idempotencyKey] = payment.id;
    return payment;
  }

  final Map<String, String> _bankIdempotency = {};

  BankPayment updateBankPayment(BankPayment payment) {
    final index = bankPayments.indexWhere((row) => row.id == payment.id);
    if (index == -1) throw const MockNotFound('Bank payment not found');
    if (bankPayments[index].isProcessed) {
      throw const MockConflict(
        'This payment has been reconciled and can no longer be edited.',
      );
    }
    bankPayments[index] = payment;
    return payment;
  }

  void deleteBankPayment(String id) {
    final index = bankPayments.indexWhere((row) => row.id == id);
    if (index == -1) throw const MockNotFound('Bank payment not found');
    if (bankPayments[index].isProcessed) {
      throw const MockConflict(
        'This payment has been reconciled and can no longer be deleted.',
      );
    }
    bankPayments.removeAt(index);
  }

  // -------------------------------------------------------------------------
  // Access control
  // -------------------------------------------------------------------------

  List<PlatformUser> listUsers() {
    final rows = users
        .where((user) => !user.isDeleted)
        .map(
          (user) => _withRoles(user, userRoles[user.phoneNumber] ?? user.roles),
        )
        .toList();
    rows.sort((a, b) => a.fullName.compareTo(b.fullName));
    return List.unmodifiable(rows);
  }

  PlatformUser toggleUserEnabled(String userId) {
    final index = users.indexWhere(
      (user) => user.id == userId || user.userId == userId,
    );
    if (index == -1) throw const MockNotFound('Account not found');

    final existing = users[index];
    if (existing.id == _server.currentUser?.id) {
      throw const MockConflict('You cannot disable your own account.');
    }

    final updated = _copy(existing, isActive: !existing.isActive);
    users[index] = updated;
    return updated;
  }

  void deleteUser(String userId) {
    final index = users.indexWhere(
      (user) => user.id == userId || user.userId == userId,
    );
    if (index == -1) throw const MockNotFound('Account not found');
    if (users[index].id == _server.currentUser?.id) {
      throw const MockConflict('You cannot delete your own account.');
    }
    users[index] = _copy(users[index], isDeleted: true, isActive: false);
  }

  AccessRole createRole(String roleName) {
    final name = roleName.trim();
    if (name.isEmpty) throw const MockConflict('Give the role a name.');
    final exists = roles.any(
      (role) => role.name.toLowerCase() == name.toLowerCase(),
    );
    if (exists) throw MockConflict('A role called $name already exists.');

    final role = AccessRole(id: _nextId('role-'), name: name);
    roles.add(role);
    return role;
  }

  List<AccessRole> listRoles() {
    final rows = [...roles]..sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(rows);
  }

  List<AccessRole> rolesForUser(String phoneNumber) => List.unmodifiable([
    for (final name in userRoles[phoneNumber] ?? const <String>[])
      roles.firstWhere(
        (role) => role.name == name,
        orElse: () => AccessRole(name: name),
      ),
  ]);

  void addUserToRole({required String phoneNumber, required String roleName}) {
    _requireRole(roleName);
    final granted = userRoles.putIfAbsent(phoneNumber, () => <String>[]);
    if (granted.contains(roleName)) {
      throw MockConflict('This account already has the $roleName role.');
    }
    granted.add(roleName);
  }

  void removeUserFromRole({
    required String phoneNumber,
    required String roleName,
  }) {
    final granted = userRoles[phoneNumber];
    if (granted == null || !granted.remove(roleName)) {
      throw const MockNotFound('This account does not have that role.');
    }
  }

  List<AccessClaim> claimsForUser(String phoneNumber) =>
      List.unmodifiable(userClaims[phoneNumber] ?? const <AccessClaim>[]);

  void addClaimToUser({
    required String phoneNumber,
    required String claimType,
    required String claimValue,
  }) => _addClaim(userClaims, phoneNumber, claimType, claimValue);

  void removeClaimFromUser({
    required String phoneNumber,
    required String claimType,
    required String claimValue,
  }) => _removeClaim(userClaims, phoneNumber, claimType, claimValue);

  List<AccessClaim> claimsForRole(String roleName) =>
      List.unmodifiable(roleClaims[roleName] ?? const <AccessClaim>[]);

  void addClaimToRole({
    required String roleName,
    required String claimType,
    required String claimValue,
  }) {
    _requireRole(roleName);
    _addClaim(roleClaims, roleName, claimType, claimValue);
  }

  void removeClaimFromRole({
    required String roleName,
    required String claimType,
    required String claimValue,
  }) => _removeClaim(roleClaims, roleName, claimType, claimValue);

  void _requireRole(String roleName) {
    final exists = roles.any((role) => role.name == roleName);
    if (!exists) throw MockNotFound('There is no role called $roleName.');
  }

  void _addClaim(
    Map<String, List<AccessClaim>> store,
    String key,
    String type,
    String value,
  ) {
    final trimmedType = type.trim();
    final trimmedValue = value.trim();
    if (trimmedType.isEmpty || trimmedValue.isEmpty) {
      throw const MockConflict('A claim needs both a type and a value.');
    }

    final claims = store.putIfAbsent(key, () => <AccessClaim>[]);
    final duplicate = claims.any(
      (claim) => claim.type == trimmedType && claim.value == trimmedValue,
    );
    if (duplicate) throw const MockConflict('That claim is already granted.');

    claims.add(AccessClaim(type: trimmedType, value: trimmedValue));
  }

  void _removeClaim(
    Map<String, List<AccessClaim>> store,
    String key,
    String type,
    String value,
  ) {
    final claims = store[key];
    final removed =
        claims?.remove(
          claims.firstWhere(
            (claim) => claim.type == type && claim.value == value,
            orElse: () => const AccessClaim(type: '', value: ''),
          ),
        ) ??
        false;
    if (!removed) throw const MockNotFound('That claim is not granted.');
  }

  static PlatformUser _withRoles(PlatformUser user, List<String> roles) =>
      _copy(user, roles: roles);

  static PlatformUser _copy(
    PlatformUser user, {
    bool? isActive,
    bool? isDeleted,
    List<String>? roles,
  }) => PlatformUser(
    id: user.id,
    userId: user.userId,
    fullName: user.fullName,
    phoneNumber: user.phoneNumber,
    emailAddress: user.emailAddress,
    role: user.role,
    profileImage: user.profileImage,
    roles: roles ?? user.roles,
    isActive: isActive ?? user.isActive,
    isDeleted: isDeleted ?? user.isDeleted,
    emailConfirmed: user.emailConfirmed,
    phoneConfirmed: user.phoneConfirmed,
    twoFactorEnabled: user.twoFactorEnabled,
    lockoutEnabled: user.lockoutEnabled,
    lockedOutUntil: user.lockedOutUntil,
    createdByName: user.createdByName,
    lastLoginAt: user.lastLoginAt,
    createdAt: user.createdAt,
  );
}
