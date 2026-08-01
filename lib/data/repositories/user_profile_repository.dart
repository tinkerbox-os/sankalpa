import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/audio/ritual_audio_service.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:sankalpa/data/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Local cache of card-style prefs. Lets the ritual paint the correct colour
/// on the first frame instead of flashing the chocolate default while the
/// Supabase profile round-trip completes (or while Riverpod re-creates the
/// FutureProvider after the Today screen stops listening during navigation).
const _cachedThemeIdKey = 'card_theme_id';
const _cachedShuffleKey = 'card_theme_shuffle_daily';
const _resolvedThemeIdKey = 'card_theme_resolved_id';
const _resolvedThemeDayKey = 'card_theme_resolved_day';

/// Pure resolver used by both the network-backed provider and the
/// SharedPreferences-backed immediate provider. Kept free of I/O so the
/// weekday rotation can be unit-tested without Flutter bindings.
String resolveCardThemeId({
  required String themeId,
  required bool shuffleDaily,
  DateTime? now,
}) {
  if (!shuffleDaily) return themeId;
  final today = now ?? DateTime.now();
  final dayOfYear = today.difference(DateTime(today.year)).inDays;
  final ids = CardBackdropTheme.values.map((t) => t.id).toList();
  return ids[dayOfYear % ids.length];
}

String _calendarDayKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

Future<void> cacheCardStylePrefs(
  SharedPreferences sp,
  CardStylePrefs prefs,
) async {
  await sp.setString(_cachedThemeIdKey, prefs.themeId);
  await sp.setBool(_cachedShuffleKey, prefs.shuffleDaily);
}

/// Persists the colour the UI should open with today. Stored separately from
/// the pinned prefs so a cold start with shuffle-on does not briefly resolve
/// to chocolate (the pinned default) before the profile round-trip lands.
Future<void> cacheResolvedCardThemeId(
  SharedPreferences sp,
  String themeId, {
  DateTime? now,
}) async {
  final day = now ?? DateTime.now();
  await sp.setString(_resolvedThemeIdKey, themeId);
  await sp.setString(_resolvedThemeDayKey, _calendarDayKey(day));
}

CardStylePrefs cardStylePrefsFromCache(SharedPreferences sp) {
  return CardStylePrefs(
    themeId: sp.getString(_cachedThemeIdKey) ?? 'chocolate',
    shuffleDaily: sp.getBool(_cachedShuffleKey) ?? false,
  );
}

/// Today's previously resolved colour, or null when the cache is from
/// another calendar day / has never been written.
String? resolvedCardThemeIdFromCache(
  SharedPreferences sp, {
  DateTime? now,
}) {
  final day = now ?? DateTime.now();
  if (sp.getString(_resolvedThemeDayKey) != _calendarDayKey(day)) {
    return null;
  }
  return sp.getString(_resolvedThemeIdKey);
}

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
  // Survive the brief gap between Today unmounting and Ritual mounting —
  // without this, Riverpod disposes the FutureProvider the moment the last
  // listener leaves, and Ritual remounts into a loading chocolate flash.
  ref
    ..keepAlive()
    ..watch(currentUserProvider);
  final settings =
      await ref.read(userProfileRepositoryProvider).getRawSettings();
  final prefs = CardStylePrefs(
    themeId: (settings['card_theme_id'] as String?) ?? 'chocolate',
    shuffleDaily: settings['card_theme_shuffle_daily'] == true,
  );
  final sp = ref.read(sharedPreferencesProvider);
  await cacheCardStylePrefs(sp, prefs);
  await cacheResolvedCardThemeId(
    sp,
    resolveCardThemeId(
      themeId: prefs.themeId,
      shuffleDaily: prefs.shuffleDaily,
    ),
  );
  return prefs;
});

/// Resolved global card theme id — what every card on every screen
/// should actually paint with. Honours the daily-shuffle toggle so
/// users get a different theme each day without ever flipping mid-ritual.
///
/// Centralizing this means we don't honour the per-row `theme_id` column
/// anymore. That column is kept in case Phase 2 brings back per-card
/// variation (e.g. AI-themed cards), but the UI no longer offers it.
final globalCardThemeIdProvider = FutureProvider<String>((ref) async {
  ref.keepAlive();
  final prefs = await ref.watch(cardStylePrefsProvider.future);
  final id = resolveCardThemeId(
    themeId: prefs.themeId,
    shuffleDaily: prefs.shuffleDaily,
  );
  await cacheResolvedCardThemeId(
    ref.read(sharedPreferencesProvider),
    id,
  );
  return id;
});

/// Theme id available on the first build frame.
///
/// Order of preference:
/// 1. Live [globalCardThemeIdProvider] when already resolved
/// 2. Today's previously resolved colour from SharedPreferences
/// 3. Recompute from cached pinned prefs (may still be chocolate on a
///    brand-new install before the first profile fetch)
final immediateCardThemeIdProvider = Provider<String>((ref) {
  final live = ref.watch(globalCardThemeIdProvider).valueOrNull;
  if (live != null) return live;
  final sp = ref.watch(sharedPreferencesProvider);
  final resolved = resolvedCardThemeIdFromCache(sp);
  if (resolved != null) return resolved;
  final cached = cardStylePrefsFromCache(sp);
  return resolveCardThemeId(
    themeId: cached.themeId,
    shuffleDaily: cached.shuffleDaily,
  );
});
