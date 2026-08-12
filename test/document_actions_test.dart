import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/error/result.dart';
import 'package:mall/domain/entities/tenant.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/domain/repositories/repositories.dart';
import 'package:mall/modules/documents/application/document_controller.dart';
import 'package:mall/services/providers.dart';

void main() {
  testWidgets('a signed document URL is handed to the platform', (
    tester,
  ) async {
    Uri? openedUri;
    final repository = _DocumentRepository(
      const Ok('https://files.example.test/signed/document.pdf?expires=60'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(repository),
          documentUrlLauncherProvider.overrideWithValue((uri) async {
            openedUri = uri;
            return true;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => FilledButton(
                onPressed: () => ref
                    .read(documentActionsProvider)
                    .openDocument(context, 'doc-1'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      openedUri,
      Uri.parse('https://files.example.test/signed/document.pdf?expires=60'),
    );
  });

  testWidgets('an invalid signed URL is rejected before platform handoff', (
    tester,
  ) async {
    var launchCount = 0;
    final repository = _DocumentRepository(const Ok('javascript:alert(1)'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(repository),
          documentUrlLauncherProvider.overrideWithValue((_) async {
            launchCount += 1;
            return true;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => FilledButton(
                onPressed: () => ref
                    .read(documentActionsProvider)
                    .openDocument(context, 'doc-1'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(launchCount, 0);
    expect(find.text('The document link is not valid.'), findsOneWidget);
  });
}

class _DocumentRepository implements DocumentRepository {
  const _DocumentRepository(this.downloadResult);

  final Result<String> downloadResult;

  @override
  Future<Result<String>> getDownloadUrl(String documentId) async =>
      downloadResult;

  @override
  Future<Result<Page<Document>>> listDocuments({
    DocumentType? type,
    int page = 1,
  }) => throw UnimplementedError();

  @override
  Future<Result<Document>> upload({
    required DocumentType type,
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) => throw UnimplementedError();
}
