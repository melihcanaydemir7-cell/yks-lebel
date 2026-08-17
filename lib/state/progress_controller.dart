import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/tr_date.dart';
import '../data/models/progress.dart';
import '../data/models/quiz.dart';
import '../domain/achievement.dart';
import '../domain/daily_quest.dart';
import '../domain/league.dart';
import '../domain/progress_engine.dart';
import '../domain/streak.dart';
import '../domain/xp.dart';
import '../services/analytics_service.dart';
import 'providers.dart';

class ProgressController extends Notifier<UserProgress> {
  @override
  UserProgress build() {
    final store = ref.watch(localStoreProvider);
    final stored = store.readProgress() ?? UserProgress.initial();
    return ProgressEngine.rollDay(stored, TrDate.todayKey());
  }

  Future<void> _persist(UserProgress next) async {
    state = next;
    await ref.read(localStoreProvider).writeProgress(next);
  }

  /// Called on resume so the home screen never shows yesterday's quests.
  Future<void> refreshDay() async {
    final rolled = ProgressEngine.rollDay(state, TrDate.todayKey());
    if (!identical(rolled, state)) await _persist(rolled);
  }

  Future<void> updateProfile({
    String? username,
    int? avatarId,
    ExamTrack? examTrack,
  }) async {
    await _persist(
      state.copyWith(
        username: username,
        avatarId: avatarId,
        examTrack: examTrack,
      ),
    );
    unawaited(ref.read(syncServiceProvider).pushProfile(state));
  }

  /// Applies a completed quiz session and emits every analytics event tied to
  /// the core loop.
  Future<SessionRewards> applySession(QuizResult result) async {
    final today = TrDate.todayKey();
    final outcome = ProgressEngine.applySession(
      progress: state,
      result: result,
      today: today,
    );
    await _persist(outcome.progress);

    final analytics = ref.read(analyticsProvider);
    final rewards = outcome.rewards;

    unawaited(
      analytics.logEvent(AnalyticsEvents.quizCompleted, <String, Object?>{
        'subject': result.subjectCode,
        'topic': result.topicCode,
        'question_count': result.total,
        'accuracy': (result.accuracy * 100).round(),
        'session_duration': result.duration.inSeconds,
        'xp_earned': rewards.totalXp,
        'best_combo': result.bestCombo,
        'source': result.source.name,
      }),
    );

    for (final quest in rewards.completedQuests) {
      unawaited(
        analytics.logEvent(AnalyticsEvents.dailyQuestCompleted, <String, Object?>{
          'quest_id': quest.id,
          'xp_earned': quest.xpReward,
        }),
      );
    }
    if (rewards.streakIncremented) {
      unawaited(
        analytics.logEvent(AnalyticsEvents.streakIncremented, <String, Object?>{
          'streak': rewards.streak,
        }),
      );
    }
    if (rewards.leveledUp) {
      unawaited(
        analytics.logEvent(AnalyticsEvents.levelUp, <String, Object?>{
          'level': rewards.levelAfter,
        }),
      );
    }

    unawaited(_sync(result: result, newAchievements: rewards.newAchievements));
    return rewards;
  }

  /// XP granted after a rewarded ad completes successfully.
  Future<SessionRewards> addBonusXp(int xp) async {
    final outcome = ProgressEngine.addXp(state, xp);
    await _persist(outcome.progress);
    if (outcome.rewards.leveledUp) {
      unawaited(
        ref.read(analyticsProvider).logEvent(
          AnalyticsEvents.levelUp,
          <String, Object?>{'level': outcome.rewards.levelAfter},
        ),
      );
    }
    unawaited(_sync());
    return outcome.rewards;
  }

  Future<void> _sync({
    QuizResult? result,
    List<AchievementDefinition> newAchievements = const [],
  }) async {
    final sync = ref.read(syncServiceProvider);
    if (!sync.isEnabled) return;
    await sync.pushProfile(state);
    await sync.pushWeeklyXp(state.currentWeekXp);
    await sync.pushDailyProgress(state.today);
    if (result != null) await sync.pushSession(result);
    if (newAchievements.isNotEmpty) {
      await sync.pushAchievements(newAchievements.map((a) => a.id).toSet());
    }
  }

  /// Pulls a cloud profile that is ahead of the local one (new device sign-in).
  Future<void> mergeFromCloud() async {
    final merged = await ref.read(syncServiceProvider).pullProfile(state);
    if (merged != null) await _persist(merged);
    unawaited(_sync());
  }

  Future<void> resetLocalProgress() async {
    await ref.read(localStoreProvider).clearProgress();
    state = UserProgress.initial();
  }
}

final progressControllerProvider =
    NotifierProvider<ProgressController, UserProgress>(ProgressController.new);

// ------------------------------------------------------------------ selectors

final levelProvider = Provider<int>(
  (ref) => XpService.levelForTotalXp(ref.watch(progressControllerProvider).totalXp),
);

final visibleStreakProvider = Provider<int>((ref) {
  final progress = ref.watch(progressControllerProvider);
  return StreakService.visibleStreak(
    today: TrDate.todayKey(),
    lastCompletedDate: progress.lastCompletedDate,
    storedStreak: progress.currentStreak,
  );
});

final dailyQuestsProvider = Provider<List<QuestProgress>>(
  (ref) => ProgressEngine.quests(ref.watch(progressControllerProvider)),
);

final leagueProvider = Provider<League>(
  (ref) => League.forWeeklyXp(ref.watch(progressControllerProvider).currentWeekXp),
);

final achievementStatsProvider = Provider<AchievementStats>(
  (ref) => ProgressEngine.statsOf(
    ref.watch(progressControllerProvider),
    TrDate.todayKey(),
  ),
);
