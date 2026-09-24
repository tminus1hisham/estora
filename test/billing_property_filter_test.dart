import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estora/core/theme/app_theme.dart';
import 'package:estora/core/utils/money.dart';
import 'package:estora/domain/entities/billing.dart';
import 'package:estora/domain/enums/domain_enums.dart';
import 'package:estora/modules/invoices/application/billing_property_filter.dart';
import 'package:estora/modules/invoices/application/invoice_controller.dart';
import 'package:estora/modules/invoices/presentation/invoices_screen.dart';
import 'package:estora/modules/payments/application/payment_controller.dart';

Invoice _invoice(
  String id, {
  required InvoiceStatus status,
  String? propertyId,
  String? propertyName,
  int month = 8,
}) {
  final paid = status == InvoiceStatus.paid ? 1000000 : 0;
  return Invoice(
    id: id,
    invoiceNumber: 'INV-$id',
    tenantId: 'tnt_1',
    status: status,
    invoiceDate: DateTime(2026, month),
    dueDate: DateTime(2026, month, 5),
    subtotal: const Money(1000000, 'KES'),
    tax: const Money(0, 'KES'),
    discount: const Money(0, 'KES'),
    total: const Money(1000000, 'KES'),
    amountPaid: Money(paid, 'KES'),
    amountDue: Money(1000000 - paid, 'KES'),
    currency: 'KES',
    propertyId: propertyId,
    propertyName: propertyName,
    lines: const [],
  );
}

Payment _payment(String id, {String? invoiceId, String? propertyId}) {
  return Payment(
    id: id,
    paymentReference: 'REF-$id',
    tenantId: 'tnt_1',
    invoiceId: invoiceId,
    propertyId: propertyId,
    invoiceNumber: invoiceId == null ? null : 'INV-$invoiceId',
    amount: const Money(1000000, 'KES'),
    currency: 'KES',
    paymentMethod: PaymentMethod.mpesa,
    status: PaymentStatus.success,
    createdAt: DateTime(2026, 8, 3),
    paidAt: DateTime(2026, 8, 3),
  );
}

/// Two malls: Sarit (id 1) with an open and a settled invoice, and the Hub
/// (id 2) with one open invoice.
final _twoProperties = <Invoice>[
  _invoice(
    'a1',
    status: InvoiceStatus.issued,
    propertyId: '1',
    propertyName: 'Sarit Mall',
  ),
  _invoice(
    'a2',
    status: InvoiceStatus.paid,
    propertyId: '1',
    propertyName: 'Sarit Mall',
    month: 7,
  ),
  _invoice(
    'b1',
    status: InvoiceStatus.overdue,
    propertyId: '2',
    propertyName: 'The Hub Karen',
    month: 6,
  ),
];

final _oneProperty = _twoProperties.take(2).toList();

/// The statement the next build answers with; a test swaps it to act out a
/// refresh.
List<Invoice> _statement = _twoProperties;

class _Invoices extends InvoiceListController {
  @override
  Future<List<Invoice>> build() async => _statement;
}

class _Payments extends PaymentHistoryController {
  @override
  Future<List<Payment>> build() async => [
    // Placed by the invoice it paid, having no property of its own — as the
    // live API sends them.
    _payment('p_sarit', invoiceId: 'a2'),
    // Placed by its own property id.
    _payment('p_hub', propertyId: '2'),
    // Placeable by neither: only ever under "All properties".
    _payment('p_loose'),
  ];
}

void main() {
  setUp(() => _statement = _twoProperties);

  group('state', () {
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          invoiceListProvider.overrideWith(_Invoices.new),
          paymentHistoryProvider.overrideWith(_Payments.new),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('properties are keyed by id, named by their invoices', () async {
      _statement = [
        ..._twoProperties,
        // Same name as Sarit, different property: kept apart.
        _invoice(
          'c1',
          status: InvoiceStatus.issued,
          propertyId: '9',
          propertyName: 'Sarit Mall',
        ),
        // No name on the wire: a stand-in, never a blank.
        _invoice('d1', status: InvoiceStatus.issued, propertyId: '7'),
        // No property at all: not offered, still counted under "All".
        _invoice('e1', status: InvoiceStatus.issued),
      ];
      final c = container();
      await c.read(invoiceListProvider.future);

      final properties = c.read(billingPropertiesProvider);
      expect(
        [for (final p in properties) (p.id, p.name, p.invoiceCount)],
        [
          ('7', 'Property 7', 1),
          ('1', 'Sarit Mall', 2),
          ('9', 'Sarit Mall', 1),
          ('2', 'The Hub Karen', 1),
        ],
      );
    });

    test('a property narrows invoices and payments; null widens', () async {
      final c = container();
      await c.read(invoiceListProvider.future);
      await c.read(paymentHistoryProvider.future);
      c.listen(scopedPaymentsProvider, (_, _) {});

      c.read(billingPropertyFilterProvider.notifier).select('1');
      expect(c.read(scopedInvoicesProvider).requireValue.map((i) => i.id), [
        'a1',
        'a2',
      ]);
      expect(c.read(scopedPaymentsProvider).requireValue.map((p) => p.id), [
        'p_sarit',
      ]);

      c.read(billingPropertyFilterProvider.notifier).select('2');
      expect(c.read(scopedPaymentsProvider).requireValue.map((p) => p.id), [
        'p_hub',
      ]);

      c.read(billingPropertyFilterProvider.notifier).select(null);
      expect(c.read(scopedInvoicesProvider).requireValue, hasLength(3));
      expect(c.read(scopedPaymentsProvider).requireValue, hasLength(3));
    });

    test('a property that leaves the statement drops back to all', () async {
      final c = container();
      await c.read(invoiceListProvider.future);
      c.listen(selectedBillingPropertyProvider, (_, _) {});

      c.read(billingPropertyFilterProvider.notifier).select('2');
      expect(c.read(selectedBillingPropertyProvider)?.name, 'The Hub Karen');

      // The Hub's lease ended; its invoice is gone on the next refresh.
      _statement = [
        ..._oneProperty,
        _invoice(
          'z1',
          status: InvoiceStatus.issued,
          propertyId: '3',
          propertyName: 'Two Rivers Mall',
        ),
      ];
      await c.read(invoiceListProvider.notifier).refresh();

      expect(c.read(selectedBillingPropertyProvider), isNull);
      expect(c.read(billingPropertyFilterProvider), isNull);
      expect(c.read(scopedInvoicesProvider).requireValue, hasLength(3));
    });

    test('with one property nothing is ever narrowed', () async {
      _statement = _oneProperty;
      final c = container();
      await c.read(invoiceListProvider.future);

      c.read(billingPropertyFilterProvider.notifier).select('1');
      expect(c.read(selectedBillingPropertyProvider), isNull);
    });
  });

  group('screen', () {
    Widget app() => ProviderScope(
      overrides: [
        invoiceListProvider.overrideWith(_Invoices.new),
        paymentHistoryProvider.overrideWith(_Payments.new),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const InvoicesScreen()),
    );

    void phone(WidgetTester tester, {double textScale = 1}) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pumpAndSettle();
      // The statement's staggered entry runs on timers.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    /// The pill in the app bar, by what it reads. The cards carry a property
    /// tag with the same name, so the bar is where to look.
    Finder pill(String label) =>
        find.descendant(of: find.byType(AppBar), matching: find.text(label));

    Future<void> choose(
      WidgetTester tester,
      String current,
      String next,
    ) async {
      await tester.tap(pill(current));
      await settle(tester);
      // The menu's row, not the card tag or the pill behind it.
      await tester.tap(
        find.descendant(
          of: find.bySemanticsLabel(RegExp('^${RegExp.escape(next)}, ')),
          matching: find.text(next),
        ),
      );
      await settle(tester);
    }

    testWidgets('one property: no pill, the tab as it was', (tester) async {
      _statement = _oneProperty;
      phone(tester);
      await tester.pumpWidget(app());
      await settle(tester);

      expect(find.text('All properties'), findsNothing);
      expect(find.text('Invoices'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('two properties: the pill filters both panes', (tester) async {
      final semantics = tester.ensureSemantics();
      phone(tester);
      await tester.pumpWidget(app());
      await settle(tester);

      expect(find.bySemanticsLabel('Property: All properties'), findsOneWidget);
      expect(find.bySemanticsLabel('All, 3'), findsOneWidget);
      expect(find.bySemanticsLabel('Outstanding, 2'), findsOneWidget);
      expect(find.text('INV-b1'), findsOneWidget);

      // The menu offers every property with its count, the current one
      // checked.
      await tester.tap(find.text('All properties'));
      await settle(tester);
      expect(find.bySemanticsLabel('All properties, 3 invoices'), findsOne);
      expect(find.bySemanticsLabel('Sarit Mall, 2 invoices'), findsOne);
      expect(find.bySemanticsLabel('The Hub Karen, 1 invoice'), findsOne);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.tapAt(const Offset(380, 800));
      await settle(tester);

      await choose(tester, 'All properties', 'Sarit Mall');
      expect(pill('Sarit Mall'), findsOneWidget);
      expect(find.text('INV-a1'), findsOneWidget);
      expect(find.text('INV-b1'), findsNothing);
      // The segmented control counts within the property.
      expect(find.bySemanticsLabel('All, 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Outstanding, 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Settled, 1'), findsOneWidget);

      // The transactions follow the same choice.
      await tester.tap(find.text('Transactions'));
      await settle(tester);
      expect(find.text('INV-a2'), findsOneWidget);
      expect(find.text('REF-p_hub'), findsNothing);
      expect(find.text('REF-p_loose'), findsNothing);

      // "All properties" puts everything back.
      await choose(tester, 'Sarit Mall', 'All properties');
      expect(find.text('REF-p_hub'), findsOneWidget);
      expect(find.text('REF-p_loose'), findsOneWidget);
      await tester.tap(find.text('Invoices'));
      await settle(tester);
      expect(find.bySemanticsLabel('All, 3'), findsOneWidget);
      expect(find.text('INV-b1'), findsOneWidget);

      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('an emptied filter speaks for the property', (tester) async {
      phone(tester);
      await tester.pumpWidget(app());
      await settle(tester);

      await choose(tester, 'All properties', 'The Hub Karen');
      await tester.tap(find.text('Settled'));
      await settle(tester);
      expect(find.text('Nothing settled yet'), findsOneWidget);
      expect(
        find.text('Invoices you have paid at The Hub Karen will be kept here.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the pill and menu hold at text scale 2.0', (tester) async {
      phone(tester, textScale: 2);
      await tester.pumpWidget(app());
      await settle(tester);

      await choose(tester, 'All properties', 'The Hub Karen');
      expect(find.text('INV-b1'), findsOneWidget);
      await tester.tap(pill('The Hub Karen'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
