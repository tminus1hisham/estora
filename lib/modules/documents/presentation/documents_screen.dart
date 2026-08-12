import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/tenant.dart';
import '../../../domain/enums/domain_enums.dart';
import '../application/document_controller.dart';

/// Section 77's Documents screen (section 51's entity).
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(documentListProvider);
    final filter = ref.watch(documentFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: Gap.sm),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: filter == null,
                    onSelected: (_) =>
                        ref.read(documentFilterProvider.notifier).select(null),
                  ),
                ),
                for (final type in const [
                  DocumentType.signedLease,
                  DocumentType.receipt,
                  DocumentType.tenantId,
                  DocumentType.businessRegistration,
                  DocumentType.taxCertificate,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: Gap.sm),
                    child: FilterChip(
                      label: Text(type.label),
                      selected: filter == type,
                      onSelected: (selected) => ref
                          .read(documentFilterProvider.notifier)
                          .select(selected ? type : null),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: switch (documents) {
              AsyncLoading() when !documents.hasValue => const LoadingView(),
              AsyncError(:final error) => ErrorView(
                failure: error is Failure
                    ? error
                    : UnknownFailure(error.toString()),
                onRetry: () =>
                    ref.read(documentListProvider.notifier).refresh(),
              ),
              _ => _DocumentList(documents: documents.requireValue),
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadSheet(context, ref),
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Upload'),
      ),
    );
  }

  void _showUploadSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'What are you uploading?',
                  style: Theme.of(sheetContext).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Gap.h8,
            for (final type in DocumentType.tenantUploadable)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(type.label),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  // A real build opens the platform file picker here. The mock
                  // records the metadata, which is what the requirement check
                  // needs, so the flow works end to end without one.
                  await ref
                      .read(documentActionsProvider)
                      .upload(
                        type: type,
                        fileName: '${type.api.toLowerCase()}.pdf',
                        bytes: Uint8List.fromList(
                          List<int>.filled(160 * 1024, 0, growable: false),
                        ),
                        mimeType: 'application/pdf',
                      );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _DocumentList extends ConsumerWidget {
  const _DocumentList({required this.documents});

  final List<Document> documents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (documents.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'No documents',
        message:
            'Your lease agreement, receipts and anything you upload will be '
            'kept here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(documentListProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: documents.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final document = documents[index];
          final scheme = Theme.of(context).colorScheme;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.surfaceContainerHighest,
              child: Icon(
                document.isPdf
                    ? Icons.picture_as_pdf_outlined
                    : Icons.insert_drive_file_outlined,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ),
            title: Text(
              document.fileName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              [
                document.documentType.label,
                AppDate.short(document.createdAt),
                if (document.sizeLabel.isNotEmpty) document.sizeLabel,
                // Section 28: generated documents are versioned and immutable,
                // so which version this is matters.
                if (document.version > 1) 'v${document.version}',
              ].join(' · '),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.download_outlined),
              onPressed: () => ref
                  .read(documentActionsProvider)
                  .openDocument(context, document.id),
            ),
            onTap: () => ref
                .read(documentActionsProvider)
                .openDocument(context, document.id),
          );
        },
      ),
    );
  }
}
