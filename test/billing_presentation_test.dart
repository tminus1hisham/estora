import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/theme/app_theme.dart';
import 'package:mall/core/utils/money.dart';
import 'package:mall/domain/entities/billing.dart';
import 'package:mall/domain/entities/lease.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/modules/invoices/application/invoice_controller.dart';
import 'package:mall/modules/invoices/presentation/invoice_detail_screen.dart';
import 'package:mall/modules/invoices/presentation/invoices_screen.dart';
import 'package:mall/modules/leases/application/lease_controller.dart';
import 'package:mall/modules/leases/presentation/lease_detail_screen.dart';
import 'package:mall/modules/leases/presentation/leases_screen.dart';

Invoice _invoice({
  required String id,
  required String number,
  required InvoiceStatus status,
  required DateTime issued,
  required DateTime due,
  int total = 15000000,
  int paid = 0,
}) {
  return Invoice(
    id: id,
    invoiceNumber: number,
    tenantId: 'tnt_1',
    status: status,
    invoiceDate: issued,
    dueDate: due,
    subtotal: Money(total, 'KES'),
    tax: Money(total ~/ 10, 'KES'),
    discount: const Money(0, 'KES'),
    total: Money(total, 'KES'),
    amountPaid: Money(paid, 'KES'),
    amountDue: Money(total - paid, 'KES'),
    currency: 'KES',
    propertyName: 'Sarit Mall',
    unitNumber: 'SHOP-101',
    billingPeriodStart: DateTime(issued.year, issued.month),
    billingPeriodEnd: DateTime(issued.year, issued.month + 1, 0),
    lines: [
      InvoiceLine(
        id: '$id-1',
        invoiceId: id,
        description: 'Monthly rent',
        quantity: 1,
        unitPrice: Money(total, 'KES'),
        amount: Money(total, 'KES'),
        lineType: InvoiceLineType.rent,
        taxRate: 16,
        taxAmount: Money(total ~/ 10, 'KES'),
      ),
      InvoiceLine(
        id: '$id-2',
        invoiceId: id,
        description: 'Service charge',
        quantity: 2,
        unitPrice: const Money(500000, 'KES'),
        amount: const Money(1000000, 'KES'),
        lineType: InvoiceLineType.serviceCharge,
      ),
    ],
  );
}

final _invoices = <Invoice>[
  _invoice(
    id: 'inv_overdue',
    number: 'INV-2026-0031',
    status: InvoiceStatus.overdue,
    issued: DateTime(2026, 7, 1),
    due: DateTime(2026, 7, 5),
  ),
  _invoice(
    id: 'inv_open',
    number: 'INV-2026-0042',
    status: InvoiceStatus.issued,
    issued: DateTime(2026, 8, 1),
    due: DateTime(2026, 8, 18),
  ),
  _invoice(
    id: 'inv_paid',
    number: 'INV-2026-0020',
    status: InvoiceStatus.paid,
    issued: DateTime(2026, 6, 1),
    due: DateTime(2026, 6, 5),
    paid: 15000000,
  ),
];

final _lease = Lease(
  id: 'lse_1',
  leaseNumber: 'LSE-2026-0007',
  propertyId: 'prp_1',
  unitId: 'unt_1',
  tenantId: 'tnt_1',
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2026, 12, 31),
  monthlyRent: const Money(15000000, 'KES'),
  depositAmount: const Money(75000000, 'KES'),
  billingFrequency: BillingFrequency.monthly,
  paymentDueDay: 5,
  status: LeaseStatus.active,
  createdAt: DateTime(2025, 12, 1),
  signedAt: DateTime(2025, 12, 10),
  activatedAt: DateTime(2026, 1, 1),
  propertyName: 'Sarit Mall',
  unitNumber: 'SHOP-101',
  terms: [
    const LeaseTerm(
      id: 't1',
      label: 'Permitted use',
      value: 'Retail — fashion and accessories',
      group: 'Use and occupation',
    ),
    const LeaseTerm(
      id: 't2',
      label: 'Notice period',
      value: '90 days',
      group: 'Notice and renewal',
    ),
  ],
  activationConditions: const [
    LeaseActivationCondition(
      id: 'c1',
      label: 'Deposit paid in full',
      isMet: true,
      isMandatory: true,
      detail: 'KES 750,000',
    ),
    LeaseActivationCondition(
      id: 'c2',
      label: 'Insurance certificate',
      isMet: false,
      isMandatory: false,
    ),
  ],
  signatures: [
    LeaseSignature(
      id: 's1',
      leaseId: 'lse_1',
      signatureType: SignatureType.drawnSignature,
      signedAt: DateTime(2025, 12, 10, 14, 30),
      signerName: 'Amina Wanjiru',
      documentHash: 'a91f4c22e8',
    ),
  ],
);

final _pendingLease = Lease(
  id: 'lse_2',
  leaseNumber: 'LSE-2027-0002',
  propertyId: 'prp_1',
  unitId: 'unt_2',
  tenantId: 'tnt_1',
  startDate: DateTime(2027, 1, 1),
  endDate: DateTime(2027, 12, 31),
  monthlyRent: const Money(16500000, 'KES'),
  depositAmount: const Money(82500000, 'KES'),
  billingFrequency: BillingFrequency.monthly,
  paymentDueDay: 5,
  status: LeaseStatus.pendingSignature,
  createdAt: DateTime(2026, 8, 1),
  propertyName: 'Sarit Mall',
  unitNumber: 'SHOP-101',
);

class _Invoices extends InvoiceListController {
  @override
  Future<List<Invoice>> build() async => _invoices;
}

class _EmptyInvoices extends InvoiceListController {
  @override
  Future<List<Invoice>> build() async => const <Invoice>[];
}

class _SettledInvoices extends InvoiceListController {
  @override
  Future<List<Invoice>> build() async => [_invoices.last];
}

class _Leases extends LeaseListController {
  @override
  Future<List<Lease>> build() async => [_pendingLease, _lease];
}

class _SingleLease extends LeaseListController {
  @override
  Future<List<Lease>> build() async => [_lease];
}

void main() {
  Widget themed(Widget child) =>
      MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark, home: child);

  void viewport(WidgetTester tester, Size size, {double textScale = 1}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
  }

  // A lazy list only overflows on the frame that builds the offending row, so
  // every case is scrolled from top to bottom before it is judged clean.
  Future<void> sweep(WidgetTester tester, Size size) async {
    final from = Offset(size.width / 2, size.height * 0.7);
    for (var i = 0; i < 8; i++) {
      await tester.dragFrom(from, const Offset(0, -320));
      await tester.pumpAndSettle();
    }
    // The rows built on the last frame each start a staggered entry, and those
    // delays are timers rather than frames — pumpAndSettle would leave them
    // pending and the binding would fail the test on teardown.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(360, 690), Size(390, 844), Size(834, 1112)]) {
    for (final scale in const [1.0, 1.4, 2.0]) {
      final name = '${size.width.toInt()}x${size.height.toInt()} @$scale';

      testWidgets('invoices lay out cleanly at $name', (tester) async {
        viewport(tester, size, textScale: scale);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [invoiceListProvider.overrideWith(_Invoices.new)],
            child: themed(const InvoicesScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await sweep(tester, size);

        expect(tester.takeException(), isNull);
      });

      testWidgets('invoice detail lays out cleanly at $name', (tester) async {
        viewport(tester, size, textScale: scale);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              invoiceDetailProvider(
                'inv_overdue',
              ).overrideWith((ref) async => _invoices.first),
            ],
            child: themed(const InvoiceDetailScreen(invoiceId: 'inv_overdue')),
          ),
        );
        await tester.pumpAndSettle();
        await sweep(tester, size);

        expect(tester.takeException(), isNull);
      });

      testWidgets('the lease screen lays out cleanly at $name', (tester) async {
        viewport(tester, size, textScale: scale);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [leaseListProvider.overrideWith(_Leases.new)],
            child: themed(const LeasesScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await sweep(tester, size);

        expect(tester.takeException(), isNull);
      });

      testWidgets('lease detail lays out cleanly at $name', (tester) async {
        viewport(tester, size, textScale: scale);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              leaseDetailProvider('lse_1').overrideWith((ref) async => _lease),
            ],
            child: themed(const LeaseDetailScreen(leaseId: 'lse_1')),
          ),
        );
        await tester.pumpAndSettle();
        await sweep(tester, size);

        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the statement opens on the invoice that falls due next', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [invoiceListProvider.overrideWith(_Invoices.new)],
        child: themed(const InvoicesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The overdue one, not the newest.
    expect(find.text('PAST DUE'), findsOneWidget);
    expect(find.text('INV-2026-0031'), findsWidgets);
    expect(find.text('Pay now'), findsOneWidget);
    expect(find.text('AUGUST 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invoices with nothing outstanding show the settled card', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [invoiceListProvider.overrideWith(_SettledInvoices.new)],
        child: themed(const InvoicesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing outstanding'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty invoice list still refreshes', (tester) async {
    viewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [invoiceListProvider.overrideWith(_EmptyInvoices.new)],
        child: themed(const InvoicesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No invoices yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching tabs filters the statement', (tester) async {
    viewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [invoiceListProvider.overrideWith(_Invoices.new)],
        child: themed(const InvoicesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settled'));
    await tester.pumpAndSettle();

    expect(find.text('INV-2026-0020'), findsOneWidget);
    expect(find.text('INV-2026-0042'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the lease awaiting signature leads the screen', (tester) async {
    viewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [leaseListProvider.overrideWith(_Leases.new)],
        child: themed(const LeasesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review and sign'), findsOneWidget);
    expect(find.text('Awaiting signature'), findsOneWidget);
    expect(find.text('OTHER LEASES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a single lease shows no history section', (tester) async {
    viewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [leaseListProvider.overrideWith(_SingleLease.new)],
        child: themed(const LeasesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PREVIOUS LEASES'), findsNothing);
    expect(find.text('Unit SHOP-101'), findsOneWidget);
    expect(find.text('TERM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the lease detail states the term and the money', (tester) async {
    viewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaseDetailProvider('lse_1').overrideWith((ref) async => _lease),
        ],
        child: themed(const LeaseDetailScreen(leaseId: 'lse_1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rent and deposit'), findsOneWidget);
    expect(find.text('TERM'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Activation checklist'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('1 of 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
