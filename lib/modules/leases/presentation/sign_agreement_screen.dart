import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';

import '../../../components/async_button.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/repositories/repositories.dart';
import '../application/lease_controller.dart';

/// Section 29. Review the agreement, then sign it.
///
/// Two gates stand between arriving here and the sign button becoming
/// available:
///
/// 1. the agreement must have been scrolled to the end, and
/// 2. a signature must actually have been drawn.
///
/// The first is not decoration. Section 29 lists reviewing the terms as a step
/// in its own right, and a signature captured from someone who was never shown
/// the text is worth very little in the dispute that section 85 anticipates.
///
/// The submitted signature carries the `documentHash` of the exact version
/// displayed, so what was signed is provable.
class SignAgreementScreen extends ConsumerStatefulWidget {
  const SignAgreementScreen({required this.leaseId, super.key});

  final String leaseId;

  @override
  ConsumerState<SignAgreementScreen> createState() =>
      _SignAgreementScreenState();
}

class _SignAgreementScreenState extends ConsumerState<SignAgreementScreen> {
  final _scrollController = ScrollController();
  late final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2.5,
    exportBackgroundColor: Colors.transparent,
  );

  bool _hasScrolledToEnd = false;
  bool _hasSignature = false;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _signatureController.addListener(_onSignatureChanged);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _signatureController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_hasScrolledToEnd) return;
    final position = _scrollController.position;
    // A small tolerance, so an agreement that ends a few pixels short of the
    // viewport bottom still counts as read.
    if (position.pixels >= position.maxScrollExtent - 24) {
      setState(() => _hasScrolledToEnd = true);
    }
  }

  void _onSignatureChanged() {
    final has = _signatureController.isNotEmpty;
    if (has != _hasSignature) setState(() => _hasSignature = has);
  }

  bool get _canSign => _hasScrolledToEnd && _hasSignature && _confirmed;

  Future<void> _sign(LeaseAgreement agreement) async {
    final signatureBytes = await _signatureController.toPngBytes();
    if (signatureBytes == null || !mounted) return;

    final result = await ref
        .read(leaseActionsProvider)
        .sign(
          leaseId: widget.leaseId,
          signatureData: signatureBytes,
          // Binds the signature to the version that was on screen.
          documentHash: agreement.documentHash,
        );

    if (!mounted) return;

    switch (result) {
      case Ok():
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.check_circle_outline_rounded, size: 40),
            title: const Text('Agreement signed'),
            content: const Text(
              'Thank you. Your signed agreement has gone to the property '
              'manager. Your lease becomes active once they approve it and the '
              'deposit has cleared.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        );
        if (mounted) context.pop();

      case Err(:final failure):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // The server rejects a stale hash if the agreement was regenerated
        // after this screen loaded. Reload so the tenant reviews and signs the
        // current wording rather than retrying against text that no longer
        // applies.
        if (failure is ConflictFailure) {
          ref.invalidate(leaseAgreementProvider(widget.leaseId));
          setState(() {
            _hasScrolledToEnd = false;
            _confirmed = false;
          });
          _signatureController.clear();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final agreement = ref.watch(leaseAgreementProvider(widget.leaseId));

    return Scaffold(
      appBar: AppBar(title: const Text('Sign your lease')),
      body: switch (agreement) {
        AsyncLoading() => const LoadingView(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () =>
              ref.invalidate(leaseAgreementProvider(widget.leaseId)),
        ),
        AsyncData(:final value) => _buildBody(value),
      },
    );
  }

  Widget _buildBody(LeaseAgreement agreement) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Step 1: read.
        Expanded(
          child: Stack(
            children: [
              ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(Gap.lg),
                children: [
                  Text(
                    'Version ${agreement.version} · '
                    '${AppDate.short(agreement.generatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Gap.h16,
                  SelectableText(
                    agreement.body ?? '',
                    style: const TextStyle(height: 1.6),
                  ),
                  Gap.h24,
                  if (!_hasScrolledToEnd)
                    Center(
                      child: Text(
                        'Scroll to the end to continue',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
              if (!_hasScrolledToEnd)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            scheme.surface.withValues(alpha: 0),
                            scheme.surface,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Step 2: sign.
        Container(
          color: scheme.surfaceContainerLow,
          padding: const EdgeInsets.all(Gap.lg),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      _hasScrolledToEnd
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      size: 18,
                      color: _hasScrolledToEnd
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    Gap.w8,
                    Expanded(
                      child: Text(
                        _hasScrolledToEnd
                            ? 'You have read the agreement'
                            : 'Read the full agreement to enable signing',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (_hasSignature)
                      TextButton(
                        onPressed: () {
                          _signatureController.clear();
                          setState(() => _hasSignature = false);
                        },
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                Gap.h12,
                Opacity(
                  opacity: _hasScrolledToEnd ? 1 : 0.45,
                  child: IgnorePointer(
                    ignoring: !_hasScrolledToEnd,
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Stack(
                        children: [
                          if (!_hasSignature)
                            Center(
                              child: Text(
                                'Sign here',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Signature(
                              controller: _signatureController,
                              height: 140,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Gap.h8,
                CheckboxListTile(
                  value: _confirmed,
                  onChanged: _hasScrolledToEnd
                      ? (value) => setState(() => _confirmed = value ?? false)
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    'I have read this agreement and agree to be bound by it.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                AsyncButton(
                  label: 'Sign agreement',
                  icon: Icons.draw_outlined,
                  enabled: _canSign,
                  onPressed: () => _sign(agreement),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
