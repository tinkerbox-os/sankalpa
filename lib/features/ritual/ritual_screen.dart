import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sankalpa/app/platform/browser_theme_color.dart';
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
  const RitualScreen({super.key, this.initialThemeId});

  /// Colour already shown on the Today CTA. When set, the ritual locks to it
  /// for the whole session so a provider reload cannot flash chocolate.
  final String? initialThemeId;

  @override
  ConsumerState<RitualScreen> createState() => _RitualScreenState();
}

class _RitualScreenState extends ConsumerState<RitualScreen> {
  final _pageCtrl = PageController();
  late final DateTime _startedAt;
  late final String _lockedThemeId;
  late final RitualAudioService _audio;
  int _currentIndex = 0;
  int _maxIndexReached = 0;
  bool _completed = false;
  String? _chromeThemeId;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    // Cache before dispose — Riverpod forbids ref after the element unmounts.
    _audio = ref.read(ritualAudioProvider);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    // Lock the colour before the first frame. Prefer the id Today handed us
    // via the route — that is already what the user was looking at — and only
    // fall back to the cache-backed provider when Ritual is opened directly.
    _lockedThemeId =
        widget.initialThemeId ?? ref.read(immediateCardThemeIdProvider);
    _chromeThemeId = _lockedThemeId;
    _setSystemChrome(CardBackdropTheme.fromId(_lockedThemeId).bg);
    // Persist so the next cold start opens on today's colour even before the
    // profile round-trip completes.
    unawaited(
      cacheResolvedCardThemeId(
        ref.read(sharedPreferencesProvider),
        _lockedThemeId,
      ),
    );
    // Today already refreshed the manifestation list inside the Start tap
    // handler. Re-refreshing here put the provider into AsyncLoading and
    // blanked the cards for a beat; skip that and keep the warm cache.
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _setSystemChrome(CreamPalette.bg, edgeTints: false);
    _pageCtrl.dispose();
    // Stop music when leaving (don't dispose the service - it's a singleton).
    unawaited(_audio.stop());
    super.dispose();
  }

  void _syncSystemChrome(String themeId) {
    if (_chromeThemeId == themeId) return;
    _chromeThemeId = themeId;
    final color = CardBackdropTheme.fromId(themeId).bg;

    // Changing browser metadata while Flutter is building can race the web
    // engine's own DOM updates. Apply it immediately after this frame; the id
    // guard prevents an older queued update winning if the provider changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _chromeThemeId != themeId) return;
      _setSystemChrome(color);
    });
  }

  void _setSystemChrome(Color color, {bool edgeTints = true}) {
    // Edge tints are ritual-only: they tell Safari 26 what colour to paint
    // its toolbars, but must not outlive the ritual or they sit under/over
    // Flutter's text-input overlay and the sign-in keyboard never opens.
    setBrowserThemeColor(_cssColor(color), edgeTints: edgeTints);
    final iconBrightness =
        color.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: color,
        statusBarIconBrightness: iconBrightness,
        // iOS describes the bar background rather than its icons, so this is
        // intentionally the inverse of statusBarIconBrightness.
        statusBarBrightness: iconBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: color,
        systemNavigationBarIconBrightness: iconBrightness,
      ),
    );
  }

  String _cssColor(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
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
        pageBuilder: (ctx, anim, _) => RitualCompleteScreen(
          cardsRead: _maxIndexReached + 1,
          duration: duration,
          themeId: _lockedThemeId,
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
    // Session-locked in initState — do not re-watch the theme provider here
    // or a late profile emission can still repaint chocolate mid-entry.
    final backdrop = CardBackdropTheme.fromId(_lockedThemeId);
    _syncSystemChrome(_lockedThemeId);

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
      // Match the card so any loading/error/safe-area gap is the same colour
      // the user already saw on the Today preview, not a black flash.
      backgroundColor: backdrop.bg,
      body: manifestations.when(
        // Keep the previous card list on screen if something re-fetches;
        // a loading spinner on chocolate was part of the entry flash.
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => Center(
          child: CircularProgressIndicator(color: backdrop.text),
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
                  themeId: _lockedThemeId,
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

/// Full-screen completion view shown after the last card. Same calm register
/// as the ritual itself — no jarring jump back to a bright sheet.
///
/// Public so widget tests can guard against hard-coding chocolate here.
class RitualCompleteScreen extends StatelessWidget {
  const RitualCompleteScreen({
    required this.cardsRead,
    required this.duration,
    required this.themeId,
    required this.onDone,
    super.key,
  });

  final int cardsRead;
  final Duration duration;
  final String themeId;
  final VoidCallback onDone;

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final backdrop = CardBackdropTheme.fromId(themeId);
    final isDark = backdrop.bg.computeLuminance() < 0.5;
    // Keep the Done button readable on both the dark mid-tones and the
    // light pastels without introducing a third accent colour.
    final buttonBg = isDark
        ? Colors.white.withValues(alpha: 0.95)
        : Colors.black.withValues(alpha: 0.88);
    final buttonFg = isDark ? backdrop.bg : backdrop.text;

    return Scaffold(
      backgroundColor: backdrop.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CardAmbientDecoration(
            kind: backdrop.decoration,
            color: backdrop.text,
            intensity: 0.55,
          ),
          CardVignette(dark: isDark),
          SafeArea(
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
                  Text(
                    'Beautiful.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: backdrop.text,
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
                      color: backdrop.text.withValues(alpha: 0.72),
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
                        backgroundColor: buttonBg,
                        foregroundColor: buttonFg,
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
        ],
      ),
    );
  }
}
