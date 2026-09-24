import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:estora/core/theme/app_theme.dart';
import 'package:estora/core/error/result.dart';
import 'package:estora/modules/support/application/support_controller.dart';
import 'package:estora/modules/support/application/support_models.dart';
import 'package:estora/modules/support/presentation/support_tickets_screen.dart';
import 'package:estora/modules/support/presentation/ticket_detail_screen.dart';
import 'package:estora/modules/utilities/application/utility_controller.dart';
import 'package:estora/modules/utilities/presentation/utilities_screen.dart';
import 'package:estora/modules/utilities/presentation/utility_detail_screen.dart';

import 'support/mock/mock_server.dart';
import 'support/repository_overrides.dart';

/// Utilities and support at a small phone and an accessibility text size, and
/// the state each owns — a reading that is entered, and a ticket that is
/// raised, answered and closed.
///
/// Utilities has no API behind it; support runs on the mock server's copy of
/// the `Tickets` routes. The wire shape itself is in `ticket_api_test.dart`.
void main() {
  late MockServer server;

  setUp(() => server = MockServer());

  /// A ticket raised against the demo tenant's own unit.
  SupportTicket raise(String comment) => server.raiseTicket(
    TicketDraft(
      category: SupportCategory.maintenance,
      comment: comment,
      propertyId: 'prop_sarit',
      propertyName: 'Sarit Centre',
      unitId: 'unit_g12',
    ),
  );

  List<Override> overrides() => [
    ...mockRepositoryOverrides,
    mockServerProvider.overrideWithValue(server),
  ];

  /// Past the mock's simulated latency, then settled.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  Widget host(Widget screen, {bool dark = false}) => ProviderScope(
    overrides: overrides(),
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
        raise('The mixer tap at the rear wash area drips steadily overnight.');
        server.answerTicket(
          raise('Three corridor lights are out near the service lift.').id,
          'The fittings were replaced on Thursday.',
          status: TicketStatus.resolved,
        );
        tester.view.physicalSize = const Size(320, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(host(screen, dark: dark));
        await settle(tester);
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

  testWidgets("the desk's answer shows, and closing ends the ticket", (
    tester,
  ) async {
    final ticket = raise('The mixer tap drips steadily overnight.');
    server.answerTicket(ticket.id, 'A plumber is booked for tomorrow at 8.');

    await tester.pumpWidget(host(TicketDetailScreen(ticketId: ticket.id)));
    await settle(tester);
    expect(
      find.text('The mixer tap drips steadily overnight.'),
      findsOneWidget,
    );
    expect(find.text('A plumber is booked for tomorrow at 8.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Close ticket'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Fixed, thank you.');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Close ticket'),
      ),
    );
    await settle(tester);

    expect(server.tickets[ticket.id]!.status, TicketStatus.closed);
    expect(server.tickets[ticket.id]!.approvalRemarks, 'Fixed, thank you.');
    expect(find.textContaining('This ticket is closed'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Close ticket'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stale id explains itself rather than breaking', (
    tester,
  ) async {
    await tester.pumpWidget(host(const TicketDetailScreen(ticketId: '0000')));
    await settle(tester);
    expect(find.byType(TicketDetailScreen), findsOneWidget);
    expect(find.textContaining('TKT-0000'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('a raised ticket is read back from the server, newest first', () async {
    raise('An older ticket about the shutter motor.');
    final container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);

    final before = await container.read(supportTicketsProvider.future);
    final result = await container
        .read(supportTicketsProvider.notifier)
        .raise(
          const TicketDraft(
            category: SupportCategory.utilities,
            comment: 'Corridor light out since Tuesday.',
            propertyId: 'prop_sarit',
            propertyName: 'Sarit Centre',
            unitId: 'unit_g12',
          ),
        );

    expect(result, isA<Ok<void>>());
    final after = container.read(supportTicketsProvider).requireValue;
    expect(after.length, before.length + 1);
    expect(after.first.comment, 'Corridor light out since Tuesday.');
    expect(after.first.status, TicketStatus.open);
    expect(after.first.category, SupportCategory.utilities);
  });

  test('an edit replaces the comment and keeps the unit', () async {
    final ticket = raise('The shutter sticks halfway.');
    final container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    await container.read(supportTicketsProvider.future);

    await container
        .read(supportTicketsProvider.notifier)
        .edit(
          ticket.id,
          ticket.toDraft().copyWith(comment: 'The shutter will not open.'),
        );

    final edited = container.read(supportTicketsProvider).requireValue.single;
    expect(edited.comment, 'The shutter will not open.');
    expect(edited.unitId, 'unit_g12');
    expect(edited.status, TicketStatus.open);
  });
}
