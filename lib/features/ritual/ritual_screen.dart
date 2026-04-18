import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/audio/ritual_audio_service.dart';
import 'package:sankalpa/data/models/manifestation.dart';
import 'package:sankalpa/data/repositories/manifestation_repository.dart';
import 'package:sankalpa/data/repositories/session_repository.dart';
import 'package:sankalpa/data/repositories/soundscape_repository.dart';

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
        error: (e, _) => _ErrorView(message: e.toString()),
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
                  onTap: () => _advance(items.length),
                ),
              ),
              // Pin chrome to the top. Without explicit Positioned the
              // unpositioned Stack child fills the available space and the
              // Row's default crossAxis center alignment drops the buttons
              // straight onto the manifestation text.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _Chrome(
                  isMuted: audio.isMuted,
                  onMuteToggle: () async {
                    await audio.setMuted(muted: !audio.isMuted);
                    setState(() {});
                  },
                  onExit: _exit,
                  currentIndex: _currentIndex,
                  total: items.length,
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
    required this.onTap,
  });

  final Manifestation manifestation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backdrop = CardBackdropTheme.fromId(manifestation.themeId);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ColoredBox(
        color: backdrop.bg,
        child: Stack(
          children: [
            const Positioned.fill(child: _BreathHalo()),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 96,
                ),
                child: Text(
                  manifestation.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: backdrop.text,
                    fontFamily: 'Fraunces',
                    fontSize: 32,
                    height: 1.35,
                    letterSpacing: 0.2,
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

/// Top chrome: exit X (left), progress dots (center), mute toggle (right).
class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.isMuted,
    required this.onMuteToggle,
    required this.onExit,
    required this.currentIndex,
    required this.total,
  });

  final bool isMuted;
  final VoidCallback onMuteToggle;
  final VoidCallback onExit;
  final int currentIndex;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Row(
          children: [
            _ChromeButton(
              icon: Icons.close,
              onTap: onExit,
              tooltip: 'Exit ritual',
            ),
            Expanded(
              child: Center(
                child:
                    _ProgressBar(currentIndex: currentIndex, total: total),
              ),
            ),
            _ChromeButton(
              icon: isMuted ? Icons.volume_off : Icons.volume_up,
              onTap: onMuteToggle,
              tooltip: isMuted ? 'Unmute' : 'Mute',
            ),
          ],
        ),
      ),
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
        color: Colors.black.withValues(alpha: 0.18),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Progress indicator. Up to 12 manifestations: render one dot per card,
/// active card filled and slightly larger. More than that: fall back to a
/// minimal numeric "current / total" so we don't tile a hundred dots.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.currentIndex, required this.total});

  final int currentIndex;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();

    if (total > 12) {
      return Text(
        '${currentIndex + 1} / $total',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontFamily: 'Inter',
          letterSpacing: 0.4,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isActive = i == currentIndex;
        final isPast = i < currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive || isPast
                ? Colors.white.withValues(alpha: isActive ? 0.95 : 0.65)
                : Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
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
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Couldn\u2019t load your manifestations:\n$message',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
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
