import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/supabase_config.dart';
import 'package:sankalpa/widgets/logo.dart';

/// Placeholder Today / Home screen.
///
/// Real implementation lands in subsequent Phase 1 tasks
/// (`ritual-mode`, `streaks-reminders`). For the scaffold sign-off we only
/// need to confirm the theme, fonts, logo, and routing all wire up cleanly.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Logo(height: 36),
              const SizedBox(height: 48),
              if (!SupabaseConfig.isConfigured) const _UnconfiguredBanner(),
              const SizedBox(height: 24),
              Text(
                'Your daily ritual',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Sankalpa keeps your manifestations in one calm place. The full ritual lands shortly — this is the scaffold sign-off screen.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 48),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: ChocolatePalette.bgElevated,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'I am bringing what I need\ninto being.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fraunces(
                        fontSize: TypeScale.manifestationMobile,
                        fontWeight: FontWeight.w400,
                        height: TypeScale.manifestationLineHeight,
                        letterSpacing: TypeScale.manifestationLetterSpacing,
                        color: ChocolatePalette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Logo(
                      variant: LogoVariant.symbol,
                      height: 28,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Center(
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('Start ritual (coming soon)'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
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
              'Supabase not configured — pass --dart-define=SUPABASE_URL=… and --dart-define=SUPABASE_ANON_KEY=…',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
