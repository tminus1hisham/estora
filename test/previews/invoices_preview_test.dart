import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/components/glass_material.dart';
import 'package:mall/core/theme/app_theme.dart';
import 'package:mall/core/utils/money.dart';
import 'package:mall/domain/entities/billing.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/modules/home/presentation/widgets/recent_invoices.dart';
import 'package:mall/modules/invoices/application/invoice_controller.dart';
import 'package:mall/modules/invoices/presentation/invoice_detail_screen.dart';
import 'package:mall/modules/invoices/presentation/invoices_screen.dart';
import 'package:mall/modules/invoices/presentation/widgets/invoice_card.dart';
import 'package:mall/modules/payments/application/payment_controller.dart';

import '../support/preview_capture.dart';

/// Every state a statement card can be in, dated against today so the
/// "due in 3 days" warning and the overdue wash are what a tenant would see.
final _today = DateTime.now();
DateTime _day(int offset) =>
    DateTime(_today.year, _today.month, _today.day + offset);

/// A tenant leasing in two malls, so the property tag on each card has
/// something to tell apart.
typedef _Shop = ({
  String propertyId,
  String unitId,
  String property,
  String unit,
});

const _Shop _sarit = (
  propertyId: 'prp_sarit',
  unitId: 'unt_shop101',
  property: 'Sarit Mall',
  unit: 'SHOP-101',
);

const _Shop _westgate = (
  propertyId: 'prp_westgate',
  unitId: 'unt_b12',
  property: 'Westgate Mall',
  unit: 'B-12',
);

Invoice _invoice({
  required String id,
  required String number,
  required InvoiceStatus status,
  required DateTime issued,
  required DateTime due,
  int total = 15000000,
  int paid = 0,
  bool deferred = false,
  InvoiceLineType line = InvoiceLineType.rent,
  _Shop shop = _sarit,
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
    propertyId: shop.propertyId,
    unitId: shop.unitId,
    propertyName: shop.property,
    unitNumber: shop.unit,
    isDeferred: deferred,
    billingPeriodStart: DateTime(issued.year, issued.month),
    billingPeriodEnd: DateTime(issued.year, issued.month + 1, 0),
    lines: [
      InvoiceLine(
        id: '$id-1',
        invoiceId: id,
        description: line.label,
        quantity: 1,
        unitPrice: Money(total, 'KES'),
        amount: Money(total, 'KES'),
        lineType: line,
      ),
    ],
  );
}

final _invoices = <Invoice>[
  _invoice(
    id: 'due_soon',
    number: 'INV-2026-0051',
    status: InvoiceStatus.issued,
    issued: _day(-4),
    due: _day(3),
  ),
  _invoice(
    id: 'open',
    number: 'INV-2026-0052',
    status: InvoiceStatus.issued,
    issued: _day(-3),
    due: _day(24),
    total: 1850000,
    line: InvoiceLineType.serviceCharge,
    shop: _westgate,
  ),
  _invoice(
    id: 'partial',
    number: 'INV-2026-0044',
    status: InvoiceStatus.partiallyPaid,
    issued: _day(-34),
    due: _day(12),
    paid: 6000000,
    shop: _westgate,
  ),
  _invoice(
    id: 'overdue',
    number: 'INV-2026-0031',
    status: InvoiceStatus.overdue,
    issued: _day(-64),
    due: _day(-40),
  ),
  _invoice(
    id: 'deferred',
    number: 'INV-2026-0029',
    status: InvoiceStatus.overdue,
    issued: _day(-66),
    due: _day(-44),
    total: 420000,
    deferred: true,
    line: InvoiceLineType.electricity,
    shop: _westgate,
  ),
  _invoice(
    id: 'paid',
    number: 'INV-2026-0020',
    status: InvoiceStatus.paid,
    issued: _day(-95),
    due: _day(-88),
    paid: 15000000,
  ),
];

class _Invoices extends InvoiceListController {
  @override
  Future<List<Invoice>> build() async => _invoices;
}

class _EmptyInvoices extends InvoiceListController {
  @override
  Future<List<Invoice>> build() async => const <Invoice>[];
}

class _SettledOnly extends InvoiceListController {
  @override
  Future<List<Invoice>> build() async =>
      _invoices.where((i) => i.status == InvoiceStatus.paid).toList();
}

class _Payments extends PaymentHistoryController {
  @override
  Future<List<Payment>> build() async => [
    Payment(
      id: 'pay_1',
      paymentReference: 'SJK4H2L9QX',
      tenantId: 'tnt_1',
      amount: const Money(9000000, 'KES'),
      currency: 'KES',
      paymentMethod: PaymentMethod.mpesa,
      status: PaymentStatus.success,
      createdAt: _day(-6),
      paidAt: _day(-6),
      invoiceNumber: 'INV-2026-0044',
      receiptId: 'rct_1',
    ),
    Payment(
      id: 'pay_2',
      paymentReference: 'SJK4H2L9QA',
      tenantId: 'tnt_1',
      amount: const Money(15000000, 'KES'),
      currency: 'KES',
      paymentMethod: PaymentMethod.mpesa,
      status: PaymentStatus.failed,
      createdAt: _day(-38),
      invoiceNumber: 'INV-2026-0031',
      failureReason: 'The request was cancelled on the phone.',
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
    bool empty = false,
  }) {
    return ProviderScope(
      overrides: [
        invoiceListProvider.overrideWith(
          empty ? _EmptyInvoices.new : _Invoices.new,
        ),
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
        home: RepaintBoundary(
          key: key,
          child: InvoicesScreen(pane: pane),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    // The staggered entry runs on timers; let every card arrive.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('statement ($mode)', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(screen(dark: dark));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await capturePreview(tester, key, 'invoices-$mode');
    });

    testWidgets('statement scrolled ($mode)', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(screen(dark: dark));
      await settle(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await capturePreview(tester, key, 'invoices-scrolled-$mode');
    });

    testWidgets('outstanding filter ($mode)', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(screen(dark: dark));
      await settle(tester);
      await tester.tap(find.text('Outstanding'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await capturePreview(tester, key, 'invoices-outstanding-$mode');
    });

    testWidgets('transactions pane ($mode)', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(
        screen(dark: dark, pane: InvoicesPane.transactions),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      await capturePreview(tester, key, 'transactions-$mode');
    });

    testWidgets('home preview ($mode)', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: RepaintBoundary(
              key: key,
              child: Scaffold(
                body: GlassScene(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 72, 20, 24),
                    children: [
                      const RecentInvoices(invoices: []),
                      const SizedBox(height: 24),
                      RecentInvoices(invoices: _invoices.take(2).toList()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      await capturePreview(tester, key, 'recent-invoices-$mode');
    });
  }

  testWidgets('statement at text scale 1.6', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(screen(dark: false, textScale: 1.6));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await capturePreview(tester, key, 'invoices-scale16-light');
  });

  testWidgets('statement at text scale 2.0 (dark)', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(screen(dark: true, textScale: 2));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await capturePreview(tester, key, 'invoices-scale20-dark');
  });

  // The compact card's height, measured rather than eyeballed: printed per
  // invoice so a change that grows the card shows up as a number.
  for (final width in const [390.0, 360.0]) {
    testWidgets('card heights at ${width.toInt()}', (tester) async {
      usePhoneViewport(tester, size: Size(width, 1400));
      await tester.pumpWidget(screen(dark: false));
      await settle(tester);
      for (final element in find.byType(InvoiceCard).evaluate()) {
        final card = element.widget as InvoiceCard;
        final size = (element.renderObject! as RenderBox).size;
        debugPrint(
          'card ${width.toInt()} ${card.invoice.id}: '
          '${size.height.toStringAsFixed(1)}',
        );
      }
      expect(tester.takeException(), isNull);
      await capturePreview(tester, key, 'invoices-${width.toInt()}-tall-light');
    });
  }

  testWidgets('nothing outstanding', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [invoiceListProvider.overrideWith(_SettledOnly.new)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const RepaintBoundary(key: key, child: InvoicesScreen()),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Outstanding'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await capturePreview(tester, key, 'invoices-nothing-outstanding-light');
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    for (final id in ['overdue', 'partial']) {
      testWidgets('detail $id ($mode)', (tester) async {
        usePhoneViewport(tester);
        final invoice = _invoices.firstWhere((i) => i.id == id);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              invoiceDetailProvider(id).overrideWith((ref) async => invoice),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? AppTheme.dark : AppTheme.light,
              home: RepaintBoundary(
                key: key,
                child: InvoiceDetailScreen(invoiceId: id),
              ),
            ),
          ),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        await capturePreview(tester, key, 'detail-$id-$mode');
      });
    }
  }

  testWidgets('empty statement', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(screen(dark: false, empty: true));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await capturePreview(tester, key, 'invoices-empty-light');
  });
}
