import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/result.dart';
import '../../../domain/entities/tenant.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../services/providers.dart';

/// The document type filter on the documents screen.
final documentFilterProvider =
    NotifierProvider<DocumentFilterController, DocumentType?>(
      DocumentFilterController.new,
    );

class DocumentFilterController extends Notifier<DocumentType?> {
  @override
  DocumentType? build() => null;

  void select(DocumentType? type) => state = type;
}

/// Section 77's Documents screen (section 51's entity).
final documentListProvider =
    AsyncNotifierProvider<DocumentListController, List<Document>>(
      DocumentListController.new,
    );

class DocumentListController extends AsyncNotifier<List<Document>> {
  @override
  Future<List<Document>> build() async {
    final type = ref.watch(documentFilterProvider);
    final result = await ref
        .read(documentRepositoryProvider)
        .listDocuments(type: type);
    return switch (result) {
      Ok(:final value) => value.items,
      Err(:final failure) => throw failure,
    };
  }

  Future<void> refresh() async {
    final scope = ref;
    final next = await AsyncValue.guard(build);
    if (scope.mounted) state = next;
  }
}

final documentActionsProvider = Provider<DocumentActions>(
  (ref) => DocumentActions(ref),
);

typedef DocumentUrlLauncher = Future<bool> Function(Uri uri);

/// Overridable so the signed-URL handoff can be verified without opening a
/// browser during widget tests.
final documentUrlLauncherProvider = Provider<DocumentUrlLauncher>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

class DocumentActions {
  DocumentActions(this._ref);

  final Ref _ref;

  /// Resolves a document to a short-lived signed URL and hands it to the
  /// platform.
  ///
  /// Section 75 requires access to go through a signed URL rather than a public
  /// link — the app never holds a durable pointer to a file, and the server
  /// re-authorises on every request. Section 74 is the reason: a URL that
  /// worked forever would be a way around tenant isolation.
  Future<void> openDocument(BuildContext context, String documentId) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await _ref
        .read(documentRepositoryProvider)
        .getDownloadUrl(documentId);

    switch (result) {
      case Ok(:final value):
        final uri = Uri.tryParse(value);
        if (uri == null ||
            !uri.hasAuthority ||
            uri.host.isEmpty ||
            !_isTrustedDocumentScheme(uri)) {
          _showMessage(messenger, 'The document link is not valid.');
          return;
        }

        try {
          final opened = await _ref.read(documentUrlLauncherProvider)(uri);
          if (!opened) {
            _showMessage(
              messenger,
              'No app is available to open this document.',
            );
          }
        } catch (_) {
          _showMessage(
            messenger,
            'The document could not be opened. Please try again.',
          );
        }
      case Err(:final failure):
        _showMessage(messenger, failure.message);
    }
  }

  bool _isTrustedDocumentScheme(Uri uri) =>
      uri.scheme == 'https' ||
      (uri.scheme == 'http' &&
          (uri.host == 'localhost' || uri.host == '127.0.0.1'));

  void _showMessage(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<Result<Document>> upload({
    required DocumentType type,
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async {
    final result = await _ref
        .read(documentRepositoryProvider)
        .upload(
          type: type,
          fileName: fileName,
          bytes: bytes,
          mimeType: mimeType,
        );
    if (result.isOk) {
      _ref.read(documentListProvider.notifier).refresh();
    }
    return result;
  }
}
