import 'package:flutter/material.dart';

import '../../../components/state_views.dart';
import '../../../core/theme/app_theme.dart';

/// A branch of the owner shell that has not been built yet.
///
/// Section 88's owner work lands milestone by milestone, and a shell with a
/// dead tab in it is worse than a shell with an honest one. This says which
/// screen is coming rather than showing an empty scaffold that reads as a bug.
///
/// Every use of this is a placeholder to be deleted, not a pattern to copy.
class OwnerPlaceholderScreen extends StatelessWidget {
  const OwnerPlaceholderScreen({
    required this.title,
    required this.icon,
    required this.message,
    super.key,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxReadingWidth),
          child: EmptyState(icon: icon, title: title, message: message),
        ),
      ),
    );
  }
}
