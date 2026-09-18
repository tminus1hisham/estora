import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/error/failure.dart';
import 'package:mall/core/error/result.dart';
import 'package:mall/core/theme/app_theme.dart';
import 'package:mall/components/collection_columns.dart';
import 'package:mall/core/utils/money.dart';
import 'package:mall/domain/entities/owner.dart';
import 'package:mall/domain/entities/treasury.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/domain/repositories/repositories.dart';
import 'package:mall/modules/invoices/presentation/invoices_screen.dart';
import 'package:mall/modules/invoices/presentation/widgets/invoice_focus_card.dart';
import 'package:mall/modules/leases/presentation/leases_screen.dart';
import 'package:mall/modules/owner/presentation/owner_money_screen.dart';
import 'package:mall/modules/treasury/presentation/bank_payments_screen.dart';
import 'package:mall/modules/treasury/presentation/mpesa_transactions_screen.dart';
import 'package:mall/services/demo/demo_fixtures.dart';
import 'package:mall/services/demo/demo_repositories.dart';
import 'package:mall/services/providers.dart';

/// The `--dart-define=DEMO_DATA=true` fixtures.
///
/// Two things are worth holding. The figures must be consistent with each
/// other the way a server's would be — the screens do no arithmetic, so a
/// ledger whose bands do not add up to its total would be shown as-is. And
/// the three screens must actually build on them at phone width, since the
/// whole point of the fixtures is to be looked at.
void main() {
  late DemoFixtures fixtures;

  setUp(() => fixtures = DemoFixtures());

  group('the fixtures agree with themselves', () {
    test('every invoice balances', () {
      for (final invoice in fixtures.invoices.values) {
        expect(
          invoice.total,
          invoice.subtotal + invoice.tax,
          reason: invoice.id,
        );
        expect(
          invoice.amountDue,
          invoice.total - invoice.amountPaid,
          reason: invoice.id,
        );
        expect(invoice.lines, isNotEmpty, reason: invoice.id);
        expect(
          invoice.lines.fold(
            Money.zero(invoice.currency),
            (sum, line) => sum + line.amount,
          ),
          invoice.subtotal,
          reason: invoice.id,
        );
      }
    });

    test('the statement leads with this month\'s rent, not the deferral', () {
      final focus = InvoiceFocusCard.focusOf(fixtures.invoices.values.toList());
      expect(focus, isNotNull);
      expect(focus!.isDeferred, isFalse);
      expect(focus.status, InvoiceStatus.partiallyPaid);
      expect(focus.lines.single.lineType, InvoiceLineType.rent);
      expect(focus.amountDue, Money.fromMajor(50000, 'KES'));
    });

    test('the ledger adds up', () {
      final ledger = fixtures.ledger;
      expect(
        ledger.netThisMonth,
        ledger.collectedThisMonth - ledger.platformFeeThisMonth,
      );
      expect(
        ledger.ageing.fold(
          Money.zero(ledger.currency),
          (sum, bucket) => sum + bucket.amount,
        ),
        ledger.totalOutstanding,
      );
      final thisMonth = DateTime(fixtures.now.year, fixtures.now.month);
      expect(
        ledger.collections
            .where((c) => !c.paidAt.isBefore(thisMonth))
            .fold(Money.zero(ledger.currency), (sum, c) => sum + c.amount),
        ledger.collectedThisMonth,
      );
      for (final payout in ledger.payouts) {
        expect(payout.net, payout.grossCollected - payout.platformFee);
      }
      // Collections are newest first; history and payouts oldest first.
      expect(
        ledger.collections.map((c) => c.paidAt).toList(),
        ledger.collections.map((c) => c.paidAt).toList()
          ..sort((a, b) => b.compareTo(a)),
      );
      expect(ledger.history.last.month, thisMonth);
      expect(ledger.payouts.last.month, thisMonth);
    });

    test('the till and the bank agree with the ledger', () {
      final ledger = fixtures.ledger;
      for (final row in fixtures.mpesa.where((row) => row.processed)) {
        final collection = ledger.collections.firstWhere(
          (c) => 'demo-mpesa-${c.paymentId}' == row.id,
        );
        expect(row.amount, collection.amount, reason: row.transactionId);
        expect(row.transactedAt, collection.paidAt, reason: row.transactionId);
      }
      // The orphans lead, and there is more than one of them.
      expect(fixtures.mpesa.takeWhile((row) => !row.processed).length, 2);
      expect(
        fixtures.bankPayments.where((row) => !row.isProcessed),
        hasLength(2),
      );
      for (final row in fixtures.bankPayments.where((row) => row.isProcessed)) {
        expect(
          ledger.collections.any(
            (c) => c.amount == row.amount && c.paidAt == row.paidAt,
          ),
          isTrue,
          reason: row.paymentReference,
        );
      }
    });

    test('one lease is live and the rest are history', () {
      final statuses = fixtures.leases.values.map((l) => l.status).toList();
      expect(statuses.where((s) => s.isCurrent), hasLength(1));
      expect(statuses.where((s) => s.needsTenantSignature), isEmpty);
      for (final lease in fixtures.leases.values) {
        expect(
          fixtures.agreements[lease.id]?.body,
          contains(lease.leaseNumber),
        );
      }
    });
  });

  group('collections over a window', () {
    test('the month answers with the ledger’s own figures', () {
      final series = fixtures.collectionsOver(const CollectionWindow.month());

      expect(series.collected, fixtures.ledger.collectedThisMonth);
      expect(series.platformFee, fixtures.ledger.platformFeeThisMonth);
      expect(series.net, fixtures.ledger.netThisMonth);
      expect(series.points, hasLength(fixtures.ledger.history.length));
      for (final (i, point) in series.points.indexed) {
        expect(point.collected, fixtures.ledger.history[i].collected);
        expect(point.billed, fixtures.ledger.history[i].billed);
      }
    });

    test('yesterday holds the one arrival seeded there', () {
      final series = fixtures.collectionsOver(
        const CollectionWindow.yesterday(),
      );

      expect(series.paymentCount, 1);
      expect(series.collected, Money.fromMajor(100000, 'KES'));
      expect(series.net, series.collected - series.platformFee);
      // Bahari paid at 11:00, so that hour's column carries the whole figure
      // and nothing else is drawn as billed.
      expect(series.points, hasLength(24));
      expect(series.points[11].collected, series.collected);
      expect(series.points.every((point) => point.billed == null), isTrue);
    });

    test('today is honestly empty', () {
      final series = fixtures.collectionsOver(const CollectionWindow.today());

      expect(series.isEmpty, isTrue);
      expect(series.collected.isZero, isTrue);
    });

    test('a custom span of this month agrees with the ledger’s arrivals', () {
      final now = fixtures.now;
      final series = fixtures.collectionsOver(
        CollectionWindow.custom(
          from: DateTime(now.year, now.month, 2),
          to: DateTime(now.year, now.month, 5),
        ),
      );

      // Nuru on the 2nd, Sifa on the 3rd, Anga on the 4th, Rafiki on the 5th;
      // both ends inclusive, so Bahari on the 1st and Tembo on the 6th stay
      // out.
      expect(series.paymentCount, 4);
      expect(series.collected, Money.fromMajor(385000, 'KES'));
      expect(series.points, hasLength(4));
      expect(series.points[0].collected, Money.fromMajor(45000, 'KES'));
      expect(series.points[3].collected, Money.fromMajor(135000, 'KES'));
    });
  });

  group('the demo repositories', () {
    test('a deferral is kept for the next read', () async {
      final repo = DemoInvoiceRepository(fixtures);
      final open = fixtures.invoices.values.firstWhere(
        (invoice) => invoice.canRequestDeferral,
      );

      final result = await repo.deferInvoice(
        invoiceId: open.id,
        reason: 'Awaiting a client payment.',
      );
      expect(result.isOk, isTrue);

      final read = await repo.getInvoice(open.id);
      expect(read.value.isDeferred, isTrue);
      expect(read.value.deferReason, 'Awaiting a client payment.');
      // Deferral moves the conversation, not the debt.
      expect(read.value.amountDue, open.amountDue);
    });

    test('signing checks the hash and leaves a live lease alone', () async {
      final repo = DemoLeaseRepository(fixtures);
      final live = fixtures.leases.values.firstWhere(
        (lease) => lease.status.isCurrent,
      );

      final stale = await repo.signLease(
        leaseId: live.id,
        signatureType: SignatureType.drawnSignature,
        signatureData: const [1, 2, 3],
        documentHash: 'not-the-hash',
        idempotencyKey: 'k1',
      );
      expect(stale, isA<Err<Object?>>());
      expect((stale as Err).failure, isA<ConflictFailure>());

      final current = await repo.signLease(
        leaseId: live.id,
        signatureType: SignatureType.drawnSignature,
        signatureData: const [1, 2, 3],
        documentHash: fixtures.agreements[live.id]!.documentHash,
        idempotencyKey: 'k2',
      );
      expect(current.value.status, LeaseStatus.active);
    });

    test('correcting an account number reconciles the orphan', () async {
      final repo = DemoTreasuryRepository(fixtures);
      final orphan = fixtures.mpesa.firstWhere((row) => !row.processed);

      final result = await repo.setMpesaAccountNumber(
        transactionId: orphan.id,
        accountNumber: 'SHOP-108',
      );
      expect(result.isOk, isTrue);

      final found = await repo.findMpesaTransactions(orphan.transactionId);
      expect(found.value.single.processed, isTrue);
      expect(found.value.single.accountNumber, 'SHOP-108');
      expect(found.value.single.isEdited, isTrue);
    });

    test('a bank payment keyed twice is one payment', () async {
      final repo = DemoTreasuryRepository(fixtures);
      final before = fixtures.bankPayments.length;
      final draft = BankPaymentDraft(
        amount: Money.fromMajor(12000, 'KES'),
        paidAt: DateTime.now(),
        paymentMethod: 'EFT',
        paymentReference: 'FT26260NEW01',
        paidByName: 'Nuru Fashions',
      );

      await repo.recordBankPayment(draft: draft, idempotencyKey: 'a');
      await repo.recordBankPayment(draft: draft, idempotencyKey: 'b');

      final listed = await repo.listBankPayments();
      expect(listed.value, hasLength(before + 1));
      expect(listed.value.first.paymentReference, 'FT26260NEW01');
      expect(listed.value.first.isProcessed, isFalse);

      await repo.deleteBankPayment(listed.value.first.id);
      expect((await repo.listBankPayments()).value, hasLength(before));
    });

    test('an unknown id is a not-found, not a blank', () async {
      expect(
        (await DemoLeaseRepository(fixtures).getLease('nope')).failureOrNull,
        isA<NotFoundFailure>(),
      );
      expect(
        (await DemoInvoiceRepository(
          fixtures,
        ).getInvoice('nope')).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });
  });

  group('the screens build on them', () {
    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Widget app(Widget screen, {ThemeData? theme}) => ProviderScope(
      overrides: [
        leaseRepositoryProvider.overrideWithValue(
          DemoLeaseRepository(fixtures),
        ),
        invoiceRepositoryProvider.overrideWithValue(
          DemoInvoiceRepository(fixtures),
        ),
        ownerRepositoryProvider.overrideWithValue(
          DemoOwnerRepository(fixtures, _NoOwner()),
        ),
        treasuryRepositoryProvider.overrideWithValue(
          DemoTreasuryRepository(fixtures),
        ),
      ],
      child: MaterialApp(theme: theme ?? AppTheme.light, home: screen),
    );

    // The rows that come in on the last frame each start a staggered entry;
    // those are timers, and pumpAndSettle alone would leave them pending.
    Future<void> settle(WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    testWidgets('money', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        app(const OwnerMoneyScreen(), theme: AppTheme.ownerStage),
      );
      await settle(tester);

      expect(find.text('COLLECTED THIS MONTH'), findsOneWidget);
      // One property in the fixtures' list: no strip to cut the report by.
      expect(find.text('All properties'), findsNothing);
      expect(find.text('OWED TO YOU'), findsOneWidget);
      // The services invoice falls due in four days whatever today is.
      expect(find.text('Not yet due'), findsOneWidget);
      // The arrivals sit below the fold on a phone, named as the till named
      // the payer.
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await settle(tester);
      expect(find.text('OUTSTANDING INVOICES'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await settle(tester);
      expect(find.text('BAHARI COFFEE'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('money switches between windows without blanking', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        app(const OwnerMoneyScreen(), theme: AppTheme.ownerStage),
      );
      await settle(tester);

      expect(find.text('COLLECTED THIS MONTH'), findsOneWidget);

      await tester.tap(find.text('Yesterday'));
      await settle(tester);

      // Bahari's rent and the orphaned Rafiki payment both landed yesterday.
      expect(find.text('COLLECTED YESTERDAY'), findsOneWidget);
      expect(find.text('KES 235,000'), findsWidgets);
      expect(
        find.textContaining('2 M-Pesa payments yesterday.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Today'));
      await settle(tester);

      expect(find.text('COLLECTED TODAY'), findsOneWidget);
      expect(find.text('Nothing came in today.'), findsOneWidget);
      expect(find.byType(CollectionColumns), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('leases', (tester) async {
      phone(tester);
      await tester.pumpWidget(app(const LeasesScreen()));
      await settle(tester);

      expect(find.text('PREVIOUS LEASES'), findsOneWidget);
      expect(find.text('Unit SHOP-101'), findsWidgets);
      expect(find.text('Sarit Mall'), findsWidgets);
      expect(find.text('Lease details'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('m-pesa payments', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        app(const MpesaTransactionsScreen(), theme: AppTheme.ownerStage),
      );
      await settle(tester);

      expect(find.text('NEEDS AN ACCOUNT NUMBER'), findsOneWidget);
      expect(find.text('Unallocated'), findsNWidgets(2));
      expect(find.text('RECONCILED'), findsOneWidget);
      expect(find.text('TIG8FN3QRD'), findsOneWidget);
      expect(find.textContaining('RAFIKI PHARMACY'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bank payments', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        app(const BankPaymentsScreen(), theme: AppTheme.ownerStage),
      );
      await settle(tester);

      expect(find.text('AWAITING REVIEW'), findsOneWidget);
      expect(find.text('RECONCILED'), findsOneWidget);
      expect(find.text('FT26259Q8K2M'), findsOneWidget);
      expect(find.text('Pending review'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invoices', (tester) async {
      phone(tester);
      await tester.pumpWidget(app(const InvoicesScreen()));
      await settle(tester);

      expect(find.byType(InvoiceFocusCard), findsOneWidget);
      expect(find.text('KES 50,000'), findsWidgets);
      expect(find.text('KES 20,632'), findsWidgets);
      expect(find.text('Outstanding'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Stands in for the API behind [DemoOwnerRepository]; the Money screen only
/// ever asks the decorator for the ledger.
class _NoOwner implements OwnerRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} reached the API');
}
