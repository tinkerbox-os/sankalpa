import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single-track looping background audio for ritual mode.
///
/// Owns one `just_audio` player. Soundscape URL can be set via [load], and the
/// mute preference is persisted to `SharedPreferences` so the user's choice
/// survives app restarts (per the brief).
class RitualAudioService {
  RitualAudioService(this._prefs)
      : _player = AudioPlayer(),
        _muted = _prefs.getBool(_kMutedKey) ?? false;

  static const _kMutedKey = 'sankalpa.ritual.muted';

  final SharedPreferences _prefs;
  final AudioPlayer _player;
  bool _muted;
  String? _currentUrl;

  bool get isMuted => _muted;

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
      await _player.setVolume(_muted ? 0 : 1);
      await _player.play();
    } on Object {
      // Audio failures shouldn't crash the ritual.
    }
  }

  Future<void> setMuted({required bool muted}) async {
    _muted = muted;
    await _prefs.setBool(_kMutedKey, muted);
    await _player.setVolume(muted ? 0 : 1);
  }

  Future<void> stop() async {
    await _player.stop();
    _currentUrl = null;
  }

  Future<void> dispose() async {
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
