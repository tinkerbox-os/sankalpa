import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/audio/ritual_audio_service.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:sankalpa/data/models/soundscape.dart';
import 'package:sankalpa/data/repositories/manifestation_repository.dart';
import 'package:sankalpa/data/repositories/session_repository.dart';
import 'package:sankalpa/data/repositories/soundscape_repository.dart';
import 'package:sankalpa/data/repositories/user_profile_repository.dart';
import 'package:sankalpa/data/supabase_config.dart';
import 'package:sankalpa/data/web/install_prompt.dart';
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
    // Pre-warm the default soundscape so its URL is in cache when the user
    // taps Start ritual; we need to call audio.load() inside the tap event
    // for iOS Safari to permit playback.
    if (SupabaseConfig.isConfigured) {
      ref.watch(defaultSoundscapeProvider);
    }

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
              if (SupabaseConfig.isConfigured) ...[
                const SizedBox(height: 24),
                _StreakRow(stats: ref.watch(streakStatsProvider)),
              ],
              const SizedBox(height: 32),
              _RitualCta(
                manifestations: manifestations,
                enabled: SupabaseConfig.isConfigured,
                onStart: () async {
                  // iOS Safari blocks audio.play() unless it fires inside
                  // the same user-gesture tick. Kick off the soundscape
                  // here (synchronously inside the tap handler) so the
                  // ritual screen doesn't have to fight the autoplay
                  // policy from a post-frame callback.
                  if (SupabaseConfig.isConfigured) {
                    final sound =
                        ref.read(defaultSoundscapeProvider).valueOrNull;
                    if (sound != null) {
                      unawaited(
                        ref.read(ritualAudioProvider).load(sound.url),
                      );
                    }
                  }
                  if (!context.mounted) return;
                  context.go('/ritual');
                },
              ),
              if (SupabaseConfig.isConfigured) ...[
                const SizedBox(height: 16),
                _LibraryButton(onTap: () => context.go('/library')),
                const SizedBox(height: 16),
                const _SoundscapeRow(),
                const _InstallBanner(),
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
    return const Logo(height: 36);
  }
}

/// Compact streak strip: current streak chip + smaller "longest" / "total" text.
/// Shows nothing visually when stats are still loading.
class _StreakRow extends StatelessWidget {
  const _StreakRow({required this.stats});

  final AsyncValue<StreakStats> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return stats.maybeWhen(
      data: (s) {
        if (s.totalDays == 0) {
          return Text(
            'No rituals yet — start one below.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          );
        }
        return Row(
          children: [
            _StreakChip(
              count: s.current,
              completedToday: s.completedToday,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _summary(s),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
          ],
        );
      },
      orElse: SizedBox.shrink,
    );
  }

  String _summary(StreakStats s) {
    final parts = <String>[];
    if (s.longest > s.current && s.longest > 0) {
      parts.add('Longest ${s.longest}');
    }
    parts.add('${s.totalDays} day${s.totalDays == 1 ? '' : 's'} total');
    return parts.join(' · ');
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.count, required this.completedToday});

  final int count;
  final bool completedToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = completedToday
        ? Accents.gold
        : theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completedToday
                ? Icons.local_fire_department
                : Icons.local_fire_department_outlined,
            size: 16,
            color: accent,
          ),
          const SizedBox(width: 6),
          Text(
            count == 0 ? 'Start streak' : '$count-day streak',
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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

/// "Install this app" prompt — shows the captured browser install event on
/// supported browsers (Chrome/Edge desktop+Android), and never appears once
/// the app is running standalone. iOS Safari has no programmatic prompt;
/// users must use Share \u2192 Add to Home Screen, so we silently hide there.
class _InstallBanner extends ConsumerStatefulWidget {
  const _InstallBanner();

  @override
  ConsumerState<_InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends ConsumerState<_InstallBanner> {
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    final handle = ref.read(installPromptProvider);
    _sub = handle?.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final handle = ref.watch(installPromptProvider);
    if (handle == null || !handle.canPrompt) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        color: Accents.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: handle.prompt,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.add_to_home_screen, color: Accents.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Install Sankalpa',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add to your home screen for one-tap access.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact row showing the active soundscape with a tap to change it.
class _SoundscapeRow extends ConsumerWidget {
  const _SoundscapeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(defaultSoundscapeProvider).valueOrNull;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openPicker(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.music_note_outlined,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Soundscape',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      current?.name ?? 'Choosing\u2026',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Consumer(
          builder: (ctx, sheetRef, _) {
            final list = sheetRef.watch(soundscapesProvider);
            final current =
                sheetRef.watch(defaultSoundscapeProvider).valueOrNull;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Text(
                        'Choose your soundscape',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    list.when(
                      data: (items) => Column(
                        children: [
                          for (final s in items)
                            _SoundscapeTile(
                              soundscape: s,
                              selected: s.id == current?.id,
                              onTap: () async {
                                await sheetRef
                                    .read(userProfileRepositoryProvider)
                                    .updateSettings({
                                  'default_soundscape_id': s.id,
                                });
                                sheetRef
                                  ..invalidate(userProfileProvider)
                                  ..invalidate(defaultSoundscapeProvider);
                                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                              },
                            ),
                        ],
                      ),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Could not load soundscapes.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SoundscapeTile extends StatelessWidget {
  const _SoundscapeTile({
    required this.soundscape,
    required this.selected,
    required this.onTap,
  });

  final Soundscape soundscape;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(_iconFor(soundscape.kind), color: Accents.gold),
      title: Text(soundscape.name),
      subtitle: Text(_subtitleFor(soundscape.kind)),
      trailing: selected ? const Icon(Icons.check, color: Accents.gold) : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      selected: selected,
      selectedTileColor:
          theme.colorScheme.onSurface.withValues(alpha: 0.04),
    );
  }

  IconData _iconFor(SoundscapeKind kind) {
    switch (kind) {
      case SoundscapeKind.solfeggio:
        return Icons.graphic_eq;
      case SoundscapeKind.nature:
        return Icons.water_drop_outlined;
      case SoundscapeKind.music:
        return Icons.music_note_outlined;
    }
  }

  String _subtitleFor(SoundscapeKind kind) {
    switch (kind) {
      case SoundscapeKind.solfeggio:
        return 'Solfeggio frequency';
      case SoundscapeKind.nature:
        return 'Nature ambience';
      case SoundscapeKind.music:
        return 'Instrumental';
    }
  }
}
