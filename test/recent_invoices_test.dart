import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:estora/components/amount_text.dart';
import 'package:estora/core/theme/app_theme.dart';
import 'package:estora/core/utils/money.dart';
import 'package:estora/domain/entities/billing.dart';
import 'package:estora/domain/enums/domain_enums.dart';
import 'package:estora/modules/home/presentation/widgets/recent_invoices.dart';
import 'package:estora/modules/invoices/application/invoice_controller.dart';
import 'package:estora/modules/invoices/presentation/widgets/invoice_sheet.dart';

Invoice _invoice(int day, InvoiceStatus status) => Invoice(
  id: '$day',
  invoiceNumber: 'INV-$day',
  tenantId: 'tenant',
  status: status,
  invoiceDate: DateTime(2026, 9, day),
  dueDate: DateTime(2026, 10, day),
  subtotal: const Money(100000, 'KES'),
  tax: const Money(0, 'KES'),
  discount: const Money(0, 'KES'),
  total: const Money(100000, 'KES'),
  amountPaid: Money(status == InvoiceStatus.paid ? 100000 : 25000, 'KES'),
  amountDue: Money(status == InvoiceStatus.paid ? 0 : 75000, 'KES'),
  currency: 'KES',
  lines: const [],
);

void main() {
  testWidgets('with nothing owed, recent invoices show the last two paid', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: RecentInvoices(
                invoices: [
                  for (var day = 1; day <= 6; day++)
                    _invoice(day, InvoiceStatus.paid),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invoiceDetailProvider(
            '6',
          ).overrideWith((ref) async => _invoice(6, InvoiceStatus.paid)),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final numbers = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where((text) => text?.startsWith('INV-') ?? false);
    expect(numbers, ['INV-6', 'INV-5']);
    expect(find.text('Pay now'), findsNothing);
    expect(
      tester
          .widget<AmountText>(find.byType(AmountText).first)
          .amount
          .minorUnits,
      100000,
    );
    await tester.tap(find.text('INV-6'));
    await tester.pumpAndSettle();
    expect(find.byType(InvoiceSheet), findsOneWidget);
  });

  testWidgets('recent invoices show every unpaid invoice and no paid ones', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecentInvoices(
                invoices: [
                  for (var day = 1; day <= 7; day++)
                    _invoice(
                      day,
                      day.isEven ? InvoiceStatus.paid : InvoiceStatus.overdue,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final numbers = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where((text) => text?.startsWith('INV-') ?? false);
    expect(numbers, ['INV-7', 'INV-5', 'INV-3', 'INV-1']);
  });

  testWidgets('partially paid invoice uses balance and fits large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: RecentInvoices(
                  invoices: [_invoice(1, InvoiceStatus.partiallyPaid)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PARTIALLY PAID'), findsOneWidget);
    expect(find.text('Partially paid'), findsOneWidget);
    expect(find.text('Pay now'), findsOneWidget);
    expect(
      tester.widget<AmountText>(find.byType(AmountText)).amount.minorUnits,
      75000,
    );
    expect(tester.takeException(), isNull);
  });
}
