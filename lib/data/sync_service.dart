import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/tr_date.dart';
import 'models/progress.dart';
import 'models/quiz.dart';

/// Best-effort mirroring of the local (authoritative) game state to Supabase.
///
/// Every method swallows its errors on purpose: syncing must never block or
/// break gameplay. The trade-off is that an attempt lost to a network failure
/// is not retried — see README "Known Limitations".
class SyncService {
  SyncService(this._client);

  final SupabaseClient? _client;

  bool get isEnabled => _client != null && _client.auth.currentUser != null;

  String? get _userId => _client?.auth.currentUser?.id;

  Future<void> pushProfile(UserProgress progress) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) return;

    try {
      await client.from('profiles').upsert(<String, dynamic>{
        'id': userId,
        'username': progress.username,
        'avatar_id': progress.avatarId,
        'total_xp': progress.totalXp,
        'current_streak': progress.currentStreak,
        'longest_streak': progress.longestStreak,
        'last_active_date': TrDate.todayKey(),
        'preferred_exam_track': progress.examTrack.storageValue,
      });
    } catch (error) {
      debugPrint('pushProfile failed: $error');
    }
  }

  Future<void> pushWeeklyXp(int weeklyXp) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) return;

    try {
      await client.from('weekly_xp').upsert(<String, dynamic>{
        'user_id': userId,
        'week_start': TrDate.weekStartKey(),
        'xp': weeklyXp,
      }, onConflict: 'user_id,week_start');
    } catch (error) {
      debugPrint('pushWeeklyXp failed: $error');
    }
  }

  Future<void> pushDailyProgress(DailyProgress daily) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) return;

    try {
      await client.from('daily_progress').upsert(<String, dynamic>{
        'user_id': userId,
        'day': daily.date,
        'questions_solved': daily.solved,
        'questions_correct': daily.correct,
        'xp_earned': daily.xpEarned,
      }, onConflict: 'user_id,day');
    } catch (error) {
      debugPrint('pushDailyProgress failed: $error');
    }
  }

  Future<void> pushSession(QuizResult result) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) return;

    try {
      final inserted = await client
          .from('study_sessions')
          .insert(<String, dynamic>{
            'user_id': userId,
            'subject_code': result.subjectCode,
            'topic_code': result.topicCode,
            'question_count': result.total,
            'correct_count': result.correct,
            'xp_earned': result.totalXp,
            'best_combo': result.bestCombo,
            'duration_ms': result.duration.inMilliseconds,
            'source': result.source.name,
          })
          .select('id')
          .single();

      final sessionId = inserted['id'];
      if (result.attempts.isEmpty) return;

      await client.from('question_attempts').insert(
        result.attempts
            .map(
              (attempt) => <String, dynamic>{
                ...attempt.toJson(),
                'user_id': userId,
                'session_id': sessionId,
              },
            )
            .toList(growable: false),
      );
    } catch (error) {
      debugPrint('pushSession failed: $error');
    }
  }

  Future<void> pushAchievements(Set<String> unlockedIds) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null || unlockedIds.isEmpty) return;

    try {
      await client.from('user_achievements').upsert(
        unlockedIds
            .map(
              (id) => <String, dynamic>{
                'user_id': userId,
                'achievement_code': id,
              },
            )
            .toList(growable: false),
        onConflict: 'user_id,achievement_code',
      );
    } catch (error) {
      debugPrint('pushAchievements failed: $error');
    }
  }

  /// Pulls the cloud profile so a returning user on a new device keeps their
  /// level. Local values win when they are ahead, which also covers the
  /// guest -> account upgrade path.
  Future<UserProgress?> pullProfile(UserProgress local) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) return null;

    try {
      final row = await client
          .from('profiles')
          .select(
            'username, avatar_id, total_xp, current_streak, longest_streak, '
            'last_active_date, preferred_exam_track',
          )
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;

      final remoteXp = (row['total_xp'] as num?)?.toInt() ?? 0;
      if (remoteXp <= local.totalXp) return null;

      return local.copyWith(
        username: (row['username'] as String?)?.isNotEmpty == true
            ? row['username'] as String
            : local.username,
        avatarId: (row['avatar_id'] as num?)?.toInt() ?? local.avatarId,
        totalXp: remoteXp,
        currentStreak:
            (row['current_streak'] as num?)?.toInt() ?? local.currentStreak,
        longestStreak:
            (row['longest_streak'] as num?)?.toInt() ?? local.longestStreak,
        examTrack: ExamTrack.fromStorage(
          row['preferred_exam_track'] as String?,
        ),
      );
    } catch (error) {
      debugPrint('pullProfile failed: $error');
      return null;
    }
  }
}
