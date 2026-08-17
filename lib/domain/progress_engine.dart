import 'dart:math' as math;

import '../core/config/app_config.dart';
import '../core/utils/tr_date.dart';
import '../data/models/progress.dart';
import '../data/models/quiz.dart';
import 'achievement.dart';
import 'daily_quest.dart';
import 'streak.dart';
import 'xp.dart';

/// Everything the UI needs to celebrate after XP has been applied.
class SessionRewards {
  const SessionRewards({
    required this.sessionXp,
    required this.questXp,
    required this.levelBefore,
    required this.levelAfter,
    required this.streak,
    required this.streakIncremented,
    this.completedQuests = const <QuestDefinition>[],
    this.newAchievements = const <AchievementDefinition>[],
  });

  final int sessionXp;
  final int questXp;
  final int levelBefore;
  final int levelAfter;
  final int streak;
  final bool streakIncremented;
  final List<QuestDefinition> completedQuests;
  final List<AchievementDefinition> newAchievements;

  int get totalXp => sessionXp + questXp;
  bool get leveledUp => levelAfter > levelBefore;

  static const SessionRewards none = SessionRewards(
    sessionXp: 0,
    questXp: 0,
    levelBefore: 1,
    levelAfter: 1,
    streak: 0,
    streakIncremented: false,
  );
}

typedef ProgressUpdate = ({UserProgress progress, SessionRewards rewards});

/// Pure gameplay reducer. Kept free of Flutter and Riverpod so it can be unit
/// tested directly — this is where all the rules that matter live.
class ProgressEngine {
  const ProgressEngine._();

  /// Rolls the daily bucket over when the Istanbul day has changed.
  static UserProgress rollDay(UserProgress progress, String today) {
    if (progress.today.date == today) return progress;
    return progress.copyWith(today: DailyProgress.empty(today));
  }

  static List<QuestProgress> quests(UserProgress progress) {
    final today = progress.today;
    return DailyQuests.forDate(today.date).map((definition) {
      final int value;
      switch (definition.kind) {
        case QuestKind.solveQuestions:
          value = today.solved;
        case QuestKind.correctAnswers:
          value = today.correct;
        case QuestKind.subjectSession:
          value = today.completedSubjectSessions.contains(definition.subjectCode)
              ? 1
              : 0;
        case QuestKind.dailyQuestion:
          value = today.dailyQuestionAnswered ? 1 : 0;
      }
      return QuestProgress(definition: definition, progress: value);
    }).toList(growable: false);
  }

  /// Applies a finished quiz session: stats, XP, daily quests, streak and
  /// achievements, in that order.
  static ProgressUpdate applySession({
    required UserProgress progress,
    required QuizResult result,
    required String today,
  }) {
    final levelBefore = XpService.levelForTotalXp(progress.totalXp);
    var next = rollDay(progress, today);

    final daily = next.today;
    var updatedDaily = daily.copyWith(
      solved: daily.solved + result.total,
      correct: daily.correct + result.correct,
      xpEarned: daily.xpEarned + result.baseXp,
      dailyQuestionAnswered:
          daily.dailyQuestionAnswered || result.source == QuizSource.dailyQuestion,
      completedSubjectSessions: <String>{
        ...daily.completedSubjectSessions,
        result.subjectCode,
      },
    );

    final subjectStats = Map<String, SubjectStats>.of(next.subjectStats);
    subjectStats[result.subjectCode] =
        (subjectStats[result.subjectCode] ?? const SubjectStats()).add(
          solved: result.total,
          correct: result.correct,
        );

    next = next.copyWith(
      today: updatedDaily,
      totalXp: next.totalXp + result.baseXp,
      totalQuestions: next.totalQuestions + result.total,
      totalCorrect: next.totalCorrect + result.correct,
      bestCombo: math.max(next.bestCombo, result.bestCombo),
      subjectStats: subjectStats,
      studyDays: result.total > 0
          ? <String>{...next.studyDays, today}
          : next.studyDays,
      weeklyXp: _addWeeklyXp(next.weeklyXp, result.baseXp),
    );

    // Daily quests are auto-claimed the moment they complete: one less tap in
    // the core loop, and no "unclaimed rewards" state to reconcile.
    final questOutcome = _claimQuests(next);
    next = questOutcome.progress;
    updatedDaily = next.today;

    final streakResult = updatedDaily.solved >= AppConfig.questionsForStreakDay
        ? StreakService.completeDay(
            today: today,
            lastCompletedDate: next.lastCompletedDate,
            currentStreak: StreakService.visibleStreak(
              today: today,
              lastCompletedDate: next.lastCompletedDate,
              storedStreak: next.currentStreak,
            ),
            longestStreak: next.longestStreak,
          )
        : null;

    if (streakResult != null) {
      next = next.copyWith(
        currentStreak: streakResult.currentStreak,
        longestStreak: streakResult.longestStreak,
        lastCompletedDate: streakResult.lastCompletedDate,
      );
    }

    final unlocked = Achievements.newlyUnlocked(
      stats: statsOf(next, today),
      alreadyUnlocked: next.unlockedAchievements,
    );
    if (unlocked.isNotEmpty) {
      next = next.copyWith(
        unlockedAchievements: <String>{
          ...next.unlockedAchievements,
          ...unlocked.map((a) => a.id),
        },
      );
    }

    return (
      progress: next,
      rewards: SessionRewards(
        sessionXp: result.baseXp,
        questXp: questOutcome.xp,
        levelBefore: levelBefore,
        levelAfter: XpService.levelForTotalXp(next.totalXp),
        streak: next.currentStreak,
        streakIncremented: streakResult?.incremented ?? false,
        completedQuests: questOutcome.completed,
        newAchievements: unlocked,
      ),
    );
  }

  /// Adds standalone XP (rewarded ad bonus) and reports any level-up.
  static ProgressUpdate addXp(UserProgress progress, int xp) {
    if (xp <= 0) return (progress: progress, rewards: SessionRewards.none);
    final levelBefore = XpService.levelForTotalXp(progress.totalXp);
    final next = progress.copyWith(
      totalXp: progress.totalXp + xp,
      today: progress.today.copyWith(xpEarned: progress.today.xpEarned + xp),
      weeklyXp: _addWeeklyXp(progress.weeklyXp, xp),
    );
    return (
      progress: next,
      rewards: SessionRewards(
        sessionXp: xp,
        questXp: 0,
        levelBefore: levelBefore,
        levelAfter: XpService.levelForTotalXp(next.totalXp),
        streak: next.currentStreak,
        streakIncremented: false,
      ),
    );
  }

  static AchievementStats statsOf(UserProgress progress, String today) =>
      AchievementStats(
        totalQuestions: progress.totalQuestions,
        currentStreak: StreakService.visibleStreak(
          today: today,
          lastCompletedDate: progress.lastCompletedDate,
          storedStreak: progress.currentStreak,
        ),
        bestCombo: progress.bestCombo,
        questionsBySubject: progress.questionsBySubject,
      );

  static ({UserProgress progress, int xp, List<QuestDefinition> completed})
  _claimQuests(UserProgress progress) {
    final completed = <QuestDefinition>[];
    var xp = 0;

    for (final quest in quests(progress)) {
      if (!quest.isCompleted) continue;
      if (progress.today.claimedQuests.contains(quest.definition.id)) continue;
      completed.add(quest.definition);
      xp += quest.definition.xpReward;
    }

    if (completed.isEmpty) return (progress: progress, xp: 0, completed: completed);

    final today = progress.today;
    return (
      progress: progress.copyWith(
        totalXp: progress.totalXp + xp,
        weeklyXp: _addWeeklyXp(progress.weeklyXp, xp),
        today: today.copyWith(
          xpEarned: today.xpEarned + xp,
          claimedQuests: <String>{
            ...today.claimedQuests,
            ...completed.map((q) => q.id),
          },
        ),
      ),
      xp: xp,
      completed: completed,
    );
  }

  static Map<String, int> _addWeeklyXp(Map<String, int> current, int xp) {
    if (xp == 0) return current;
    final weekKey = TrDate.weekStartKey();
    return <String, int>{...current, weekKey: (current[weekKey] ?? 0) + xp};
  }
}
