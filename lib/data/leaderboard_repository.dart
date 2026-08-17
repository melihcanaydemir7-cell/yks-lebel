import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/tr_date.dart';
import 'models/leaderboard.dart';

/// Weekly XP leaderboard. Requires an account: guests get a sign-in prompt
/// instead of a list.
class LeaderboardRepository {
  LeaderboardRepository(this._client);

  final SupabaseClient? _client;

  static const int topCount = 50;

  bool get isAvailable => _client != null;

  Future<LeaderboardPage> weeklyTop({
    String? currentUserId,
    int limit = topCount,
  }) async {
    final client = _client;
    if (client == null) return LeaderboardPage.empty;

    final weekStart = TrDate.weekStartKey();
    final rows = await client
        .from('weekly_leaderboard')
        .select('user_id, username, avatar_id, weekly_xp')
        .eq('week_start', weekStart)
        .order('weekly_xp', ascending: false)
        .limit(limit);

    final entries = <LeaderboardEntry>[];
    var rank = 0;
    for (final row in (rows as List<dynamic>).cast<Map<String, dynamic>>()) {
      rank++;
      entries.add(
        LeaderboardEntry(
          rank: rank,
          userId: row['user_id'].toString(),
          username: row['username'] as String? ?? 'Öğrenci',
          avatarId: (row['avatar_id'] as num?)?.toInt() ?? 0,
          weeklyXp: (row['weekly_xp'] as num?)?.toInt() ?? 0,
          isCurrentUser: row['user_id'].toString() == currentUserId,
        ),
      );
    }

    if (currentUserId == null || entries.any((e) => e.isCurrentUser)) {
      return LeaderboardPage(entries: entries);
    }

    return LeaderboardPage(
      entries: entries,
      currentUserEntry: await _currentUserRow(client, currentUserId, weekStart),
    );
  }

  Future<LeaderboardEntry?> _currentUserRow(
    SupabaseClient client,
    String userId,
    String weekStart,
  ) async {
    try {
      final rank = await client.rpc<dynamic>(
        'weekly_rank',
        params: <String, dynamic>{'p_user_id': userId, 'p_week_start': weekStart},
      );
      final row = await client
          .from('weekly_leaderboard')
          .select('user_id, username, avatar_id, weekly_xp')
          .eq('week_start', weekStart)
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return LeaderboardEntry(
        rank: (rank as num?)?.toInt() ?? 0,
        userId: userId,
        username: row['username'] as String? ?? 'Öğrenci',
        avatarId: (row['avatar_id'] as num?)?.toInt() ?? 0,
        weeklyXp: (row['weekly_xp'] as num?)?.toInt() ?? 0,
        isCurrentUser: true,
      );
    } catch (_) {
      return null;
    }
  }
}
