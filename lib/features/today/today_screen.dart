import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:sankalpa/data/repositories/manifestation_repository.dart';
import 'package:sankalpa/data/supabase_config.dart';
import 'package:sankalpa/widgets/logo.dart';

/// Home / "Today" screen.
///
/// Surfaces the most important action — start the ritual — and gives quick
/// glances at the manifestation count and library access. Intentionally
/// quiet: no streaks/stats panel until that lands in `streaks-reminders`.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final manifestations = SupabaseConfig.isConfigured
        ? ref.watch(manifestationsProvider)
        : const AsyncValue<List<dynamic>>.data(<dynamic>[]);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _TopBar(),
              const SizedBox(height: 48),
              if (!SupabaseConfig.isConfigured) ...[
                const _UnconfiguredBanner(),
                const SizedBox(height: 24),
              ],
              Text(
                _greeting(),
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Take a moment for your manifestations.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 40),
              _RitualCta(
                manifestations: manifestations,
                enabled: SupabaseConfig.isConfigured,
                onStart: () => context.go('/ritual'),
              ),
              if (SupabaseConfig.isConfigured) ...[
                const SizedBox(height: 16),
                _LibraryButton(onTap: () => context.go('/library')),
                const SizedBox(height: 32),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.read(authControllerProvider).signOut(),
                    child: Text(
                      'Sign out',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Late night.';
    if (hour < 12) return 'Good morning.';
    if (hour < 17) return 'Good afternoon.';
    if (hour < 21) return 'Good evening.';
    return 'Good night.';
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Logo(height: 32),
        const SizedBox(width: 10),
        Text(
          'Sankalpa',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

class _RitualCta extends StatelessWidget {
  const _RitualCta({
    required this.manifestations,
    required this.enabled,
    required this.onStart,
  });

  final AsyncValue<dynamic> manifestations;
  final bool enabled;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = manifestations.maybeWhen(
      data: (items) => (items as List).length,
      orElse: () => 0,
    );
    final hasAny = count > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: ChocolatePalette.bgElevated,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Logo(variant: LogoVariant.symbol, height: 22),
              const SizedBox(width: 10),
              Text(
                'Daily ritual',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: ChocolatePalette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasAny
                ? '$count manifestation${count == 1 ? '' : 's'} ready.'
                : 'Add a manifestation to begin.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: ChocolatePalette.textPrimary.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: ChocolatePalette.surface,
              foregroundColor: ChocolatePalette.textPrimary,
            ),
            onPressed: enabled && hasAny ? onStart : null,
            child: const Text('Start ritual'),
          ),
        ],
      ),
    );
  }
}

class _LibraryButton extends StatelessWidget {
  const _LibraryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.library_books_outlined, size: 18),
        label: const Text('Open library'),
      ),
    );
  }
}

class _UnconfiguredBanner extends StatelessWidget {
  const _UnconfiguredBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Accents.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: Accents.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Accents.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Supabase not configured.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
