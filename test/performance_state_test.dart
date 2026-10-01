import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:estora/components/record_group.dart';
import 'package:estora/components/app_media.dart';
import 'package:estora/domain/entities/billing.dart';
import 'package:estora/modules/payments/application/payment_controller.dart';
import 'package:estora/core/error/failure.dart';
import 'package:estora/core/error/result.dart';
import 'package:estora/core/theme/app_theme.dart';
import 'package:estora/core/utils/money.dart';
import 'package:estora/domain/entities/owner.dart';
import 'package:estora/domain/entities/property.dart';
import 'package:estora/domain/entities/treasury.dart';
import 'package:estora/domain/enums/domain_enums.dart';
import 'package:estora/domain/repositories/repositories.dart';
import 'package:estora/modules/home/presentation/available_home.dart';
import 'package:estora/modules/invoices/application/invoice_controller.dart';
import 'package:estora/modules/owner/application/owner_controller.dart';
import 'package:estora/modules/owner/presentation/owner_live_dashboard.dart';
import 'package:estora/modules/properties/application/property_controller.dart';
import 'package:estora/modules/treasury/application/treasury_controller.dart';
import 'package:estora/modules/treasury/presentation/bank_payments_screen.dart';
import 'package:estora/services/providers.dart';

class _Owner extends Mock implements OwnerRepository {}

class _Properties extends Mock implements PropertyRepository {}

class _Invoices extends Mock implements InvoiceRepository {}

class _Treasury extends Mock implements TreasuryRepository {}
class _Payments extends Mock implements PaymentRepository {}

Property _property(String id) => Property(
  id: id,
  name: id,
  code: id,
  propertyType: PropertyType.estora,
  status: PropertyStatus.active,
  city: 'Nairobi',
  country: 'Kenya',
);
OwnerReport _report([String? id]) =>
    OwnerReport(propertyId: id, received: [], invoices: []);

void main() {
  testWidgets('polling ends when its last consumer leaves', (tester) async {
    final repository = _Payments();
    when(() => repository.getPayment('1')).thenAnswer((_) async => Ok(Payment(
      id: '1', paymentReference: 'P1', tenantId: '1',
      amount: Money.fromMajor(100, 'KES'), currency: 'KES',
      paymentMethod: PaymentMethod.mpesa, status: PaymentStatus.pending,
      createdAt: DateTime(2026),
    )));
    final scope = ProviderContainer(overrides: [paymentRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(scope.dispose);
    final listener = scope.listen(paymentStatusProvider('1'), (_, _) {});
    await tester.pump();
    verify(() => repository.getPayment('1')).called(1);
    listener.close();
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    verifyNever(() => repository.getPayment('1'));
    expect(scope.exists(paymentStatusProvider('1')), isFalse);
  });

  testWidgets('image decode width is finite, display-sized and preserves ratio', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Center(child: SizedBox(width: 120,
      child: AppMedia(source: 'assets/images/property_placeholder.webp')))));
    await tester.pumpAndSettle();
    final provider = tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    expect(provider.width, greaterThan(0));
    expect(provider.width, lessThan(1536));
    expect(provider.height, isNull);
    expect(tester.takeException(), isNull);
  });

  test(
    'Home and Revenue share reads, refresh, failures and mutation invalidation',
    () async {
      final owner = _Owner();
      final invoices = _Invoices();
      final treasury = _Treasury();
      var calls = 0;
      var fail = false;
      when(
        () => owner.getReport(propertyId: any(named: 'propertyId')),
      ).thenAnswer((invocation) async {
        calls++;
        return fail
            ? const Err(NetworkFailure())
            : Ok(_report(invocation.namedArguments[#propertyId] as String?));
      });
      when(
        () => invoices.settleInvoice('1'),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => treasury.setMpesaAccountNumber(
          transactionId: '1',
          accountNumber: 'A',
        ),
      ).thenAnswer((_) async => const Ok(null));
      final scope = ProviderContainer(
        overrides: [
          ownerRepositoryProvider.overrideWithValue(owner),
          invoiceRepositoryProvider.overrideWithValue(invoices),
          treasuryRepositoryProvider.overrideWithValue(treasury),
        ],
      );
      addTearDown(scope.dispose);
      final home = await scope.read(ownerDashboardReportProvider.future);
      expect(await scope.read(selectedOwnerReportProvider.future), same(home));
      expect(calls, 1);
      scope.read(reportPropertyProvider.notifier).select('2');
      expect(
        (await scope.read(selectedOwnerReportProvider.future)).propertyId,
        '2',
      );
      expect(await scope.read(ownerDashboardReportProvider.future), same(home));
      scope.read(reportPropertyProvider.notifier).select(null);
      expect(await scope.read(selectedOwnerReportProvider.future), same(home));
      expect(calls, 2);
      await scope.read(invoiceActionsProvider).settleInvoice('1');
      await scope.read(ownerDashboardReportProvider.future);
      expect(calls, 3);
      await scope
          .read(treasuryActionsProvider)
          .setAccountNumber(transactionId: '1', accountNumber: 'A');
      await scope.read(ownerDashboardReportProvider.future);
      expect(calls, 4);
      fail = true;
      await expectLater(
        scope.refresh(ownerDashboardReportProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
      fail = false;
      await scope.refresh(ownerDashboardReportProvider.future);
      expect(calls, 6);
    },
  );

  test(
    'shared property refresh cannot publish after session invalidation',
    () async {
      final repository = _Properties();
      final pending = Completer<Result<Page<Property>>>();
      var calls = 0;
      when(() => repository.listProperties()).thenAnswer((_) async {
        calls++;
        if (calls == 2) return pending.future;
        return Ok(Page.single([_property(calls == 1 ? 'old' : 'new')]));
      });
      final scope = ProviderContainer(
        overrides: [propertyRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(scope.dispose);
      expect(
        await scope.read(homePropertiesProvider.future),
        same(await scope.read(propertyListProvider.future)),
      );
      expect(calls, 1);
      final refresh = scope.read(propertyListProvider.notifier).refresh();
      scope.invalidate(propertyListProvider);
      expect(
        (await scope.read(homePropertiesProvider.future)).single.id,
        'new',
      );
      pending.complete(Ok(Page.single([_property('stale')])));
      await refresh;
      expect(scope.read(propertyListProvider).requireValue.single.id, 'new');
    },
  );

  test(
    'property details overlap reads and fetch floors only for missing counts',
    () async {
      final repository = _Properties();
      final property = Completer<Result<Property>>();
      when(
        () => repository.getProperty('1'),
      ).thenAnswer((_) => property.future);
      when(() => repository.listBuildings('1')).thenAnswer(
        (_) async => const Ok([
          Building(
            id: 'known',
            propertyId: '1',
            name: 'Known',
            code: '',
            numberOfFloors: 3,
          ),
          Building(
            id: 'zero',
            propertyId: '1',
            name: 'Zero',
            code: '',
            numberOfFloors: 0,
          ),
          Building(id: 'missing', propertyId: '1', name: 'Missing', code: ''),
        ]),
      );
      when(
        () => repository.listFloors('missing'),
      ).thenAnswer((_) async => Ok(Floor.fromCount('missing', 2)));
      final scope = ProviderContainer(
        overrides: [propertyRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(scope.dispose);
      final subscription = scope.listen(propertyDetailProvider('1'), (_, _) {});
      final pending = scope.read(propertyDetailProvider('1').future);
      await Future<void>.delayed(Duration.zero);
      verify(() => repository.listBuildings('1')).called(1);
      property.complete(Ok(_property('1')));
      final detail = await pending;
      expect(detail.floorsByBuilding['known']!.map((f) => f.id), [
        'known:0',
        'known:1',
        'known:2',
      ]);
      expect(detail.floorsByBuilding['known']!.first.name, 'Ground floor');
      expect(detail.floorsByBuilding['zero'], isEmpty);
      expect(detail.floorsByBuilding['missing'], hasLength(2));
      verifyNever(() => repository.listFloors('known'));
      verifyNever(() => repository.listFloors('zero'));
      subscription.close();
      await scope.pump();
      expect(scope.exists(propertyDetailProvider('1')), isFalse);
    },
  );

  for (final dark in [false, true]) {
    testWidgets('1,000 bank payments stay lazy, large text, dark=$dark', (
      tester,
    ) async {
      final repository = _Treasury();
      when(() => repository.listBankPayments()).thenAnswer(
        (_) async => Ok(
          List.generate(
            1000,
            (i) => BankPayment(
              id: '$i',
              amount: Money.fromMajor(100, 'KES'),
              paidAt: DateTime(2026),
              paymentMethod: 'Transfer',
              paymentReference: 'REFERENCE $i',
              isProcessed: i >= 500,
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [treasuryRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: const BankPaymentsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AWAITING REVIEW'), findsOneWidget);
      expect(find.byType(RecordRow).evaluate().length, lessThan(30));
      expect(find.text('REFERENCE 999'), findsNothing);
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, -1000),
        2000,
      );
      await tester.pumpAndSettle();
      expect(find.byType(RecordRow).evaluate().length, lessThan(30));
      expect(tester.takeException(), isNull);
    });
  }
}
