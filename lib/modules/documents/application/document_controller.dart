import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    state = await AsyncValue.guard(build);
  }
}

final documentActionsProvider = Provider<DocumentActions>(
  (ref) => DocumentActions(ref),
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
        // Handing off to the platform browser or viewer is the remaining piece
        // here; the signed URL is what that call would receive.
        messenger.showSnackBar(
          SnackBar(
            content: Text('Signed download link ready: $value'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      case Err(:final failure):
        messenger.showSnackBar(
          SnackBar(
            content: Text(failure.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
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
