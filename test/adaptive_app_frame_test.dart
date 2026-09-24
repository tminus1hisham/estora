import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estora/core/theme/app_theme.dart';
import 'package:estora/navigation/adaptive_app_frame.dart';

void main() {
  for (final width in [320.0, 1200.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('navigation at width $width and text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        var selected = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: AdaptiveAppFrame(
              body: const Center(child: Text('Workspace content')),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search),
                  label: 'Browse',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_available_outlined),
                  label: 'Bookings',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long),
                  label: 'Invoices',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Profile',
                ),
              ],
              selectedIndex: 0,
              onDestinationSelected: (index) => selected = index,
              workspaceLabel: 'Your space',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(NavigationRail),
          width >= 1100 && scale == 1 ? findsOneWidget : findsNothing,
        );
        expect(find.text('Workspace content'), findsOneWidget);
        await tester.tap(find.text('Browse'));
        await tester.pumpAndSettle();
        expect(selected, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
