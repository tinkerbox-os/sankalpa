import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:sankalpa/data/models/soundscape.dart';
import 'package:sankalpa/data/repositories/user_profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads soundscape rows for ritual mode.
///
/// Includes both system rows (`is_system = true`, readable by everyone via
/// RLS) and the current user's own uploads (Phase 2).
class SoundscapeRepository {
  SoundscapeRepository(this._client);

  final SupabaseClient _client;

  /// All soundscapes the current user can play, system rows first.
  Future<List<Soundscape>> list() async {
    final rows = await _client
        .from('soundscapes')
        .select()
        .order('is_system', ascending: false)
        .order('name');
    return rows
        .map((r) => Soundscape.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<Soundscape?> byId(String id) async {
    final row = await _client
        .from('soundscapes')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Soundscape.fromJson(Map<String, dynamic>.from(row));
  }
}

final soundscapeRepositoryProvider = Provider<SoundscapeRepository>((ref) {
  return SoundscapeRepository(Supabase.instance.client);
});

final soundscapesProvider = FutureProvider<List<Soundscape>>((ref) async {
  ref.watch(currentUserProvider);
  return ref.read(soundscapeRepositoryProvider).list();
});

/// The soundscape that should auto-play when ritual mode opens.
///
/// Strategy: respect `user_profiles.settings.default_soundscape_id` if set,
/// otherwise fall back to the first system soundscape (alphabetical).
/// Returns `null` only if there are zero soundscapes available.
final defaultSoundscapeProvider = FutureProvider<Soundscape?>((ref) async {
  final list = await ref.watch(soundscapesProvider.future);
  if (list.isEmpty) return null;

  final profile = await ref.watch(userProfileProvider.future);
  final preferredId = profile?.settings.defaultSoundscapeId;
  if (preferredId != null) {
    final match =
        list.where((s) => s.id == preferredId).cast<Soundscape?>().firstOrNull;
    if (match != null) return match;
  }

  return list.firstWhere((s) => s.isSystem, orElse: () => list.first);
});
