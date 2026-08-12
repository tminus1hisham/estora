import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../navigation/routes.dart';
import '../application/lease_controller.dart';

/// Section 77's Lease Agreement screen — read-only.
///
/// Section 28 makes generated documents immutable and versioned, so the version
/// and hash are shown: a tenant should be able to see which document they are
/// looking at, and it is the same identifier that appears against their
/// signature afterwards.
class LeaseAgreementScreen extends ConsumerWidget {
  const LeaseAgreementScreen({required this.leaseId, super.key});

  final String leaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agreement = ref.watch(leaseAgreementProvider(leaseId));
    final lease = ref.watch(leaseDetailProvider(leaseId)).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lease agreement'),
        actions: [
          IconButton(
            tooltip: 'Download',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'The signed PDF is available from Documents once the lease '
                  'is signed.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            ),
            icon: const Icon(Icons.download_outlined),
          ),
          Gap.w8,
        ],
      ),
      body: switch (agreement) {
        AsyncLoading() => const LoadingView(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(leaseAgreementProvider(leaseId)),
        ),
        AsyncData(:final value) => _AgreementBody(agreement: value),
      },
      bottomNavigationBar:
          (lease?.status.needsTenantSignature ?? false)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: FilledButton.icon(
                  onPressed: () => context.pushReplacementNamed(
                    Routes.signAgreement,
                    pathParameters: {'leaseId': leaseId},
                  ),
                  icon: const Icon(Icons.draw_outlined),
                  label: const Text('Sign this agreement'),
                ),
              ),
            )
          : null,
    );
  }
}

class _AgreementBody extends StatelessWidget {
  const _AgreementBody({required this.agreement});

  final LeaseAgreement agreement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Version ${agreement.version} · '
                      '${AppDate.short(agreement.generatedAt)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      agreement.documentHash,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Gap.h24,
        SelectableText(
          agreement.body ?? 'The agreement text is not available.',
          style: const TextStyle(height: 1.6),
        ),
      ],
    );
  }
}
