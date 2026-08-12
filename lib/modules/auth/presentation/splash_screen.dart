import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Shown while the stored session is being read (section 77's Splash).
///
/// The router keeps the app here until the auth stage resolves, so a signed-in
/// tenant never sees the login screen flash past on launch.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.storefront_rounded,
                size: 36,
                color: scheme.onPrimaryContainer,
              ),
            ),
            Gap.h24,
            Text(
              'Tenant Portal',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            Gap.h32,
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
