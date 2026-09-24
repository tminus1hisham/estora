import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_bottom_action_bar.dart';
import '../../../components/async_button.dart';
import '../../../components/page_empty_state.dart';
import '../../../components/page_header.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/routes.dart';
import '../application/support_controller.dart';
import '../application/support_models.dart';

/// The form that opens a ticket — the contract's `CreateTicketRequest`.
///
/// It asks for what kind of problem it is and what is happening. The
/// property and unit the request also needs come off the tenant's lease: a
/// tenant with one unit is never asked, and one with several picks.
class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key});

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();

  SupportCategory _category = SupportCategory.maintenance;
  TicketSpace? _space;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit(TicketSpace space) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Check the highlighted fields before sending.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await ref
        .read(supportTicketsProvider.notifier)
        .raise(
          TicketDraft(
            category: _category,
            comment: _commentController.text.trim(),
            propertyId: space.propertyId,
            propertyName: space.propertyName,
            unitId: space.unitId,
          ),
        );
    if (!mounted) return;

    switch (result) {
      case Ok():
        // Back to the list, which has already been reread with the new
        // ticket at the top.
        context.pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Ticket raised. We will be in touch.'),
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

  @override
  Widget build(BuildContext context) {
    final spaces = ref.watch(ticketSpacesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Raise a ticket')),
      body: switch (spaces) {
        AsyncLoading() when !spaces.hasValue => const LoadingView(),
        AsyncError(:final error) when !spaces.hasValue => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(ticketSpacesProvider),
        ),
        _ when spaces.requireValue.isEmpty => PageEmptyState(
          icon: Icons.storefront_outlined,
          caption: 'Support',
          title: 'No unit to raise it about',
          message:
              'A ticket is raised about the space on your lease. Once you '
              'have one, you can report anything about it here.',
          action: FilledButton.tonalIcon(
            onPressed: () => context.goNamed(Routes.support),
            icon: const Icon(Icons.list_alt_rounded),
            label: const Text('Back to tickets'),
          ),
        ),
        _ => _form(context, spaces.requireValue),
      },
      // The bar is a bottomNavigationBar so the scaffold lifts it clear of the
      // keyboard; see AppBottomActionBar for why it constrains its own height.
      bottomNavigationBar: switch (spaces.value) {
        final list? when list.isNotEmpty => AppBottomActionBar(
          child: AsyncButton(
            label: 'Send to support',
            loadingLabel: 'Sending…',
            icon: Icons.send_outlined,
            expand: true,
            onPressed: () => _submit(_space ?? list.first),
          ),
        ),
        _ => null,
      },
    );
  }

  Widget _form(BuildContext context, List<TicketSpace> spaces) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = _space ?? spaces.first;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxReadingWidth),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            children: [
              const PageHeader(
                compact: true,
                title: 'Tell us what is wrong',
                subtitle:
                    'The more precise the detail, the fewer questions come '
                    'back.',
              ),
              Gap.h16,

              SectionCard(
                title: 'What is it about?',
                children: [
                  CategoryChips(
                    selected: _category,
                    onSelected: (category) =>
                        setState(() => _category = category),
                  ),
                ],
              ),

              Gap.h12,
              SectionCard(
                title: 'Where is it?',
                children: [
                  if (spaces.length == 1)
                    DetailRow(label: 'Unit', value: selected.label)
                  else
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.sm,
                      children: [
                        for (final space in spaces)
                          ChoiceChip(
                            label: Text(space.label),
                            selected: space.unitId == selected.unitId,
                            onSelected: (_) => setState(() => _space = space),
                          ),
                      ],
                    ),
                ],
              ),

              Gap.h12,
              SectionCard(
                title: 'The detail',
                children: [
                  TicketCommentField(controller: _commentController),
                  Text(
                    'The desk will reply on this ticket.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The six categories as chips. Shared with the edit sheet on the detail
/// screen, so a ticket is described the same way both times.
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final SupportCategory selected;
  final ValueChanged<SupportCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Chips rather than a dropdown: six options are quicker to scan laid out
    // than hidden behind a tap, and the wrap handles narrow screens and large
    // text on its own.
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        for (final category in SupportCategory.values)
          ChoiceChip(
            avatar: Icon(
              category.icon,
              size: 18,
              color: selected == category
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
            ),
            label: Text(category.label),
            selected: selected == category,
            onSelected: (_) => onSelected(category),
          ),
      ],
    );
  }
}

/// The ticket's comment, with the same rules when raising and editing.
class TicketCommentField extends StatelessWidget {
  const TicketCommentField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      minLines: 4,
      maxLines: 8,
      maxLength: 1000,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'What is happening?',
        alignLabelWithHint: true,
        hintText:
            'When it started, how bad it is, and anything you have already '
            'tried.',
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return 'Describe the issue';
        if (text.length < 15) return 'Give the desk a little more to go on';
        return null;
      },
    );
  }
}
