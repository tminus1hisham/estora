import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/app_media.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../navigation/routes.dart';

/// The architectural welcome is decorative, never presented as an owned or
/// rented property. It stays present in loading, empty and error states.
class PremiumHomeHero extends StatelessWidget {
  const PremiumHomeHero({required this.manager, this.name, super.key});
  final bool manager;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Stack(
      children: [
        const Positioned.fill(
          child: ExcludeSemantics(
            child: AppMedia(
              source: 'assets/images/property_sarit_mall.jpg',
              aspectRatio: null,
              backgroundColor: AppPalette.navy900,
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  AppPalette.navy950.withValues(alpha: 0.42),
                  AppPalette.navy900.withValues(alpha: 0.87),
                  AppPalette.navy950,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.maxReadingWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.apartment_rounded,
                          color: AppPalette.brass200,
                          size: 24,
                        ),
                        Gap.w8,
                        Text(
                          'MALL',
                          style: text.titleMedium?.copyWith(
                            color: AppPalette.stone0,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        IconButton.filledTonal(
                          tooltip: 'Your account',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.12,
                            ),
                            foregroundColor: AppPalette.stone0,
                          ),
                          onPressed: () => context.goNamed(
                            manager ? Routes.ownerAccount : Routes.profile,
                          ),
                          icon: const Icon(Icons.person_outline_rounded),
                        ),
                      ],
                    ),
                    Gap.h24,
                    Text(
                      name == null || name!.isEmpty
                          ? 'Welcome'
                          : 'Welcome, $name',
                      style: text.titleMedium?.copyWith(
                        color: AppPalette.brass200,
                      ),
                    ),
                    Gap.h8,
                    Text(
                      manager
                          ? 'Great spaces.\nMade simple.'
                          : 'Your space.\nYour next chapter.',
                      style: text.headlineLarge?.copyWith(
                        color: AppPalette.stone0,
                        fontSize: 36,
                        height: 1.15,
                        letterSpacing: -1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Gap.h16,
                    Text(
                      manager
                          ? 'A little clarity for everything you manage.'
                          : 'Settle in. Everything you need is right here.',
                      style: text.bodyMedium?.copyWith(
                        color: AppPalette.stone200,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class HomeActionPanel extends StatelessWidget {
  const HomeActionPanel({required this.manager, super.key});
  final bool manager;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.navy950.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MAKE YOURSELF AT HOME',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.8,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          Gap.h8,
          Text(
            'What would you like to do?',
            style: theme.textTheme.titleMedium,
          ),
          Gap.h16,
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              FilledButton.icon(
                onPressed: () => context.goNamed(
                  manager ? Routes.ownerProperties : Routes.invoices,
                ),
                icon: Icon(
                  manager
                      ? Icons.apartment_outlined
                      : Icons.receipt_long_outlined,
                ),
                label: Text(manager ? 'View properties' : 'View invoices'),
              ),
              if (!manager)
                OutlinedButton.icon(
                  onPressed: () => context.goNamed(Routes.browse),
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Browse properties'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class HomeWelcomeCard extends StatelessWidget {
  const HomeWelcomeCard({required this.manager, super.key});
  final bool manager;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              manager
                  ? Icons.holiday_village_outlined
                  : Icons.mark_email_read_outlined,
              color: theme.colorScheme.onTertiaryContainer,
              size: 30,
            ),
          ),
          Gap.h16,
          Text(
            manager
                ? 'Nothing in your portfolio yet.'
                : 'A fresh start. A clear view.',
            style: theme.textTheme.titleLarge,
          ),
          Gap.h8,
          Text(
            manager
                ? 'Properties assigned to you will appear here, with their spaces and rent all in one place.'
                : 'No invoices yet. When one arrives, you’ll find the details here. In the meantime, explore a space that feels right for you.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          Gap.h16,
          TextButton.icon(
            onPressed: () => manager
                ? context.goNamed(Routes.ownerProperties)
                : context.goNamed(Routes.browse),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(manager ? 'Open your portfolio' : 'Explore spaces'),
          ),
        ],
      ),
    );
  }
}

class HomeLoadingCard extends StatelessWidget {
  const HomeLoadingCard({super.key});
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Getting things ready for you',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Gap.h16,
          const LinearProgressIndicator(),
        ],
      ),
    ),
  );
}

class HomeSectionError extends StatelessWidget {
  const HomeSectionError({
    required this.failure,
    required this.onRetry,
    super.key,
  });
  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          Gap.h16,
          Text(
            'Your home is ready. The details can wait.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Gap.h8,
          Text(
            failure.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (failure is NetworkFailure ||
              failure is ServerFailure ||
              failure is UnknownFailure) ...[
            Gap.h8,
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    ),
  );
}

class HomeFooter extends StatelessWidget {
  const HomeFooter({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Gap.sm),
    child: Text(
      'SPACE TO BELONG. ROOM TO GROW.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.6,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
