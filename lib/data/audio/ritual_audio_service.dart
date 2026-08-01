import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single-track looping background audio for ritual mode.
///
/// Owns one `just_audio` player. Soundscape URL can be set via [load], and the
/// mute preference is persisted to `SharedPreferences` so the user's choice
/// survives app restarts (per the brief).
///
/// Extends [ChangeNotifier] so the UI can rebuild when mute state flips —
/// `setVolume(0)` alone doesn't fire `playerStateStream`, which is why the
/// mute icon appeared "stuck" before. We also use `pause`/`play` instead of
/// just `setVolume` because some web browsers ignore `volume = 0` on a
/// looping HLS stream.
class RitualAudioService extends ChangeNotifier {
  RitualAudioService(this._prefs)
      : _player = AudioPlayer(),
        _muted = _prefs.getBool(_kMutedKey) ?? false;

  static const _kMutedKey = 'sankalpa.ritual.muted';

  final SharedPreferences _prefs;
  final AudioPlayer _player;
  bool _muted;
  String? _currentUrl;
  bool _disposed = false;

  bool get isMuted => _muted;

  /// URL most recently passed to [load] or [playPreview]. `null` if nothing
  /// has been loaded yet (or after [stop]).
  String? get currentUrl => _currentUrl;

  /// Whether the underlying player is actively playing audio right now.
  /// Useful for the soundscape picker to show a play/pause indicator on
  /// the tile that's currently previewing.
  bool get isPlaying => _player.playing;

  /// Emits whenever the underlying player's state changes (loading,
  /// buffering, ready, etc.). The chrome listens to this to show a thin
  /// progress ring around the mute icon while audio is being fetched.
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Convenience: `true` when the player is downloading/buffering audio.
  bool get isLoading {
    final s = _player.processingState;
    return s == ProcessingState.loading || s == ProcessingState.buffering;
  }

  /// Loads a soundscape URL and starts looping playback (unless muted).
  ///
  /// Safe to call repeatedly with the same URL — no-ops in that case.
  /// Placeholder URLs (containing `placeholder.local`) are silently skipped
  /// so the rest of ritual mode keeps working before real audio is wired up.
  Future<void> load(String? url) async {
    if (url == null || url.isEmpty) return;
    if (url.contains('placeholder.local')) return;
    if (url == _currentUrl) return;
    _currentUrl = url;
    try {
      await _player.setUrl(url);
      await _player.setLoopMode(LoopMode.all);
      await _player.setVolume(1);
      if (_muted) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } on Object {
      // Audio failures shouldn't crash the ritual.
    }
  }

  Future<void> setMuted({required bool muted}) async {
    if (muted == _muted) return;
    _muted = muted;
    await _prefs.setBool(_kMutedKey, muted);
    notifyListeners();
    try {
      // Belt + braces: drop volume immediately so even if pause is rejected
      // (e.g. some headless test envs), audio stops being audible.
      await _player.setVolume(muted ? 0 : 1);
      if (muted) {
        await _player.pause();
      } else if (_currentUrl != null) {
        await _player.play();
      }
    } on Object {
      // Toggling failed — leave the flag set; user can retry.
    }
  }

  /// Plays [url] right now, ignoring the persisted mute preference. Used
  /// by the soundscape picker for sample previews \u2014 we always want the
  /// user to actually hear the track when they tap it, even if their
  /// ritual is normally muted. Doesn't touch the mute flag, so the next
  /// ritual still respects it.
  Future<void> playPreview(String url) async {
    if (url.isEmpty || url.contains('placeholder.local')) return;
    try {
      if (url != _currentUrl) {
        _currentUrl = url;
        await _player.setUrl(url);
        await _player.setLoopMode(LoopMode.all);
      }
      await _player.setVolume(1);
      await _player.play();
      notifyListeners();
    } on Object {
      // Audio failures shouldn't crash the picker.
    }
  }

  /// Pauses playback without clearing the loaded URL. Use [stop] to also
  /// release the URL.
  Future<void> pause() async {
    try {
      await _player.pause();
      notifyListeners();
    } on Object {
      // Best-effort; UI is already updated.
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } on Object {
      // Best-effort; ritual exit must not throw.
    }
    if (_disposed) return;
    _currentUrl = null;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    super.dispose();
    await _player.dispose();
  }
}

/// Eagerly-initialized prefs handle. Created in main() and overridden here.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPreferencesProvider in main()');
});

final ritualAudioProvider = Provider<RitualAudioService>((ref) {
  final svc = RitualAudioService(ref.watch(sharedPreferencesProvider));
  ref.onDispose(svc.dispose);
  return svc;
});
