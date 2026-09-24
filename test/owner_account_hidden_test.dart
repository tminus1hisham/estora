import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estora/modules/owner/presentation/owner_account_screen.dart';
import 'package:estora/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/repository_overrides.dart';

void main() {
  testWidgets('owner account page does not list Administration', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...mockRepositoryOverrides,
        ],
        child: const MaterialApp(home: OwnerAccountScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ADMINISTRATION'), findsNothing);
    expect(find.text('People'), findsNothing);
    expect(find.text('Roles'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Sign out'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('ADMINISTRATION'), findsNothing);
    expect(find.text('People'), findsNothing);
    expect(find.text('Roles'), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
