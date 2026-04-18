import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records ritual sessions to Supabase.
///
/// Phase 1 only logs the bare minimum (cards read + duration); streaks layer
/// reads from this table in a later phase.
class SessionRepository {
  SessionRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('SessionRepository called without an active session');
    }
    return id;
  }

  /// Inserts a `sessions` row marking a completed ritual.
  Future<void> recordCompleted({
    required int cardsRead,
    required Duration duration,
    String mode = 'morning',
    DateTime? startedAt,
  }) async {
    final start = startedAt ?? DateTime.now().subtract(duration);
    await _client.from('sessions').insert({
      'user_id': _uid,
      'mode': mode,
      'started_at': start.toIso8601String(),
      'ended_at': DateTime.now().toIso8601String(),
      'cards_read': cardsRead,
      'duration_s': duration.inSeconds,
    });
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(Supabase.instance.client);
});
