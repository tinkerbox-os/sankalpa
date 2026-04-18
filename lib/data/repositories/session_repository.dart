import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sankalpa/data/auth/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records ritual sessions to Supabase and reads them back for the streak.
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

  /// Returns `ended_at` timestamps for completed sessions over the last
  /// [days] days. Used by the streak calculator. Cheap query — sessions are
  /// ~1/day per user.
  Future<List<DateTime>> recentEndedAt({int days = 400}) async {
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .toUtc()
        .toIso8601String();
    final rows = await _client
        .from('sessions')
        .select('ended_at')
        .eq('user_id', _uid)
        .gte('ended_at', since)
        .order('ended_at', ascending: false);
    return rows
        .map((r) => DateTime.parse(r['ended_at'] as String).toLocal())
        .toList();
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(Supabase.instance.client);
});

/// Streak statistics derived from completed sessions.
///
/// Uses local calendar days. Strict: missing a day breaks the streak.
class StreakStats {
  const StreakStats({
    required this.current,
    required this.longest,
    required this.totalDays,
    required this.completedToday,
    this.lastCompletedOn,
  });

  factory StreakStats.fromTimestamps(List<DateTime> endedAt) {
    if (endedAt.isEmpty) return empty;

    // Collapse to set of unique local-calendar days.
    final days = endedAt
        .map((t) => DateTime(t.year, t.month, t.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // newest first

    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final yesterdayKey = todayKey.subtract(const Duration(days: 1));
    final completedToday = days.first == todayKey;

    // Current streak: walk back day-by-day from today (or yesterday if not
    // yet completed today) and count consecutive practiced days.
    var cursor = completedToday ? todayKey : yesterdayKey;
    var current = 0;
    final daysSet = days.toSet();
    while (daysSet.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Longest streak: scan all days for the longest consecutive run.
    final ascending = days.reversed.toList();
    var longest = 1;
    var run = 1;
    for (var i = 1; i < ascending.length; i++) {
      final diff = ascending[i].difference(ascending[i - 1]).inDays;
      if (diff == 1) {
        run++;
        if (run > longest) longest = run;
      } else if (diff > 1) {
        run = 1;
      }
    }

    return StreakStats(
      current: current,
      longest: longest,
      totalDays: days.length,
      completedToday: completedToday,
      lastCompletedOn: days.first,
    );
  }

  static const empty = StreakStats(
    current: 0,
    longest: 0,
    totalDays: 0,
    completedToday: false,
  );

  final int current;
  final int longest;
  final int totalDays;
  final bool completedToday;
  final DateTime? lastCompletedOn;
}

/// Reactive streak read from Supabase. Recomputes when auth changes or when
/// invalidated (e.g. after a session insert).
final streakStatsProvider = FutureProvider<StreakStats>((ref) async {
  ref.watch(currentUserProvider);
  final ts = await ref.read(sessionRepositoryProvider).recentEndedAt();
  return StreakStats.fromTimestamps(ts);
});
