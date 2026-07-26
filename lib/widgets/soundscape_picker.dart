import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/audio/ritual_audio_service.dart';
import 'package:sankalpa/data/models/soundscape.dart';
import 'package:sankalpa/data/repositories/soundscape_repository.dart';
import 'package:sankalpa/data/repositories/user_profile_repository.dart';

/// Bottom-sheet soundscape picker used by both the Today quick-actions
/// row and the Settings screen.
///
/// Each row has its own play/pause control so the user can audition a
/// track before committing to it. Tapping the rest of the row commits it
/// as the new default and closes the sheet. Audio is paused on close so
/// previews don't bleed onto Today.
class SoundscapePicker {
  const SoundscapePicker._();

  static Future<void> open(BuildContext context, WidgetRef ref) async {
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
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                      child: Text(
                        'Choose your soundscape',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Text(
                        'Tap a row to preview. Use \u201cSet\u201d to make it your default.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    list.when(
                      data: (items) => Column(
                        children: [
                          for (final s in items)
                            _SoundscapeTile(
                              soundscape: s,
                              selected: s.id == current?.id,
                              onSelect: () async {
                                await sheetRef
                                    .read(ritualAudioProvider)
                                    .pause();
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
    // Sheet closed (drag-down, tap-outside, or explicit Navigator.pop in
    // the tile's onSelect). Stop any preview audio so it doesn't keep
    // playing on the screen behind the sheet.
    await ref.read(ritualAudioProvider).pause();
  }
}

class _SoundscapeTile extends ConsumerStatefulWidget {
  const _SoundscapeTile({
    required this.soundscape,
    required this.selected,
    required this.onSelect,
  });

  final Soundscape soundscape;
  final bool selected;
  final VoidCallback onSelect;

  @override
  ConsumerState<_SoundscapeTile> createState() => _SoundscapeTileState();
}

class _SoundscapeTileState extends ConsumerState<_SoundscapeTile> {
  late final RitualAudioService _audio;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(ritualAudioProvider);
    _audio.addListener(_onChange);
  }

  @override
  void dispose() {
    _audio.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  bool get _isThisPlaying =>
      _audio.currentUrl == widget.soundscape.url && _audio.isPlaying;

  bool get _isPlaceholder =>
      widget.soundscape.url.contains('placeholder.local') ||
      widget.soundscape.url.isEmpty;

  Future<void> _togglePreview() async {
    if (_isPlaceholder) return;
    if (_isThisPlaying) {
      await _audio.pause();
    } else {
      await _audio.playPreview(widget.soundscape.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = _isThisPlaying && _audio.isLoading;
    return Material(
      color: widget.selected
          ? theme.colorScheme.onSurface.withValues(alpha: 0.04)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        // The whole row toggles the preview — much easier hit target on
        // mobile than the small leading icon, and matches the user's
        // mental model of "tap the song to play it".
        onTap: _isPlaceholder ? null : _togglePreview,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Accents.gold),
                        ),
                      ),
                    Icon(
                      _isThisPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_outline,
                      color: _isPlaceholder
                          ? theme.colorScheme.onSurface
                              .withValues(alpha: 0.25)
                          : Accents.gold,
                      size: 30,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.soundscape.name,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isPlaceholder
                          ? '${_subtitleFor(widget.soundscape.kind)} \u2014 not available yet'
                          : _isThisPlaying
                              ? 'Playing preview'
                              : _subtitleFor(widget.soundscape.kind),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (widget.selected)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Accents.gold, size: 18),
                      SizedBox(width: 4),
                      Text(
                        'Default',
                        style: TextStyle(
                          color: Accents.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                )
              else
                FilledButton.tonal(
                  onPressed: _isPlaceholder ? null : widget.onSelect,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Set'),
                ),
            ],
          ),
        ),
      ),
    );
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
