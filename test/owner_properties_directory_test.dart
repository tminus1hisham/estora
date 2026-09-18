import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/theme/app_theme.dart';
import 'package:mall/modules/owner/presentation/owner_properties_screen.dart';
import 'package:mall/modules/owner/presentation/widgets/owner_dashboard_widgets.dart';

import 'support/repository_overrides.dart';

void main() {
  testWidgets('directory search, type filters and reset work together', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: mockRepositoryOverrides,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const OwnerPropertiesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OwnerPropertyTile), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), 'ABC');
    await tester.pumpAndSettle();
    expect(find.byType(OwnerPropertyTile), findsOneWidget);
    expect(find.text('ABC Business Centre'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mall'));
    await tester.pumpAndSettle();
    expect(find.text('No matching properties'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.byType(OwnerPropertyTile), findsNWidgets(2));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mall'));
    await tester.pumpAndSettle();
    expect(find.byType(OwnerPropertyTile), findsOneWidget);
    expect(find.text('Sarit Mall'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
