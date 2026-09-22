import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/components/glass_material.dart';
import 'package:mall/core/theme/app_theme.dart';

import '../support/preview_capture.dart';

void main() {
  setUpAll(loadPreviewFonts);

  for (final dark in [false, true]) {
    testWidgets('glass material renders (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      usePhoneViewport(tester);
      const key = ValueKey('preview');
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark : AppTheme.light,
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              body: GlassScene(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
                  children: [
                    for (final tone in [
                      null,
                      AppPalette.red700,
                      AppPalette.green700,
                    ]) ...[
                      FrostedPane(
                        tone: tone,
                        child: Row(
                          children: [
                            const Expanded(child: Text('INV-2026-0031')),
                            GlassCapsuleButton(
                              label: 'Pay now',
                              icon: Icons.phone_android_rounded,
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    FrostedPane(
                      radius: GlassRadius.platter,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (final i in [
                            Icons.receipt_long_rounded,
                            Icons.account_balance_wallet_rounded,
                            Icons.folder_copy_rounded,
                            Icons.support_agent_rounded,
                          ])
                            FrostedPane(
                              depth: GlassDepth.inset,
                              radius: GlassRadius.tile,
                              padding: const EdgeInsets.all(14),
                              child: Icon(i),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassCapsuleButton(
                      label: 'All invoices',
                      prominent: false,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capturePreview(tester, key, 'glass-${dark ? 'dark' : 'light'}');
    });
  }
}
