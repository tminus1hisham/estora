import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_skeleton.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
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
              AsyncLoading() when !documents.hasValue =>
                const AppSkeletonList(),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What are you uploading?',
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: AppTypography.bold),
                  ),
                  Gap.h8,
                  Text(
                    'Choose a PDF, JPG or PNG file up to 15 MB.',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Gap.h8,
            for (final type in DocumentType.tenantUploadable)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(type.label),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _pickAndUpload(context, ref, type);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(
    BuildContext context,
    WidgetRef ref,
    DocumentType type,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: true,
    );
    if (selection == null || selection.files.isEmpty) return;
    if (!context.mounted) return;

    final file = selection.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('That file could not be read. Please choose it again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    const maximumBytes = 15 * 1024 * 1024;
    if (file.size > maximumBytes) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Choose a file smaller than 15 MB.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            Gap.w12,
            Expanded(child: Text('Uploading ${file.name}...')),
          ],
        ),
        duration: const Duration(minutes: 1),
      ),
    );

    final result = await ref
        .read(documentActionsProvider)
        .upload(
          type: type,
          fileName: file.name,
          bytes: bytes,
          mimeType: _mimeType(file.extension),
        );
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    switch (result) {
      case Ok():
        messenger.showSnackBar(
          SnackBar(
            content: Text('${file.name} uploaded successfully.'),
            behavior: SnackBarBehavior.floating,
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

  String _mimeType(String? extension) => switch (extension?.toLowerCase()) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    _ => 'application/pdf',
  };
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
              style: const TextStyle(fontWeight: AppTypography.semibold),
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
