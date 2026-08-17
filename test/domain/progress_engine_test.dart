import 'package:flutter_test/flutter_test.dart';
import 'package:yks_level/core/utils/tr_date.dart';
import 'package:yks_level/data/models/progress.dart';
import 'package:yks_level/data/models/quiz.dart';
import 'package:yks_level/domain/achievement.dart';
import 'package:yks_level/domain/daily_quest.dart';
import 'package:yks_level/domain/league.dart';
import 'package:yks_level/domain/progress_engine.dart';
import 'package:yks_level/domain/xp.dart';

import '../helpers.dart';

/// 2026-03-12 12:00 UTC → Thursday 15:00 in Istanbul.
final _now = DateTime.utc(2026, 3, 12, 12);
const _today = '2026-03-12';

UserProgress _base({
  int totalXp = 0,
  int solvedToday = 0,
  int correctToday = 0,
  String? lastCompletedDate,
  int currentStreak = 0,
  Set<String> claimed = const {},
}) => UserProgress(
  username: 'Test',
  avatarId: 0,
  examTrack: ExamTrack.tyt,
  today: DailyProgress(
    date: _today,
    solved: solvedToday,
    correct: correctToday,
    claimedQuests: claimed,
  ),
  totalXp: totalXp,
  currentStreak: currentStreak,
  lastCompletedDate: lastCompletedDate,
);

void main() {
  setUp(() => setUpTestClock(now: _now));
  tearDown(resetTestClock);

  group('rollDay', () {
    test('clears yesterday-s bucket when the day changed', () {
      final stale = _base(solvedToday: 7).copyWith(
        today: const DailyProgress(date: '2026-03-11', solved: 7, correct: 5),
      );
      final rolled = ProgressEngine.rollDay(stale, _today);
      expect(rolled.today.date, _today);
      expect(rolled.today.solved, 0);
      expect(rolled.today.correct, 0);
    });

    test('is a no-op within the same day', () {
      final progress = _base(solvedToday: 3);
      expect(identical(ProgressEngine.rollDay(progress, _today), progress), isTrue);
    });
  });

  group('applySession', () {
    test('adds session stats, XP and weekly XP', () {
      final result = buildQuizResult(total: 10, correct: 8, baseXp: 100);
      final outcome = ProgressEngine.applySession(
        progress: _base(),
        result: result,
        today: _today,
      );
      final progress = outcome.progress;

      expect(progress.totalQuestions, 10);
      expect(progress.totalCorrect, 8);
      expect(progress.today.solved, 10);
      expect(progress.subjectStats['tyt_matematik']!.solved, 10);
      expect(progress.studyDays, contains(_today));

      // 100 session XP + 20 (solve 5) + 30 (5 correct) + 50 (math session).
      expect(outcome.rewards.sessionXp, 100);
      expect(outcome.rewards.questXp, 100);
      expect(progress.totalXp, 200);
      expect(progress.weeklyXp[TrDate.weekStartKey()], 200);
    });

    test('auto-claims each daily quest exactly once', () {
      var progress = _base();
      final first = ProgressEngine.applySession(
        progress: progress,
        result: buildQuizResult(total: 10, correct: 8, baseXp: 100),
        today: _today,
      );
      progress = first.progress;
      expect(
        first.rewards.completedQuests.map((q) => q.id),
        containsAll(<String>[
          DailyQuests.solveFive,
          DailyQuests.correctFive,
          DailyQuests.mathSession,
        ]),
      );

      final second = ProgressEngine.applySession(
        progress: progress,
        result: buildQuizResult(total: 10, correct: 8, baseXp: 100),
        today: _today,
      );
      expect(second.rewards.completedQuests, isEmpty);
      expect(second.rewards.questXp, 0);
    });

    test('completes the daily-question quest only from that entry point', () {
      final outcome = ProgressEngine.applySession(
        progress: _base(),
        result: buildQuizResult(
          total: 1,
          correct: 1,
          baseXp: 10,
          source: QuizSource.dailyQuestion,
        ),
        today: _today,
      );
      expect(outcome.progress.today.dailyQuestionAnswered, isTrue);
      expect(
        outcome.rewards.completedQuests.map((q) => q.id),
        contains(DailyQuests.dailyQuestion),
      );
    });

    test('does not complete the math quest for another subject', () {
      final outcome = ProgressEngine.applySession(
        progress: _base(),
        result: buildQuizResult(
          subjectCode: 'tyt_turkce',
          topicCode: 'paragraf',
          total: 10,
          correct: 8,
          baseXp: 100,
        ),
        today: _today,
      );
      expect(
        outcome.rewards.completedQuests.map((q) => q.id),
        isNot(contains(DailyQuests.mathSession)),
      );
    });

    test('bumps the streak once the daily question target is reached', () {
      final outcome = ProgressEngine.applySession(
        progress: _base(lastCompletedDate: '2026-03-11', currentStreak: 4),
        result: buildQuizResult(total: 10, correct: 8, baseXp: 100),
        today: _today,
      );
      expect(outcome.rewards.streakIncremented, isTrue);
      expect(outcome.progress.currentStreak, 5);
      expect(outcome.progress.lastCompletedDate, _today);
    });

    test('leaves the streak alone below the daily target', () {
      final outcome = ProgressEngine.applySession(
        progress: _base(),
        result: buildQuizResult(total: 3, correct: 3, baseXp: 30),
        today: _today,
      );
      expect(outcome.rewards.streakIncremented, isFalse);
      expect(outcome.progress.currentStreak, 0);
    });

    test('reports a level-up across the session and quest XP', () {
      final outcome = ProgressEngine.applySession(
        progress: _base(totalXp: 60),
        result: buildQuizResult(total: 10, correct: 8, baseXp: 100),
        today: _today,
      );
      expect(outcome.rewards.levelBefore, 1);
      expect(outcome.rewards.leveledUp, isTrue);
      expect(
        outcome.rewards.levelAfter,
        XpService.levelForTotalXp(outcome.progress.totalXp),
      );
    });

    test('unlocks achievements once and only once', () {
      final first = ProgressEngine.applySession(
        progress: _base(),
        result: buildQuizResult(total: 10, correct: 8, baseXp: 100),
        today: _today,
      );
      expect(
        first.rewards.newAchievements.map((a) => a.id),
        containsAll(<String>['first_step', 'warming_up']),
      );

      final second = ProgressEngine.applySession(
        progress: first.progress,
        result: buildQuizResult(total: 10, correct: 8, baseXp: 100),
        today: _today,
      );
      expect(second.rewards.newAchievements, isEmpty);
    });

    test('rolls the day over before applying a stale session', () {
      final yesterday = _base().copyWith(
        today: const DailyProgress(date: '2026-03-11', solved: 9, correct: 9),
      );
      final outcome = ProgressEngine.applySession(
        progress: yesterday,
        result: buildQuizResult(total: 2, correct: 2, baseXp: 20),
        today: _today,
      );
      expect(outcome.progress.today.date, _today);
      expect(outcome.progress.today.solved, 2);
      expect(outcome.rewards.streakIncremented, isFalse);
    });
  });

  group('addXp', () {
    test('adds bonus XP to the total, today and the week', () {
      final outcome = ProgressEngine.addXp(_base(totalXp: 50), 25);
      expect(outcome.progress.totalXp, 75);
      expect(outcome.progress.today.xpEarned, 25);
      expect(outcome.progress.weeklyXp[TrDate.weekStartKey()], 25);
    });

    test('ignores non-positive amounts', () {
      final progress = _base(totalXp: 50);
      expect(ProgressEngine.addXp(progress, 0).progress.totalXp, 50);
      expect(ProgressEngine.addXp(progress, -10).progress.totalXp, 50);
    });

    test('reports a level-up', () {
      final outcome = ProgressEngine.addXp(_base(totalXp: 95), 25);
      expect(outcome.rewards.leveledUp, isTrue);
      expect(outcome.rewards.levelAfter, 2);
    });
  });

  group('quests', () {
    test('reflect live daily counters', () {
      final quests = ProgressEngine.quests(
        _base(solvedToday: 3, correctToday: 2),
      );
      final solve = quests.firstWhere(
        (q) => q.definition.id == DailyQuests.solveFive,
      );
      expect(solve.progress, 3);
      expect(solve.isCompleted, isFalse);
      expect(solve.ratio, closeTo(0.6, 0.001));
    });
  });

  group('leagues', () {
    test('are derived from weekly XP thresholds', () {
      expect(League.forWeeklyXp(0), League.bronze);
      expect(League.forWeeklyXp(499), League.bronze);
      expect(League.forWeeklyXp(500), League.silver);
      expect(League.forWeeklyXp(1000), League.gold);
      expect(League.forWeeklyXp(2000), League.platinum);
      expect(League.forWeeklyXp(3500), League.diamond);
      expect(League.forWeeklyXp(99999), League.diamond);
    });

    test('report the distance to the next league', () {
      expect(League.bronze.xpToNext(120), 380);
      expect(League.gold.xpToNext(2500), 0);
      expect(League.diamond.xpToNext(9000), isNull);
      expect(League.diamond.next, isNull);
    });
  });

  group('achievements', () {
    test('track their own counter', () {
      const stats = AchievementStats(
        totalQuestions: 100,
        currentStreak: 3,
        bestCombo: 4,
        questionsBySubject: {'tyt_matematik': 40},
      );
      expect(Achievements.isUnlocked(Achievements.byId('hundred')!, stats), isTrue);
      expect(
        Achievements.isUnlocked(Achievements.byId('streak_start')!, stats),
        isTrue,
      );
      expect(Achievements.isUnlocked(Achievements.byId('on_fire')!, stats), isFalse);
      expect(
        Achievements.isUnlocked(Achievements.byId('mathematician')!, stats),
        isFalse,
      );
    });

    test('newlyUnlocked excludes already-earned ones', () {
      const stats = AchievementStats(
        totalQuestions: 10,
        currentStreak: 0,
        bestCombo: 0,
        questionsBySubject: {},
      );
      final unlocked = Achievements.newlyUnlocked(
        stats: stats,
        alreadyUnlocked: {'first_step'},
      );
      expect(unlocked.map((a) => a.id), <String>['warming_up']);
    });
  });
}
