import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_bottom_action_bar.dart';
import '../../../components/async_button.dart';
import '../../../components/page_header.dart';
import '../../../components/section_card.dart';
import '../../../core/theme/app_theme.dart';
import '../application/support_controller.dart';
import '../application/support_models.dart';

/// The form that opens a ticket.
///
/// It asks for the five things a support desk needs to act without writing
/// back for more: what kind of problem, how urgent, a line to recognise it by,
/// the detail, and where in the building it is. Nothing else — every extra
/// field is a reason to put the report off until later.
class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key});

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  SupportCategory _category = SupportCategory.maintenance;
  TicketPriority _priority = TicketPriority.normal;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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

    final location = _locationController.text.trim();
    final ticket = ref
        .read(supportTicketsProvider.notifier)
        .raise(
          subject: _subjectController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _category,
          priority: _priority,
          location: location.isEmpty ? null : location,
        );

    // Back to the list, where the new ticket is already sitting at the top;
    // the reference follows in a snackbar so it is read against the record it
    // belongs to rather than on a screen about to disappear.
    context.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Ticket ${ticket.reference} raised. We will be in touch.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Raise a ticket')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.sm,
                Gap.lg,
                Gap.xxl,
              ),
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
                    // Chips rather than a dropdown: six options are quicker to
                    // scan laid out than hidden behind a tap, and the wrap
                    // handles narrow screens and large text on its own.
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.sm,
                      children: [
                        for (final category in SupportCategory.values)
                          ChoiceChip(
                            avatar: Icon(
                              category.icon,
                              size: 18,
                              color: _category == category
                                  ? scheme.onSecondaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                            label: Text(category.label),
                            selected: _category == category,
                            onSelected: (_) =>
                                setState(() => _category = category),
                          ),
                      ],
                    ),
                    Gap.h16,
                    DropdownButtonFormField<TicketPriority>(
                      initialValue: _priority,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: [
                        for (final priority in TicketPriority.values)
                          DropdownMenuItem(
                            value: priority,
                            child: Text(priority.label),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => _priority = value ?? TicketPriority.normal,
                      ),
                    ),
                  ],
                ),

                Gap.h12,
                SectionCard(
                  title: 'The detail',
                  children: [
                    TextFormField(
                      controller: _subjectController,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        hintText: 'e.g. Leaking tap in the wash area',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Give the issue a short title';
                        if (text.length < 5) {
                          return 'A few more words would help';
                        }
                        return null;
                      },
                    ),
                    Gap.h8,
                    TextFormField(
                      controller: _descriptionController,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'What is happening?',
                        alignLabelWithHint: true,
                        hintText:
                            'When it started, how bad it is, and anything you '
                            'have already tried.',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'Describe the issue';
                        }
                        if (text.length < 15) {
                          return 'Give the desk a little more to go on';
                        }
                        return null;
                      },
                    ),
                    Gap.h8,
                    TextFormField(
                      controller: _locationController,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: 'Where is it? (optional)',
                        prefixIcon: Icon(Icons.place_outlined),
                        hintText: 'Unit, floor or area',
                      ),
                    ),
                    Text(
                      'Left blank, the desk will assume the unit on your lease.',
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
      ),
      // The bar is a bottomNavigationBar so the scaffold lifts it clear of the
      // keyboard; see AppBottomActionBar for why it constrains its own height.
      bottomNavigationBar: AppBottomActionBar(
        child: AsyncButton(
          label: 'Send to support',
          loadingLabel: 'Sending…',
          icon: Icons.send_outlined,
          expand: true,
          onPressed: _submit,
        ),
      ),
    );
  }
}
