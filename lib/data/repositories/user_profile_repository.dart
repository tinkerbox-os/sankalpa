import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  /// Merges [partial] into the existing `settings` jsonb. Server-side we just
  /// read-modify-write — settings is small (<1KB) so the round-trip is fine.
  Future<UserProfile> updateSettings(Map<String, dynamic> partial) async {
    final current = await get();
    final merged = <String, dynamic>{
      ...?current?.settings.toJson(),
      ...partial,
    };
    final row = await _client
        .from('user_profiles')
        .update({'settings': merged})
        .eq('user_id', _uid)
        .select()
        .single();
    return UserProfile.fromJson(Map<String, dynamic>.from(row));
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
