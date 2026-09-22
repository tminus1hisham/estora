import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/theme/app_theme.dart';
import 'package:mall/modules/support/application/support_controller.dart';
import 'package:mall/modules/support/application/support_models.dart';
import 'package:mall/modules/support/presentation/support_tickets_screen.dart';
import 'package:mall/modules/support/presentation/ticket_detail_screen.dart';
import 'package:mall/modules/utilities/application/utility_controller.dart';
import 'package:mall/modules/utilities/presentation/utilities_screen.dart';
import 'package:mall/modules/utilities/presentation/utility_detail_screen.dart';

/// The two screens that stand on mock data.
///
/// Neither has an API behind it yet, so there is no contract test to lean on;
/// what is worth pinning instead is that they survive a small phone at an
/// accessibility text size, and that the one piece of state each of them does
/// own behaves — a reading that is entered, and a ticket that is replied to.
void main() {
  Widget host(Widget screen, {bool dark = false}) => ProviderScope(
    child: MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      builder: (context, child) => MediaQuery(
        // Animations off: these screens reveal their cards on a stagger, and
        // `pumpAndSettle` would otherwise wait on a timeline that is not what
        // the test is about.
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.6),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: screen,
    ),
  );

  for (final (name, screen) in <(String, Widget)>[
    ('utilities', const UtilitiesScreen()),
    ('a meter', const UtilityDetailScreen(kind: UtilityKind.electricity)),
    ('support tickets', const SupportTicketsScreen()),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('$name fits a 320px phone at large text, dark: $dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(host(screen, dark: dark));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -1400),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  // A plain test, not a widget one: `refresh` waits on a real delay, and a
  // widget test's fake clock only advances when something pumps it.
  test(
    'a submitted reading replaces the month and survives a refresh',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final before = container.read(utilityAccountProvider(UtilityKind.water));
      final controller = container.read(utilityAccountsProvider.notifier);
      controller.submitReading(UtilityKind.water, before.latestReading + 12);

      final after = container.read(utilityAccountProvider(UtilityKind.water));
      expect(after.latestReading, before.latestReading + 12);

      // Pull-to-refresh has nothing to fetch, so it must not quietly throw the
      // tenant's own figure away.
      await controller.refresh();
      expect(
        container.read(utilityAccountProvider(UtilityKind.water)).latestReading,
        before.latestReading + 12,
      );
    },
  );

  test('a reading below the last one is refused', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = container.read(utilityAccountProvider(UtilityKind.water));
    container
        .read(utilityAccountsProvider.notifier)
        .submitReading(UtilityKind.water, before.previousReading - 1);
    expect(
      container.read(utilityAccountProvider(UtilityKind.water)).latestReading,
      before.latestReading,
    );
  });

  testWidgets('a reply joins the thread and opens on the ticket', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ticket = container
        .read(supportTicketsProvider)
        .firstWhere((candidate) => candidate.status.isLive);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: TicketDetailScreen(reference: ticket.reference),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(ticket.subject), findsWidgets);

    container
        .read(supportTicketsProvider.notifier)
        .reply(ticket.reference, 'Any word on this?');
    await tester.pumpAndSettle();

    expect(find.text('Any word on this?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stale reference explains itself rather than breaking', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const TicketDetailScreen(reference: 'TKT-0000')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TicketDetailScreen), findsOneWidget);
    expect(find.textContaining('TKT-0000'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test(
    'a raised ticket is filed open, newest first, with its own reference',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final before = container.read(supportTicketsProvider);
      final raised = container
          .read(supportTicketsProvider.notifier)
          .raise(
            subject: 'Corridor light out',
            description: 'Off since Tuesday.',
            category: SupportCategory.maintenance,
            priority: TicketPriority.normal,
          );

      final after = container.read(supportTicketsProvider);
      expect(after.length, before.length + 1);
      expect(after.first.reference, raised.reference);
      expect(after.first.status, TicketStatus.open);
      expect(before.map((t) => t.reference), isNot(contains(raised.reference)));
      // The description opens the thread, so the detail screen reads in order.
      expect(after.first.thread.single.body, 'Off since Tuesday.');
    },
  );
}
