import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/audio/ritual_audio_service.dart';
import 'package:sankalpa/data/repositories/manifestation_repository.dart';
import 'package:sankalpa/data/repositories/session_repository.dart';
import 'package:sankalpa/data/repositories/soundscape_repository.dart';
import 'package:sankalpa/data/repositories/user_profile_repository.dart';
import 'package:sankalpa/data/supabase_config.dart';
import 'package:sankalpa/data/web/install_prompt.dart';
import 'package:sankalpa/widgets/card_ambient_decoration.dart';
import 'package:sankalpa/widgets/logo.dart';
import 'package:sankalpa/widgets/soundscape_picker.dart';

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

    final hasManifestations = manifestations.maybeWhen(
      data: (items) => items.isNotEmpty,
      orElse: () => false,
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              if (SupabaseConfig.isConfigured) ...[
                const SizedBox(height: 24),
                _WeekTracker(stats: ref.watch(streakStatsProvider)),
                _OnboardingCard(manifestations: manifestations),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'Take a moment for your manifestations.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
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
                    // Pull the latest ordered manifestation list before we
                    // enter ritual mode. This avoids launching the ritual off
                    // an older in-memory snapshot and then correcting itself a
                    // beat later, which can make the "first" card appear
                    // wrong right after a reorder.
                    final refreshed = ref.refresh(manifestationsProvider.future);
                    await refreshed;
                  }
                  if (!context.mounted) return;
                  // Hand Ritual the colour the CTA is already painting. That
                  // locks the first ritual frame to today's shade instead of
                  // letting it fall back to chocolate while providers reload.
                  final themeId = ref.read(immediateCardThemeIdProvider);
                  context.go('/ritual', extra: themeId);
                },
              ),
              if (SupabaseConfig.isConfigured) ...[
                const SizedBox(height: 24),
                // Once the user has manifestations, library/soundscape stop
                // earning their full-width-card real estate. Demote them to
                // a quiet icon row.
                if (hasManifestations)
                  const _QuickActions()
                else ...[
                  _LibraryButton(onTap: () => context.go('/library')),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.push('/settings'),
                      icon: Icon(
                        Icons.settings_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55),
                      ),
                      label: Text(
                        'Settings',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                ],
                const _InstallBanner(),
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
    return const Center(child: Logo(height: 36));
  }
}

/// Compact bottom row of secondary actions \u2014 Library / Soundscape /
/// Settings \u2014 used once the user actually has manifestations and the
/// big "Open library" / "Soundscape" cards become visual noise.
class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _QuickActionButton(
          icon: Icons.library_books_outlined,
          label: 'Library',
          onTap: () => context.go('/library'),
        ),
        _QuickActionButton(
          icon: Icons.music_note_outlined,
          label: 'Sound',
          onTap: () => SoundscapePicker.open(context, ref),
        ),
        _QuickActionButton(
          icon: Icons.settings_outlined,
          label: 'Settings',
          onTap: () => context.push('/settings'),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: muted),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: muted,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Weekly habit-tracker strip — the visual centrepiece of the home
/// screen. Shows Mon–Sun for the current week with each day in one of:
///
///   - **Practiced** (gold filled circle + white check)
///   - **Today, not yet** (gold ring + sparkle logo glyph)
///   - **Today, done**     (gold filled circle + sparkle)
///   - **Past, missed**    (muted hollow ring)
///   - **Future**          (very faint hollow ring, no border emphasis)
///
/// Inspired by the "I am" weekly widget; replaces the static "Take a
/// moment" subtitle and the older streak chip — same data, visualised.
/// Streak/longest/total numbers are demoted to a single fine-print line
/// below so they don't compete with the strip itself.
class _WeekTracker extends StatelessWidget {
  const _WeekTracker({required this.stats});

  final AsyncValue<StreakStats> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return stats.maybeWhen(
      data: (s) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WeekStrip(practicedDays: s.practicedDays),
            const SizedBox(height: 12),
            Text(
              _summary(s),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      },
      // While loading we reserve the same vertical footprint so the
      // Daily ritual CTA below doesn't jump as the data resolves.
      orElse: () => const SizedBox(height: 86),
    );
  }

  String _summary(StreakStats s) {
    if (s.totalDays == 0) {
      return 'Tap Start ritual below to begin your first day.';
    }
    final parts = <String>[
      if (s.current == 0) 'Streak paused' else '${s.current}-day streak',
    ];
    if (s.longest > s.current && s.longest > 0) {
      parts.add('longest ${s.longest}');
    }
    parts.add('${s.totalDays} day${s.totalDays == 1 ? '' : 's'} total');
    return parts.join(' \u00b7 ');
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.practicedDays});

  final Set<DateTime> practicedDays;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    // Monday-first week, matching the I am layout.
    final monday = todayKey.subtract(Duration(days: today.weekday - 1));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = monday.add(Duration(days: i));
        final isToday = day == todayKey;
        final isFuture = day.isAfter(todayKey);
        final practiced = practicedDays.contains(day);
        return _DayCell(
          label: _weekdayShort(day.weekday),
          isToday: isToday,
          isFuture: isFuture,
          practiced: practiced,
        );
      }),
    );
  }

  static String _weekdayShort(int weekday) {
    // ISO: 1=Mon..7=Sun
    const labels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    return labels[weekday - 1];
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    required this.isToday,
    required this.isFuture,
    required this.practiced,
  });

  final String label;
  final bool isToday;
  final bool isFuture;
  final bool practiced;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final faint = theme.colorScheme.onSurface.withValues(alpha: 0.18);

    // Pick a (background, border, child) triple per state. Keeping it
    // declarative here makes the visual contract obvious at a glance.
    late final Color bg;
    late final Color border;
    late final Widget? child;

    if (practiced) {
      // Filled chocolate disc with a white check — anchors past days
      // in the same warm brown as the chocolate card style.
      bg = ChocolatePalette.bg;
      border = ChocolatePalette.bg;
      child = const Icon(Icons.check, size: 14, color: Colors.white);
    } else if (isToday) {
      // Today, not yet: hollow chocolate ring with the gold brand
      // sparkle inside — chocolate = "this is your day", gold sparkle =
      // "still to be done".
      bg = Colors.transparent;
      border = ChocolatePalette.bg;
      child = const Logo(variant: LogoVariant.symbol, height: 12);
    } else if (isFuture) {
      bg = Colors.transparent;
      border = faint;
      child = null;
    } else {
      // Past, missed.
      bg = Colors.transparent;
      border = muted.withValues(alpha: 0.35);
      child = null;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isToday ? ChocolatePalette.bg : muted,
            letterSpacing: 0.4,
            fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: isToday ? 1.6 : 1),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// Daily-ritual CTA. Painted with the user's global card style so the
/// home screen previews exactly what the ritual cards will look like
/// — ambient sparkles, vignette, theme background — and changing the
/// card style in Settings updates this card too.
class _RitualCta extends ConsumerWidget {
  const _RitualCta({
    required this.manifestations,
    required this.enabled,
    required this.onStart,
  });

  final AsyncValue<dynamic> manifestations;
  final bool enabled;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final count = manifestations.maybeWhen(
      data: (items) => (items as List).length,
      orElse: () => 0,
    );
    final hasAny = count > 0;

    final backdrop = CardBackdropTheme.fromId(
      ref.watch(immediateCardThemeIdProvider),
    );
    final isDark = backdrop.bg.computeLuminance() < 0.5;
    // Slightly stronger button background than the card itself: white
    // overlay on dark themes, black overlay on light themes. Keeps the
    // CTA visible without forcing a separate accent colour.
    final buttonBg = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    final buttonBgPressed = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.14);

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Stack(
        children: [
          // All backdrop layers are IgnorePointer so they never absorb
          // taps that should reach the CTA button.  ColoredBox defaults
          // to HitTestBehavior.opaque, and on Flutter web that fallback
          // hit target was intercepting taps near the button edges.
          Positioned.fill(
            child: IgnorePointer(child: ColoredBox(color: backdrop.bg)),
          ),
          Positioned.fill(
            child: CardAmbientDecoration(
              kind: backdrop.decoration,
              color: backdrop.text,
              intensity: 0.7,
            ),
          ),
          Positioned.fill(
            child: CardVignette(dark: isDark),
          ),
          // GestureDetector with opaque behavior ensures taps anywhere
          // inside the card bounds are routed to this subtree rather
          // than falling through to the (now-ignored) backdrop layers.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled && hasAny ? onStart : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
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
                          color: backdrop.text,
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
                      color: backdrop.text.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: ButtonStyle(
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(vertical: 16),
                      ),
                      backgroundColor:
                          WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.disabled)) {
                          return buttonBg.withValues(alpha: 0.4);
                        }
                        if (states.contains(WidgetState.pressed)) {
                          return buttonBgPressed;
                        }
                        return buttonBg;
                      }),
                      foregroundColor:
                          WidgetStatePropertyAll(backdrop.text),
                      overlayColor:
                          WidgetStatePropertyAll(buttonBgPressed),
                    ),
                    onPressed: enabled && hasAny ? onStart : null,
                    child: const Text('Start ritual'),
                  ),
                ],
              ),
            ),
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

/// First-run onboarding card. Visible only when:
///   - the user is signed in (Supabase configured),
///   - their library is empty,
///   - they haven't already imported the seed.
///
/// Offers two actions: import 12 starter manifestations, or open the
/// library to write their own. Once the user picks one, the card vanishes.
class _OnboardingCard extends ConsumerStatefulWidget {
  const _OnboardingCard({required this.manifestations});

  final AsyncValue<dynamic> manifestations;

  @override
  ConsumerState<_OnboardingCard> createState() => _OnboardingCardState();
}

class _OnboardingCardState extends ConsumerState<_OnboardingCard> {
  @override
  Widget build(BuildContext context) {
    final list = widget.manifestations.valueOrNull;
    if (list is! List || list.isNotEmpty) return const SizedBox.shrink();

    final profileAsync = ref.watch(userProfileProvider);
    final imported =
        profileAsync.valueOrNull?.settings.importedSeed ?? false;
    if (imported) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Material(
        color: Accents.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/onboarding'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Accents.gold.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Accents.gold,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Set up your manifestations',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.55),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'A short five-step walk through the areas of your '
                  'life. Write each one in your own words \u2014 about '
                  'three minutes.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
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
