import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/section_card.dart';
import '../../../../components/state_views.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/access.dart';

/// Granting and revoking claims, for either an account or a role.
///
/// The same control serves both because a claim is the same thing in both
/// places — a type and a value — and only what it is attached to differs. The
/// callers supply the two verbs.
///
/// Claim types are shown by their tail (`permission`, not the whole schema
/// URI) with the full string underneath, because a column of identical URI
/// prefixes tells the reader nothing and hides the part that differs.
class ClaimEditor extends StatelessWidget {
  const ClaimEditor({
    required this.title,
    required this.description,
    required this.claims,
    required this.onAdd,
    required this.onRemove,
    required this.onRetry,
    super.key,
  });

  final String title;
  final String description;
  final AsyncValue<List<AccessClaim>> claims;
  final Future<Result<void>> Function(String type, String value) onAdd;
  final Future<Result<void>> Function(AccessClaim claim) onRemove;
  final VoidCallback onRetry;

  Future<void> _add(BuildContext context) async {
    final claim = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => const _AddClaimDialog(),
    );
    if (claim == null || !context.mounted) return;

    final result = await onAdd(claim.$1, claim.$2);
    if (!context.mounted) return;
    if (result case Err(:final failure)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _remove(BuildContext context, AccessClaim claim) async {
    final result = await onRemove(claim);
    if (!context.mounted) return;
    if (result case Err(:final failure)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SectionCard(
      title: title,
      trailing: IconButton(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_rounded),
        tooltip: 'Add a permission',
      ),
      children: [
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        Gap.h12,
        switch (claims) {
          AsyncLoading() when !claims.hasValue => const LoadingView(
            compact: true,
          ),
          AsyncError(:final error) => ErrorView(
            failure: error is Failure
                ? error
                : UnknownFailure(error.toString()),
            onRetry: onRetry,
          ),
          _ => _ClaimList(
            claims: claims.requireValue,
            onRemove: (claim) => _remove(context, claim),
          ),
        },
      ],
    );
  }
}

class _ClaimList extends StatelessWidget {
  const _ClaimList({required this.claims, required this.onRemove});

  final List<AccessClaim> claims;
  final ValueChanged<AccessClaim> onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (claims.isEmpty) {
      return Text(
        'No permissions granted here.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      );
    }

    return Column(
      children: [
        for (final claim in claims)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.key_outlined),
            title: Text(claim.value),
            subtitle: Text(
              claim.shortType == claim.type
                  ? claim.type
                  : '${claim.shortType} · ${claim.type}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: IconButton(
              onPressed: () => onRemove(claim),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Revoke',
            ),
          ),
      ],
    );
  }
}

class _AddClaimDialog extends StatefulWidget {
  const _AddClaimDialog();

  @override
  State<_AddClaimDialog> createState() => _AddClaimDialogState();
}

class _AddClaimDialogState extends State<_AddClaimDialog> {
  final _formKey = GlobalKey<FormState>();

  /// `permission` is what the platform's own claims use, so it is the default
  /// rather than an empty field somebody has to guess at.
  final _typeController = TextEditingController(text: 'permission');
  final _valueController = TextEditingController();

  @override
  void dispose() {
    _typeController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a permission'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _typeController,
              decoration: const InputDecoration(
                labelText: 'Claim type',
                helperText: 'Usually "permission".',
              ),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Enter a claim type' : null,
            ),
            Gap.h12,
            TextFormField(
              controller: _valueController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Value',
                hintText: 'invoices.settle',
              ),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Enter a value' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(
              context,
            ).pop((_typeController.text.trim(), _valueController.text.trim()));
          },
          child: const Text('Grant'),
        ),
      ],
    );
  }
}
