import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estora/core/theme/app_theme.dart';
import 'package:estora/core/utils/money.dart';
import 'package:estora/domain/entities/billing.dart';
import 'package:estora/domain/enums/domain_enums.dart';
import 'package:estora/modules/invoices/application/invoice_controller.dart';
import 'package:estora/modules/invoices/presentation/invoices_screen.dart';
import 'package:estora/modules/payments/application/payment_controller.dart';

import '../support/preview_capture.dart';

/// A tenant billed at three malls, so the property pill is drawn, with the
/// menu closed and open, on both panes.
final _today = DateTime.now();
DateTime _day(int offset) =>
    DateTime(_today.year, _today.month, _today.day + offset);

Invoice _invoice({
  required String id,
  required String number,
  required InvoiceStatus status,
  required int issued,
  required int due,
  required String propertyId,
  required String propertyName,
  int total = 15000000,
  int paid = 0,
}) {
  return Invoice(
    id: id,
    invoiceNumber: number,
    tenantId: 'tnt_1',
    status: status,
    invoiceDate: _day(issued),
    dueDate: _day(due),
    subtotal: Money(total, 'KES'),
    tax: const Money(0, 'KES'),
    discount: const Money(0, 'KES'),
    total: Money(total, 'KES'),
    amountPaid: Money(paid, 'KES'),
    amountDue: Money(total - paid, 'KES'),
    currency: 'KES',
    propertyId: propertyId,
    propertyName: propertyName,
    unitNumber: 'SHOP-101',
    lines: [
      InvoiceLine(
        id: '$id-1',
        invoiceId: id,
        description: 'Rent',
        quantity: 1,
        unitPrice: Money(total, 'KES'),
        amount: Money(total, 'KES'),
        lineType: InvoiceLineType.rent,
      ),
    ],
  );
}

final _invoices = <Invoice>[
  _invoice(
    id: 'sarit_open',
    number: 'INV-2026-0051',
    status: InvoiceStatus.issued,
    issued: -4,
    due: 3,
    propertyId: '1',
    propertyName: 'Sarit Mall',
  ),
  _invoice(
    id: 'hub_open',
    number: 'INV-2026-0052',
    status: InvoiceStatus.issued,
    issued: -3,
    due: 24,
    total: 9800000,
    propertyId: '2',
    propertyName: 'The Hub Karen',
  ),
  _invoice(
    id: 'sarit_overdue',
    number: 'INV-2026-0031',
    status: InvoiceStatus.overdue,
    issued: -64,
    due: -40,
    propertyId: '1',
    propertyName: 'Sarit Mall',
  ),
  _invoice(
    id: 'hub_paid',
    number: 'INV-2026-0033',
    status: InvoiceStatus.paid,
    issued: -60,
    due: -50,
    total: 9800000,
    paid: 9800000,
    propertyId: '2',
    propertyName: 'The Hub Karen',
  ),
  _invoice(
    id: 'rivers_paid',
    number: 'INV-2026-0020',
    status: InvoiceStatus.paid,
    issued: -95,
    due: -88,
    total: 4200000,
    paid: 4200000,
    propertyId: '3',
    propertyName: 'Two Rivers Mall',
  ),
];

class _Invoices extends InvoiceListController {
  @override
  Future<List<Invoice>> build() async => _invoices;
}

class _Payments extends PaymentHistoryController {
  @override
  Future<List<Payment>> build() async => [
    Payment(
      id: 'pay_hub',
      paymentReference: 'SJK4H2L9QX',
      tenantId: 'tnt_1',
      invoiceId: 'hub_paid',
      amount: const Money(9800000, 'KES'),
      currency: 'KES',
      paymentMethod: PaymentMethod.mpesa,
      status: PaymentStatus.success,
      createdAt: _day(-52),
      paidAt: _day(-52),
      invoiceNumber: 'INV-2026-0033',
      receiptId: 'rct_1',
    ),
    Payment(
      id: 'pay_rivers',
      paymentReference: 'SJK4H2L9QB',
      tenantId: 'tnt_1',
      invoiceId: 'rivers_paid',
      amount: const Money(4200000, 'KES'),
      currency: 'KES',
      paymentMethod: PaymentMethod.mpesa,
      status: PaymentStatus.success,
      createdAt: _day(-90),
      paidAt: _day(-90),
      invoiceNumber: 'INV-2026-0020',
      receiptId: 'rct_2',
    ),
  ];
}

void main() {
  setUpAll(loadPreviewFonts);

  const key = ValueKey('preview');

  Widget screen({
    required bool dark,
    double textScale = 1,
    InvoicesPane pane = InvoicesPane.invoices,
  }) {
    return ProviderScope(
      overrides: [
        invoiceListProvider.overrideWith(_Invoices.new),
        paymentHistoryProvider.overrideWith(_Payments.new),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AppTheme.dark : AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        // The boundary wraps the navigator, so the menu — a route above the
        // screen — is in the capture.
        home: RepaintBoundary(
          key: key,
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => InvoicesScreen(pane: pane),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  Finder pill() => find.text('All properties');

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('pill closed ($mode)', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(screen(dark: dark));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await capturePreview(tester, key, 'pill-closed-$mode');
    });

    testWidgets('menu open ($mode)', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(screen(dark: dark));
      await settle(tester);
      await tester.tap(pill());
      await settle(tester);
      expect(tester.takeException(), isNull);
      await capturePreview(tester, key, 'menu-open-$mode');
    });

    testWidgets('one property chosen ($mode)', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(screen(dark: dark));
      await settle(tester);
      await tester.tap(pill());
      await settle(tester);
      await tester.tap(find.text('Sarit Mall').last);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await capturePreview(tester, key, 'filtered-$mode');
    });

    testWidgets('transactions, one property chosen ($mode)', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(
        screen(dark: dark, pane: InvoicesPane.transactions),
      );
      await settle(tester);
      await tester.tap(pill());
      await settle(tester);
      await tester.tap(find.text('The Hub Karen').last);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await capturePreview(tester, key, 'transactions-filtered-$mode');
    });
  }

  for (final scale in [1.6, 2.0]) {
    testWidgets('menu open at text scale $scale', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(screen(dark: scale == 2.0, textScale: scale));
      await settle(tester);
      await tester.tap(pill());
      await settle(tester);
      expect(tester.takeException(), isNull);
      await capturePreview(
        tester,
        key,
        'menu-open-scale${(scale * 10).round()}',
      );
    });
  }

  for (final scale in [1.6, 2.0]) {
    testWidgets('pill closed at text scale $scale', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(screen(dark: scale == 2.0, textScale: scale));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await capturePreview(
        tester,
        key,
        'pill-closed-scale${(scale * 10).round()}',
      );
    });
  }

  for (final dark in [false, true]) {
    testWidgets('transactions, all properties (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(
        screen(dark: dark, pane: InvoicesPane.transactions),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      await capturePreview(
        tester,
        key,
        'transactions-all-${dark ? 'dark' : 'light'}',
      );
    });
  }
}
