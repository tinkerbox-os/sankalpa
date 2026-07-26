import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/audio/ritual_audio_service.dart';
import 'package:sankalpa/data/errors/app_error.dart';
import 'package:sankalpa/data/models/manifestation.dart';
import 'package:sankalpa/data/repositories/manifestation_repository.dart';
import 'package:sankalpa/data/repositories/session_repository.dart';
import 'package:sankalpa/data/repositories/soundscape_repository.dart';
import 'package:sankalpa/data/repositories/user_profile_repository.dart';
import 'package:sankalpa/widgets/card_ambient_decoration.dart';

/// Full-screen daily ritual. Auto-plays a soundscape, shows manifestations
/// one card at a time, and records a `sessions` row on completion.
///
/// UX rules from the brief:
/// - Tap or swipe to advance. No auto-advance — user controls pace.
/// - Music starts on entry. Mute toggle persists across sessions.
/// - Subtle breath animation behind the text (4s in, 4s out).
/// - Light haptic tick on each card change.
/// - Only chrome on screen: an exit "X" and the mute toggle.
class RitualScreen extends ConsumerStatefulWidget {
  const RitualScreen({super.key});

  @override
  ConsumerState<RitualScreen> createState() => _RitualScreenState();
}

class _RitualScreenState extends ConsumerState<RitualScreen> {
  final _pageCtrl = PageController();
  late final DateTime _startedAt;
  int _currentIndex = 0;
  int _maxIndexReached = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    // Force a fresh fetch every time the ritual screen opens. Riverpod's
    // FutureProvider will otherwise hand back the cached AsyncData from
    // a previous mount, which means a reorder saved in Library wouldn't
    // show up here until the app is fully restarted. The invalidate
    // schedules a rebuild + refetch on the next frame, so the user sees
    // the freshest order possible without an explicit pull-to-refresh
    // gesture (there isn't one here — the screen is full-bleed).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.refresh(manifestationsProvider.future));
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageCtrl.dispose();
    // Stop music when leaving (don't dispose the service - it's a singleton).
    ref.read(ritualAudioProvider).stop();
    super.dispose();
  }

  Future<void> _onPageChanged(int i) async {
    setState(() {
      _currentIndex = i;
      if (i > _maxIndexReached) _maxIndexReached = i;
    });
    await HapticFeedback.lightImpact();
  }

  Future<void> _advance(int total) async {
    if (_currentIndex >= total - 1) {
      await _finish(total);
      return;
    }
    await _pageCtrl.nextPage(
      duration: Motion.normal,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish(int total) async {
    if (_completed) return;
    _completed = true;
    // Stop the soundscape immediately on completion. dispose() will also
    // call stop(), but on Flutter web the navigation away from this route
    // can lag behind, so the music keeps playing for a beat. Belt + braces.
    await ref.read(ritualAudioProvider).stop();
    final duration = DateTime.now().difference(_startedAt);
    try {
      await ref.read(sessionRepositoryProvider).recordCompleted(
            cardsRead: _maxIndexReached + 1,
            duration: duration,
          );
      // Refresh the streak on the Today screen.
      ref.invalidate(streakStatsProvider);
    } on Object {
      // Recording is best-effort; never block the user from exiting.
    }
    if (!mounted) return;
    await _showFinishedSheet(duration);
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _exit() async {
    await ref.read(ritualAudioProvider).stop();
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _showFinishedSheet(Duration duration) async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 480),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (ctx, anim, _) => _RitualCompleteScreen(
          cardsRead: _maxIndexReached + 1,
          duration: duration,
          onDone: () => Navigator.of(ctx).pop(),
        ),
        transitionsBuilder: (_, anim, _, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manifestations = ref.watch(manifestationsProvider);
    final defaultSound = ref.watch(defaultSoundscapeProvider);
    final audio = ref.watch(ritualAudioProvider);
    final globalThemeId =
        ref.watch(globalCardThemeIdProvider).valueOrNull ?? 'chocolate';

    // Kick off the default soundscape once it resolves. Idempotent — load()
    // no-ops if the URL is unchanged.
    defaultSound.whenData((s) {
      if (s != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          audio.load(s.url);
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: manifestations.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (e, st) => _ErrorView(error: AppError.from(e, st)),
        data: (items) {
          if (items.isEmpty) return const _EmptyRitual();

          return Stack(
            children: [
              PageView.builder(
                controller: _pageCtrl,
                itemCount: items.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, i) => _ManifestationCard(
                  manifestation: items[i],
                  themeId: globalThemeId,
                  onTap: () => _advance(items.length),
                ),
              ),
              // Hairline progress strip stays pinned to the very top edge
              // so it reads as a system-level indicator independent of the
              // controls below.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _ProgressStrip(
                  currentIndex: _currentIndex,
                  total: items.length,
                ),
              ),
              // Controls live at the bottom-right ("I am" pattern): out of
              // the eye-line for the manifestation text, thumb-reachable on
              // mobile.
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _BottomControls(
                  audio: audio,
                  onMuteToggle: () async {
                    await audio.setMuted(muted: !audio.isMuted);
                    setState(() {});
                  },
                  onExit: _exit,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One full-screen card. Tap anywhere = advance.
class _ManifestationCard extends StatelessWidget {
  const _ManifestationCard({
    required this.manifestation,
    required this.themeId,
    required this.onTap,
  });

  final Manifestation manifestation;
  final String themeId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backdrop = CardBackdropTheme.fromId(themeId);
    final hasImage = manifestation.backdropType == BackdropType.image &&
        (manifestation.imageUrl?.isNotEmpty ?? false);
    final textColor = hasImage ? Colors.white : backdrop.text;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ColoredBox(
        color: backdrop.bg,
        child: Stack(
          children: [
            // Backdrop layer: photo (if attached) or breath halo on the
            // theme colour. The photo is darkened with a top→bottom
            // gradient to keep manifestation text legible regardless of
            // what was uploaded (sky photos, busy textures, etc.).
            if (hasImage) ...[
              Positioned.fill(
                child: Image.network(
                  manifestation.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x66000000),
                        Color(0x99000000),
                        Color(0xCC000000),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ] else ...[
              const Positioned.fill(child: _BreathHalo()),
              Positioned.fill(
                child: CardAmbientDecoration(
                  kind: backdrop.decoration,
                  color: backdrop.text,
                ),
              ),
              Positioned.fill(
                child: CardVignette(
                  dark: backdrop.bg.computeLuminance() < 0.5,
                ),
              ),
            ],
            // Text fills the screen "I am"-style: large target size,
            // tight line height, minimal padding — and FittedBox auto-
            // shrinks long manifestations so they never clip. Bottom
            // padding leaves clearance for the exit/mute controls.
            //
            // GoogleFonts.cormorantGaramond (not raw fontFamily) so the
            // font is guaranteed registered with the requested weight
            // before first paint. Garalde-style serif chosen to mirror
            // the editorial feel of the "I am" affirmation app — wider
            // letterforms, ball terminals, classical proportions.
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 56, 28, 96),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          MediaQuery.sizeOf(context).width - 56,
                    ),
                    child: Text(
                      manifestation.text,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cormorantGaramond(
                        color: textColor,
                        fontSize: 56,
                        fontWeight: FontWeight.w500,
                        height: 1.18,
                        letterSpacing: 0,
                        shadows: hasImage
                            ? const [
                                Shadow(
                                  blurRadius: 12,
                                  color: Color(0xAA000000),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slow-pulsing radial halo behind the text — 4s inhale, 4s exhale.
///
/// Pure-Flutter animation, no extra deps. Opacity barely shifts (0.0 → 0.12)
/// so it reads as ambient breath, not a distracting effect.
class _BreathHalo extends StatefulWidget {
  const _BreathHalo();

  @override
  State<_BreathHalo> createState() => _BreathHaloState();
}

class _BreathHaloState extends State<_BreathHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: Breath.inhaleSec),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        // Multiple stops + low alpha avoid the visible concentric rings
        // Flutter web's CanvasKit produces with two-stop radial gradients.
        final peak = 0.03 + 0.05 * t;
        return IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.1,
                stops: const [0.0, 0.35, 0.7, 1.0],
                colors: [
                  Colors.white.withValues(alpha: peak),
                  Colors.white.withValues(alpha: peak * 0.55),
                  Colors.white.withValues(alpha: peak * 0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom-right control cluster: mute toggle + exit X.
///
/// "I am"-style: kept low and to the right so the manifestation text
/// dominates the upper visual field and the controls are within thumb
/// reach on mobile. Icons are small, translucent, and dressed with a
/// soft bottom-edge gradient so they remain legible on both light and
/// dark backdrops without painting a hard chrome bar.
class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.audio,
    required this.onMuteToggle,
    required this.onExit,
  });

  final RitualAudioService audio;
  final VoidCallback onMuteToggle;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Soft gradient lifts the icons off bright/busy backdrops without
        // drawing a visible bar. IgnorePointer so taps in this band still
        // reach the PageView for advancing.
        const IgnorePointer(
          child: SizedBox(
            height: 80,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x40000000),
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            // Split across the bottom edge: exit on the left (deliberate
            // reach, mirrors the iOS back-gesture origin), mute on the
            // right (under the resting thumb for quick toggling without
            // breaking the ritual flow).
            child: Row(
              children: [
                _ChromeButton(
                  icon: Icons.close,
                  onTap: onExit,
                  tooltip: 'Exit ritual',
                ),
                const Spacer(),
                _MuteButton(audio: audio, onTap: onMuteToggle),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Mute / unmute button with a thin progress ring while audio is buffering.
///
/// Listens to two things:
///  1. `audio` itself (a `ChangeNotifier`) — fires on mute toggle so the
///     icon flips immediately.
///  2. `audio.playerStateStream` — fires while buffering so the spinner
///     ring shows up around the icon during download.
class _MuteButton extends StatefulWidget {
  const _MuteButton({required this.audio, required this.onTap});

  final RitualAudioService audio;
  final VoidCallback onTap;

  @override
  State<_MuteButton> createState() => _MuteButtonState();
}

class _MuteButtonState extends State<_MuteButton> {
  @override
  void initState() {
    super.initState();
    widget.audio.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.audio.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isMuted = widget.audio.isMuted;
    return StreamBuilder<PlayerState>(
      stream: widget.audio.playerStateStream,
      builder: (context, snap) {
        final state = snap.data?.processingState;
        // Only show the buffering ring when audio is actually expected to
        // be playing — otherwise tapping mute (which pauses) would briefly
        // flash a spinner.
        final loading = !isMuted &&
            (state == ProcessingState.loading ||
                state == ProcessingState.buffering);
        return SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white70),
                  ),
                ),
              _ChromeButton(
                icon: isMuted ? Icons.volume_off : Icons.volume_up,
                onTap: widget.onTap,
                tooltip: isMuted ? 'Unmute' : 'Mute',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChromeButton extends StatelessWidget {
  const _ChromeButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.22),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.85),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

/// 2px progress bar pinned to the very top edge. Replaces the row of dots
/// so we never tile dozens of pips for big libraries and the icons get
/// their own breathing room on either side of the row.
class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.currentIndex, required this.total});

  final int currentIndex;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    final fraction = ((currentIndex + 1) / total).clamp(0.0, 1.0);
    return SizedBox(
      height: 2,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: Colors.white.withValues(alpha: 0.12)),
          ),
          FractionallySizedBox(
            widthFactor: fraction,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRitual extends StatelessWidget {
  const _EmptyRitual();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'Add a manifestation first',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Fraunces',
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).maybePop().then((_) {}),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final AppError error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, color: Colors.white70, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Couldn\u2019t load your manifestations.',
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error.message,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen completion view shown after the last card. Same dark, calm
/// register as the ritual itself — no jarring jump back to a bright sheet.
class _RitualCompleteScreen extends StatelessWidget {
  const _RitualCompleteScreen({
    required this.cardsRead,
    required this.duration,
    required this.onDone,
  });

  final int cardsRead;
  final Duration duration;
  final VoidCallback onDone;

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1612),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.auto_awesome,
                size: 56,
                color: Accents.gold.withValues(alpha: 0.95),
              ),
              const SizedBox(height: 28),
              const Text(
                'Beautiful.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Fraunces',
                  fontSize: 36,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'You showed up for $cardsRead manifestation${cardsRead == 1 ? '' : 's'}\nin ${_formatDuration(duration)}.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontFamily: 'Inter',
                  fontSize: 15,
                  height: 1.5,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.95),
                    foregroundColor: const Color(0xFF1F1612),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: onDone,
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                    ),
                  ),
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
