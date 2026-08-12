import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/components/countdown_timer.dart';
import 'package:mall/components/money_text.dart';
import 'package:mall/components/status_chip.dart';
import 'package:mall/core/theme/app_theme.dart';
import 'package:mall/core/utils/money.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/modules/leases/presentation/sign_agreement_screen.dart';
import 'package:mall/modules/leases/application/lease_controller.dart';
import 'package:mall/domain/repositories/repositories.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mall/services/providers.dart';

/// Widget-level checks for the rules that are enforced in the UI rather than
/// on the server: the signing gate, and how figures and statuses are rendered.
void main() {
  // `Override` is not exported from flutter_riverpod 3, so overrides are passed
  // as a list literal at each call site and inferred there rather than being
  // threaded through a typed helper parameter.
  Widget app(Widget child) =>
      MaterialApp(theme: AppTheme.light, home: child);

  Widget wrap(Widget child) => ProviderScope(child: app(child));

  group('MoneyText', () {
    testWidgets('renders the amount as supplied, with its currency', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Scaffold(body: MoneyText(Money.fromMajor(150000, 'KES'))),
        ),
      );

      expect(find.text('KES 150,000'), findsOneWidget);
    });

    testWidgets('bare drops the currency for line items', (tester) async {
      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: MoneyText(Money.fromMajor(150000, 'KES'), bare: true),
          ),
        ),
      );

      expect(find.text('150,000'), findsOneWidget);
    });
  });

  group('StatusChip', () {
    testWidgets('shows the human label rather than the wire value', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: StatusChip(
              label: BookingStatus.pendingPayment.label,
              tone: BookingStatus.pendingPayment.tone,
            ),
          ),
        ),
      );

      expect(find.text('Awaiting payment'), findsOneWidget);
      expect(find.text('PENDING_PAYMENT'), findsNothing);
    });
  });

  group('CountdownTimer', () {
    testWidgets('counts down and fires onExpired once at zero', (tester) async {
      var expiredCalls = 0;
      // Driven rather than waited on: `tester.pump` advances timers but not the
      // wall clock, so the widget's clock is injected and moved by hand.
      var now = DateTime(2026, 9, 1, 12);
      final expiresAt = now.add(const Duration(seconds: 30));

      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: CountdownTimer(
              expiresAt: expiresAt,
              clock: () => now,
              tick: const Duration(milliseconds: 100),
              onExpired: () => expiredCalls++,
              builder: (context, remaining) => Text('${remaining.inSeconds}'),
            ),
          ),
        ),
      );

      expect(find.text('30'), findsOneWidget);
      expect(expiredCalls, 0);

      now = now.add(const Duration(seconds: 10));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('20'), findsOneWidget);
      expect(expiredCalls, 0);

      // Past the expiry.
      now = now.add(const Duration(seconds: 25));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('0'), findsOneWidget);
      // Section 23: reaching zero notifies so the screen can re-read the
      // server's verdict. It must fire once, not on every subsequent tick.
      expect(expiredCalls, 1);

      await tester.pump(const Duration(milliseconds: 500));
      expect(expiredCalls, 1);
    });

    testWidgets('an already-expired time reports zero immediately', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: CountdownTimer(
              expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
              builder: (context, remaining) => Text('${remaining.inSeconds}'),
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
    });
  });

  group('SignAgreementScreen gate (section 29)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('the sign button is disabled until the agreement is read', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            leaseAgreementProvider('lease-1').overrideWith(
              (ref) async => LeaseAgreement(
                leaseId: 'lease-1',
                documentHash: 'sha256:test',
                version: 1,
                generatedAt: DateTime(2026, 9, 1),
                body: 'Short agreement text.',
              ),
            ),
          ],
          child: app(const SignAgreementScreen(leaseId: 'lease-1')),
        ),
      );
      await tester.pumpAndSettle();

      final signButton = find.widgetWithText(FilledButton, 'Sign agreement');
      expect(signButton, findsOneWidget);

      // Not scrolled, nothing drawn, box unticked: signing must not be
      // possible. A signature captured from someone who was never shown the
      // text is what the gate exists to prevent.
      final button = tester.widget<FilledButton>(signButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('the confirmation checkbox is disabled before reading', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            leaseAgreementProvider('lease-1').overrideWith(
              (ref) async => LeaseAgreement(
                leaseId: 'lease-1',
                documentHash: 'sha256:test',
                version: 1,
                generatedAt: DateTime(2026, 9, 1),
                body: 'A' * 4000,
              ),
            ),
          ],
          child: app(const SignAgreementScreen(leaseId: 'lease-1')),
        ),
      );
      await tester.pumpAndSettle();

      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.onChanged, isNull);
    });
  });
}
