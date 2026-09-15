import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/error/failure.dart';
import 'package:mall/core/error/result.dart';
import 'package:mall/core/utils/money.dart';
import 'package:mall/domain/entities/booking.dart';
import 'package:mall/domain/entities/property.dart';
import 'package:mall/domain/entities/treasury.dart';
import 'package:mall/domain/entities/unit.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/domain/repositories/repositories.dart';
import 'support/mock/mock_repositories.dart';
import 'support/mock/mock_server.dart';

/// The parts of the published contract the app had no home for until now:
/// blocks, single units, invoice deferral, the treasury, and access control.
///
/// These assert *server* rules, the same way the booking and payment suites do
/// — what may be deleted, what may not, and what a write is allowed to move.
/// Where a rule protects money or a tenancy, the case is written from the
/// direction that would do the damage.
void main() {
  late MockServer server;
  late PropertyStructureRepository structure;
  late InvoiceRepository invoices;
  late TreasuryRepository treasury;
  late AccessRepository access;
  late AccountRepository account;

  setUp(() {
    server = MockServer();
    structure = MockPropertyStructureRepository(server);
    invoices = MockInvoiceRepository(server);
    treasury = MockTreasuryRepository(server);
    access = MockAccessRepository(server);
    account = MockAccountRepository(server);
    server.loginWithPassword('owner@karunaholdings.co.ke', 'a-password');
  });

  const kes = 'KES';
  Money kesOf(num major) => Money.fromMajor(major, kes);

  T unwrap<T>(Result<T> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError('expected Ok, got $failure'),
  };

  String propertyIdWithUnits() => server.units.values.first.propertyId;

  // -------------------------------------------------------------------------
  group('blocks', () {
    test('a block is created against its property and listed there', () async {
      final propertyId = propertyIdWithUnits();

      final created = await structure.createBlock(
        BuildingDraft(
          propertyId: propertyId,
          name: 'North Wing',
          status: BlockStatus.underConstruction,
          numberOfFloors: 3,
          totalUnits: 24,
          leasableUnits: 22,
        ),
      );
      expect(created.isOk, isTrue);

      final blocks = unwrap(await structure.listBlocks(propertyId));
      final block = blocks.firstWhere((b) => b.name == 'North Wing');

      expect(block.status, BlockStatus.underConstruction);
      expect(block.numberOfFloors, 3);
      expect(block.shapeLabel, '3 floors · 24 units');
    });

    test('renaming a block renames it on every unit inside it', () async {
      final unit = server.units.values.firstWhere(
        (row) => row.buildingId != null,
      );
      final blockId = unit.buildingId!;
      final block = unwrap(await structure.getBlock(blockId));

      unwrap(
        await structure.updateBlock(
          blockId: blockId,
          draft: BuildingDraft(
            propertyId: block.propertyId,
            name: 'Renamed Wing',
            status: block.status,
          ),
        ),
      );

      // The unit denormalises its block name for list rendering. A rename that
      // only reached the block would leave two different names on screen.
      expect(server.units[unit.id]!.buildingName, 'Renamed Wing');
    });

    test('a block holding units cannot be deleted', () async {
      final blockId = server.units.values
          .firstWhere((row) => row.buildingId != null)
          .buildingId!;

      final result = await structure.deleteBlock(blockId);

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<ConflictFailure>());
      // The refusal names the count, so it reads as an instruction.
      expect(result.failureOrNull!.message, contains('unit'));
    });

    test('an empty block can be deleted', () async {
      final propertyId = propertyIdWithUnits();
      unwrap(
        await structure.createBlock(
          BuildingDraft(
            propertyId: propertyId,
            name: 'Empty Wing',
            status: BlockStatus.active,
          ),
        ),
      );
      final blocks = unwrap(await structure.listBlocks(propertyId));
      final empty = blocks.firstWhere((b) => b.name == 'Empty Wing');

      expect((await structure.deleteBlock(empty.id)).isOk, isTrue);

      final after = unwrap(await structure.listBlocks(propertyId));
      expect(after.any((b) => b.id == empty.id), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('units', () {
    test(
      'a created unit is available and keeps the rent it was given',
      () async {
        final propertyId = propertyIdWithUnits();

        unwrap(
          await structure.createUnit(
            UnitDraft(
              propertyId: propertyId,
              unitNumber: 'KIOSK-9',
              category: UnitCategory.kiosk,
              monthlyRent: kesOf(45000),
              area: 220,
              floorNumber: 0,
            ),
          ),
        );

        final created = server.units.values.firstWhere(
          (row) => row.unitNumber == 'KIOSK-9',
        );

        expect(created.status, UnitStatus.available);
        expect(created.baseRent, kesOf(45000));
        expect(created.category, UnitCategory.kiosk);
        expect(created.floorName, 'Ground floor');
        // Entered by hand, so a later repricing of the property leaves it alone.
        expect(created.rentOverridden, isTrue);
      },
    );

    test('a let unit cannot be removed', () async {
      final leased = server.leases.values.firstWhere(
        (lease) => lease.status.isCurrent,
      );

      final result = await structure.deleteUnit(leased.unitId);

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<ConflictFailure>());
    });

    test(
      'removing a free unit keeps the record and drops it from lists',
      () async {
        final propertyId = propertyIdWithUnits();
        unwrap(
          await structure.createUnit(
            UnitDraft(
              propertyId: propertyId,
              unitNumber: 'TEMP-1',
              category: UnitCategory.storage,
              monthlyRent: kesOf(10000),
            ),
          ),
        );
        final unit = server.units.values.firstWhere(
          (row) => row.unitNumber == 'TEMP-1',
        );

        expect((await structure.deleteUnit(unit.id)).isOk, isTrue);

        // Soft, like the contract's own delete: the row survives so anything
        // pointing at it still resolves.
        expect(server.units[unit.id], isNotNull);
        expect(server.units[unit.id]!.isDeleted, isTrue);
      },
    );
  });

  // -------------------------------------------------------------------------
  group('invoice deferral and settlement', () {
    test('deferring records the request without moving the balance', () async {
      final row = server.invoices.values.firstWhere(
        (invoice) => invoice.status.isPayable,
      );
      final owed = row.amountDue;

      unwrap(
        await invoices.deferInvoice(
          invoiceId: row.id,
          reason: 'Waiting on a customer payment',
        ),
      );

      final after = server.invoices[row.id]!;
      expect(after.isDeferred, isTrue);
      expect(after.deferReason, 'Waiting on a customer payment');
      // The whole point: a postponement moves the conversation, not the debt.
      expect(after.amountDue, owed);
      expect(after.status, row.status);
    });

    test('a deferred invoice cannot be deferred again', () async {
      final row = server.invoices.values.firstWhere(
        (invoice) => invoice.status.isPayable,
      );
      unwrap(
        await invoices.deferInvoice(invoiceId: row.id, reason: 'Cash flow'),
      );

      final domain = unwrap(await invoices.getInvoice(row.id));
      expect(domain.canRequestDeferral, isFalse);
    });

    test('settling clears the balance and stamps when', () async {
      final row = server.invoices.values.firstWhere(
        (invoice) => invoice.status.isPayable,
      );

      unwrap(await invoices.settleInvoice(row.id));

      final after = server.invoices[row.id]!;
      expect(after.status, InvoiceStatus.paid);
      expect(after.amountDue.isZero, isTrue);
      expect(after.settledOn, isNotNull);
    });

    test('an owner reads the invoices of a named tenant', () async {
      final row = server.invoices.values.first;

      final page = unwrap(await invoices.listInvoicesForTenant(row.tenantId));

      expect(page.items, isNotEmpty);
      // Scoped to the tenant asked about, not to whoever is signed in — which
      // is an owner here, and has no invoices of their own.
      expect(
        page.items.every((invoice) => invoice.tenantId == row.tenantId),
        isTrue,
      );
    });

    test('a settled invoice cannot be settled twice', () async {
      final row = server.invoices.values.firstWhere(
        (invoice) => invoice.status.isPayable,
      );
      unwrap(await invoices.settleInvoice(row.id));

      final second = await invoices.settleInvoice(row.id);
      expect(second.isErr, isTrue);
      expect(second.failureOrNull, isA<ConflictFailure>());
    });
  });

  // -------------------------------------------------------------------------
  group('treasury', () {
    test(
      'an unallocated payment is credited without changing the amount',
      () async {
        final orphan = unwrap(
          await treasury.listMpesaTransactions(),
        ).firstWhere((row) => !row.processed);
        final received = orphan.amount;

        unwrap(
          await treasury.setMpesaAccountNumber(
            transactionId: orphan.id,
            accountNumber: 'INV-1042',
          ),
        );

        final after = unwrap(
          await treasury.listMpesaTransactions(),
        ).firstWhere((row) => row.id == orphan.id);

        expect(after.accountNumber, 'INV-1042');
        expect(after.processed, isTrue);
        expect(after.isEdited, isTrue);
        // Section 84 rule 1: correcting a reference is not a licence to change
        // what arrived.
        expect(after.amount, received);
      },
    );

    test('a blank account number is refused', () async {
      final orphan = unwrap(
        await treasury.listMpesaTransactions(),
      ).firstWhere((row) => !row.processed);

      final result = await treasury.setMpesaAccountNumber(
        transactionId: orphan.id,
        accountNumber: '   ',
      );
      expect(result.isErr, isTrue);
    });

    BankPaymentDraft draft({String reference = 'FT-0001'}) => BankPaymentDraft(
      amount: kesOf(150000),
      paidAt: DateTime.now(),
      paymentMethod: 'RTGS',
      paymentReference: reference,
      paidByName: 'Nyota Retail Ltd',
    );

    test('a recorded payment is pending, not reconciled', () async {
      unwrap(
        await treasury.recordBankPayment(
          draft: draft(),
          idempotencyKey: 'bank-1',
        ),
      );

      final rows = unwrap(await treasury.listBankPayments());
      final recorded = rows.firstWhere(
        (row) => row.paymentReference == 'FT-0001',
      );

      // Somebody still has to check it against the statement. Recording is not
      // reconciling, and the invoice is not paid until it is.
      expect(recorded.isProcessed, isFalse);
      expect(recorded.status, 'Pending review');
    });

    test('the same key replays rather than recording twice', () async {
      unwrap(
        await treasury.recordBankPayment(
          draft: draft(),
          idempotencyKey: 'bank-retry',
        ),
      );
      unwrap(
        await treasury.recordBankPayment(
          draft: draft(),
          idempotencyKey: 'bank-retry',
        ),
      );

      final matching = unwrap(
        await treasury.listBankPayments(),
      ).where((row) => row.paymentReference == 'FT-0001');
      expect(matching.length, 1);
    });

    test('a bank reference cannot be recorded twice under new keys', () async {
      unwrap(
        await treasury.recordBankPayment(
          draft: draft(),
          idempotencyKey: 'bank-a',
        ),
      );

      final second = await treasury.recordBankPayment(
        draft: draft(),
        idempotencyKey: 'bank-b',
      );

      expect(second.isErr, isTrue);
      expect(second.failureOrNull, isA<ConflictFailure>());
    });

    test('a payment with no reference is refused', () async {
      final result = await treasury.recordBankPayment(
        draft: draft(reference: '  '),
        idempotencyKey: 'bank-blank',
      );
      expect(result.isErr, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('access control', () {
    test('a role grant shows up against the account', () async {
      final user = unwrap(
        await access.listUsers(),
      ).firstWhere((row) => row.roles.contains('FinanceOfficer'));
      final phone = user.phoneNumber!;

      unwrap(
        await access.addUserToRole(
          phoneNumber: phone,
          roleName: 'PropertyManager',
        ),
      );

      final roles = unwrap(await access.rolesForUser(phone));
      expect(roles.map((role) => role.name), contains('PropertyManager'));
    });

    test('the same role cannot be granted twice', () async {
      final user = unwrap(
        await access.listUsers(),
      ).firstWhere((row) => row.roles.contains('Administrator'));

      final result = await access.addUserToRole(
        phoneNumber: user.phoneNumber!,
        roleName: 'Administrator',
      );
      expect(result.isErr, isTrue);
    });

    test('a role that does not exist cannot be granted', () async {
      final user = unwrap(await access.listUsers()).first;

      final result = await access.addUserToRole(
        phoneNumber: user.phoneNumber!,
        roleName: 'Sorcerer',
      );
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('a duplicate role name is refused', () async {
      expect((await access.createRole('Auditor')).isOk, isTrue);
      expect((await access.createRole('auditor')).isErr, isTrue);
    });

    test('claims are granted and revoked against a role', () async {
      unwrap(await access.createRole('Auditor'));

      unwrap(
        await access.addClaimToRole(
          roleName: 'Auditor',
          claimType: 'permission',
          claimValue: 'reports.read',
        ),
      );
      expect(
        unwrap(await access.claimsForRole('Auditor')).single.value,
        'reports.read',
      );

      unwrap(
        await access.removeClaimFromRole(
          roleName: 'Auditor',
          claimType: 'permission',
          claimValue: 'reports.read',
        ),
      );
      expect(unwrap(await access.claimsForRole('Auditor')), isEmpty);
    });

    test('the same claim cannot be granted twice', () async {
      unwrap(await access.createRole('Auditor'));
      unwrap(
        await access.addClaimToRole(
          roleName: 'Auditor',
          claimType: 'permission',
          claimValue: 'reports.read',
        ),
      );

      final second = await access.addClaimToRole(
        roleName: 'Auditor',
        claimType: 'permission',
        claimValue: 'reports.read',
      );
      expect(second.isErr, isTrue);
    });

    test('an administrator cannot disable their own account', () async {
      final me = unwrap(await account.getAccount());

      final result = await access.toggleUserEnabled(me.userId ?? me.id);

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<ConflictFailure>());
    });

    test('disabling another account flips it and leaves it listed', () async {
      final other = unwrap(
        await access.listUsers(),
      ).firstWhere((row) => row.roles.contains('PropertyManager'));

      unwrap(await access.toggleUserEnabled(other.userId ?? other.id));

      final after = unwrap(
        await access.listUsers(),
      ).firstWhere((row) => row.id == other.id);

      expect(after.isActive, isFalse);
      // Shown, not hidden: an administrator asking why somebody cannot sign in
      // has to be able to find the account to answer it.
      expect(after.isDeleted, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('the signed-in account', () {
    test('a changed password is required at the next sign-in', () async {
      final me = unwrap(await account.getAccount());
      final phone = me.phoneNumber!;

      unwrap(
        await account.changePassword(
          phoneNumber: phone,
          currentPassword: 'a-password',
          newPassword: 'a-longer-password',
        ),
      );

      // The mock accepts anything until a password is set, and the new one
      // afterwards — so the screen does something the next sign-in notices.
      expect(server.loginWithPassword(phone, 'a-longer-password'), isNotNull);
      expect(server.loginWithPassword(phone, 'the-old-one'), isNull);
    });

    test('a short password is refused', () async {
      final me = unwrap(await account.getAccount());

      final result = await account.changePassword(
        phoneNumber: me.phoneNumber!,
        currentPassword: 'a-password',
        newPassword: 'short',
      );
      expect(result.isErr, isTrue);
    });

    test('a reset needs the code that was sent', () async {
      final me = unwrap(await account.getAccount());

      final wrong = await account.resetPassword(
        phoneNumber: me.phoneNumber!,
        resetToken: '000000',
        newPassword: 'a-longer-password',
      );
      expect(wrong.isErr, isTrue);

      final right = await account.resetPassword(
        phoneNumber: me.phoneNumber!,
        resetToken: MockServer.demoOtp,
        newPassword: 'a-longer-password',
      );
      expect(right.isOk, isTrue);
    });

    test('confirming an email marks it confirmed', () async {
      final me = unwrap(await account.getAccount());

      unwrap(
        await account.confirmEmail(
          email: me.emailAddress!,
          token: MockServer.demoOtp,
        ),
      );

      expect(unwrap(await account.getAccount()).emailConfirmed, isTrue);
    });

    test('a wrong verification code is refused', () async {
      final me = unwrap(await account.getAccount());

      final result = await account.confirmEmail(
        email: me.emailAddress!,
        token: '999999',
      );
      expect(result.isErr, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  test('a booking carries the applicant it was made by', () async {
    server.loginWithPassword('amina@example.co.ke', 'a-password');
    final bookings = MockBookingRepository(server);

    const applicant = BookingApplicant(
      fullName: 'Amina Wanjiru',
      phoneNumber: '254712345678',
      email: 'amina@example.co.ke',
      companyName: 'Wanjiru Fabrics',
      businessType: 'Fashion and apparel',
    );

    final booking = unwrap(
      await bookings.createBooking(
        unitId: 'unt_shop_102',
        applicant: applicant,
        idempotencyKey: 'applicant-key',
      ),
    );

    final row = server.bookings[booking.id]!;
    expect(row.applicant?.companyName, 'Wanjiru Fabrics');
    expect(row.applicant?.businessType, 'Fashion and apparel');
    expect(row.applicant?.isCompany, isTrue);
  });
}
