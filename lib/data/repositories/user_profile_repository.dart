import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:sankalpa/data/models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads & writes the per-user profile row (`user_profiles`).
///
/// The row is auto-created by the `handle_new_user` trigger on sign-up, so
/// we only have to read/update from the client.
class UserProfileRepository {
  UserProfileRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('UserProfileRepository called without an active session');
    }
    return id;
  }

  Future<UserProfile?> get() async {
    final row = await _client
        .from('user_profiles')
        .select()
        .eq('user_id', _uid)
        .maybeSingle();
    if (row == null) return null;
    return UserProfile.fromJson(Map<String, dynamic>.from(row));
  }

  /// Merges [partial] into the existing `settings` jsonb. We read the raw
  /// jsonb (not the typed model) so any keys we haven't migrated into the
  /// freezed model yet — e.g. `card_theme_id` — survive the round-trip.
  Future<UserProfile> updateSettings(Map<String, dynamic> partial) async {
    final current = await _client
        .from('user_profiles')
        .select('settings')
        .eq('user_id', _uid)
        .maybeSingle();
    final existing = current == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(
            (current['settings'] as Map?) ?? const {},
          );
    final merged = <String, dynamic>{...existing, ...partial};
    final row = await _client
        .from('user_profiles')
        .update({'settings': merged})
        .eq('user_id', _uid)
        .select()
        .single();
    return UserProfile.fromJson(Map<String, dynamic>.from(row));
  }

  /// Reads a single raw setting key (bypasses the typed model). Useful for
  /// settings that aren't worth a full model migration yet — e.g. the
  /// global card theme.
  Future<String?> getRawSetting(String key) async {
    final row = await _client
        .from('user_profiles')
        .select('settings')
        .eq('user_id', _uid)
        .maybeSingle();
    if (row == null) return null;
    final settings = (row['settings'] as Map?) ?? const {};
    final v = settings[key];
    return v?.toString();
  }

  /// Returns the entire raw settings jsonb. Convenient for screens that
  /// need to read several raw keys without round-tripping each.
  Future<Map<String, dynamic>> getRawSettings() async {
    final row = await _client
        .from('user_profiles')
        .select('settings')
        .eq('user_id', _uid)
        .maybeSingle();
    if (row == null) return const {};
    return Map<String, dynamic>.from((row['settings'] as Map?) ?? const {});
  }
}

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(Supabase.instance.client);
});

/// Reactive profile (re-fetches when auth changes or invalidated).
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  ref.watch(currentUserProvider);
  return ref.read(userProfileRepositoryProvider).get();
});

/// Convenience aggregate of card-style settings (raw jsonb).
class CardStylePrefs {
  const CardStylePrefs({
    required this.themeId,
    required this.shuffleDaily,
  });

  /// The user's manually picked theme id. Used when [shuffleDaily] is off,
  /// and as the "anchor" preview shown in the picker even when shuffle is on.
  final String themeId;

  /// When true, [globalCardThemeIdProvider] returns a date-deterministic
  /// theme id instead of [themeId], rotating once per day.
  final bool shuffleDaily;
}

/// Raw card-style preferences from the settings jsonb.
final cardStylePrefsProvider = FutureProvider<CardStylePrefs>((ref) async {
  ref.watch(currentUserProvider);
  final settings =
      await ref.read(userProfileRepositoryProvider).getRawSettings();
  return CardStylePrefs(
    themeId: (settings['card_theme_id'] as String?) ?? 'chocolate',
    shuffleDaily: settings['card_theme_shuffle_daily'] == true,
  );
});

/// Resolved global card theme id — what every card on every screen
/// should actually paint with. Honours the daily-shuffle toggle so
/// users get a different theme each day without ever flipping mid-ritual.
///
/// Centralizing this means we don't honour the per-row `theme_id` column
/// anymore. That column is kept in case Phase 2 brings back per-card
/// variation (e.g. AI-themed cards), but the UI no longer offers it.
final globalCardThemeIdProvider = FutureProvider<String>((ref) async {
  final prefs = await ref.watch(cardStylePrefsProvider.future);
  if (!prefs.shuffleDaily) return prefs.themeId;
  // Deterministic rotation: same day → same theme, so the look is
  // stable across the entire day (no flip mid-ritual at midnight is
  // fine; we want today to feel consistent end-to-end).
  final today = DateTime.now();
  final dayOfYear =
      today.difference(DateTime(today.year)).inDays;
  final ids = CardBackdropTheme.values.map((t) => t.id).toList();
  return ids[dayOfYear % ids.length];
});
