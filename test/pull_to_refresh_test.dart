import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estora/components/app_refresh_indicator.dart';
import 'package:estora/components/state_views.dart';
import 'package:estora/core/error/failure.dart';

void main() {
  for (final empty in [false, true]) {
    testWidgets('short page refresh waits for completion (empty: $empty)', (
      tester,
    ) async {
      final completion = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppRefreshIndicator(
              onRefresh: () {
                calls++;
                return completion.future;
              },
              child: empty
                  ? const EmptyState(icon: Icons.search, title: 'No records')
                  : ListView(children: const [Text('One record')]),
            ),
          ),
        ),
      );
      await tester.drag(find.byType(Scrollable), const Offset(0, 400));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 1);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      completion.complete();
      await tester.pumpAndSettle();
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('error page supports pull to retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorView(
            failure: const NetworkFailure(),
            onRetry: () async {
              calls++;
            },
          ),
        ),
      ),
    );
    await tester.drag(find.byType(Scrollable), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed refresh ends and preserves entered form text', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppRefreshIndicator(
            onRefresh: () async {
              throw const NetworkFailure();
            },
            child: ListView(children: [TextField(controller: controller)]),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Unsaved value');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(300, 300), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(controller.text, 'Unsaved value');
    expect(find.text('Could not refresh. Try again.'), findsOneWidget);
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
