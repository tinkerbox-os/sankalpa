import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/repositories/user_profile_repository.dart';
import 'package:sankalpa/widgets/card_ambient_decoration.dart';

/// Bottom-sheet picker for the single global card theme used across every
/// manifestation. Mirrors the pattern from `SoundscapePicker` so Settings
/// stays consistent.
class CardThemePicker {
  const CardThemePicker._();

  static Future<void> open(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Consumer(
          builder: (ctx, sheetRef, _) {
            // Highlight the user's stored anchor — NOT the effective
            // daily-shuffle theme. Otherwise the checkmark lands on
            // whatever today rolled, which isn't what the user picked.
            final prefs = sheetRef.watch(cardStylePrefsProvider).valueOrNull;
            final currentId = prefs?.themeId ?? 'chocolate';
            return SafeArea(
              child: SingleChildScrollView(
                // Seven swatches is four rows, which can outgrow a short
                // screen in landscape. The grid itself stays unscrollable so
                // the whole sheet moves as one.
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
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                      child: Text(
                        'Card style',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      child: Text(
                        'Applied across every manifestation.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 1.4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        for (final t in CardBackdropTheme.values)
                          _ThemeSwatch(
                            theme: t,
                            selected: t.id == currentId,
                            onTap: () async {
                              await sheetRef
                                  .read(userProfileRepositoryProvider)
                                  .updateSettings({'card_theme_id': t.id});
                              sheetRef
                                ..invalidate(userProfileProvider)
                                ..invalidate(cardStylePrefsProvider)
                                ..invalidate(globalCardThemeIdProvider);
                              if (sheetCtx.mounted) {
                                Navigator.pop(sheetCtx);
                              }
                            },
                          ),
                      ],
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

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final CardBackdropTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            width: selected ? 2.5 : 1,
            color: selected
                ? Accents.gold
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.md - 2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: theme.bg),
              Positioned.fill(
                child: CardAmbientDecoration(
                  kind: theme.decoration,
                  color: theme.text,
                  intensity: 0.9,
                ),
              ),
              Positioned.fill(
                child: CardVignette(
                  dark: theme.bg.computeLuminance() < 0.5,
                ),
              ),
              Center(
                child: Text(
                  theme.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.text,
                    fontFamily: 'Fraunces',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Accents.gold,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
