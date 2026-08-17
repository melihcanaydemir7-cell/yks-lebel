import 'package:flutter_test/flutter_test.dart';
import 'package:yks_level/core/utils/tr_date.dart';
import 'package:yks_level/domain/streak.dart';

import '../helpers.dart';

void main() {
  setUp(setUpTestClock);
  tearDown(resetTestClock);

  group('completeDay', () {
    test('starts a streak from nothing', () {
      final result = StreakService.completeDay(
        today: '2026-03-10',
        lastCompletedDate: null,
        currentStreak: 0,
        longestStreak: 0,
      );
      expect(result.currentStreak, 1);
      expect(result.longestStreak, 1);
      expect(result.incremented, isTrue);
    });

    test('extends the streak on consecutive days', () {
      final result = StreakService.completeDay(
        today: '2026-03-10',
        lastCompletedDate: '2026-03-09',
        currentStreak: 6,
        longestStreak: 6,
      );
      expect(result.currentStreak, 7);
      expect(result.longestStreak, 7);
      expect(result.incremented, isTrue);
    });

    test('resets after a missed day', () {
      final result = StreakService.completeDay(
        today: '2026-03-12',
        lastCompletedDate: '2026-03-10',
        currentStreak: 20,
        longestStreak: 20,
      );
      expect(result.currentStreak, 1);
      expect(result.longestStreak, 20, reason: 'longest streak is never lost');
    });

    test('is idempotent within the same day', () {
      final result = StreakService.completeDay(
        today: '2026-03-10',
        lastCompletedDate: '2026-03-10',
        currentStreak: 4,
        longestStreak: 9,
      );
      expect(result.currentStreak, 4);
      expect(result.incremented, isFalse);
    });

    test('handles month and year boundaries', () {
      expect(
        StreakService.completeDay(
          today: '2026-03-01',
          lastCompletedDate: '2026-02-28',
          currentStreak: 3,
          longestStreak: 3,
        ).currentStreak,
        4,
      );
      expect(
        StreakService.completeDay(
          today: '2027-01-01',
          lastCompletedDate: '2026-12-31',
          currentStreak: 11,
          longestStreak: 11,
        ).currentStreak,
        12,
      );
    });
  });

  group('visibleStreak', () {
    test('is zero without any completed day', () {
      expect(
        StreakService.visibleStreak(
          today: '2026-03-10',
          lastCompletedDate: null,
          storedStreak: 5,
        ),
        0,
      );
    });

    test('stays alive on the day after the last completion', () {
      expect(
        StreakService.visibleStreak(
          today: '2026-03-10',
          lastCompletedDate: '2026-03-09',
          storedStreak: 5,
        ),
        5,
      );
    });

    test('dies once a whole day was missed', () {
      expect(
        StreakService.visibleStreak(
          today: '2026-03-11',
          lastCompletedDate: '2026-03-09',
          storedStreak: 5,
        ),
        0,
      );
    });
  });

  group('isAtRisk', () {
    test('warns on the grace day when today is not done yet', () {
      expect(
        StreakService.isAtRisk(
          today: '2026-03-10',
          lastCompletedDate: '2026-03-09',
          completedToday: false,
        ),
        isTrue,
      );
    });

    test('stays quiet once today is complete', () {
      expect(
        StreakService.isAtRisk(
          today: '2026-03-10',
          lastCompletedDate: '2026-03-09',
          completedToday: true,
        ),
        isFalse,
      );
    });
  });

  group('Istanbul day and week boundaries', () {
    test('week starts on Monday', () {
      // 2026-03-12 is a Thursday.
      expect(TrDate.weekStartKey(DateTime.utc(2026, 3, 12, 12)), '2026-03-09');
      // Monday itself maps to itself.
      expect(TrDate.weekStartKey(DateTime.utc(2026, 3, 9, 12)), '2026-03-09');
    });

    test('a late Sunday night in Istanbul still belongs to that week', () {
      // 2026-03-15 22:00 UTC is 2026-03-16 01:00 in Istanbul (UTC+3), i.e.
      // already Monday and therefore a new leaderboard week.
      expect(TrDate.weekStartKey(DateTime.utc(2026, 3, 15, 22)), '2026-03-16');
      expect(TrDate.dayKey(DateTime.utc(2026, 3, 15, 22)), '2026-03-16');
      // An hour earlier is still Sunday.
      expect(TrDate.dayKey(DateTime.utc(2026, 3, 15, 20)), '2026-03-15');
    });

    test('daysBetweenKeys is timezone independent', () {
      expect(TrDate.daysBetweenKeys('2026-03-09', '2026-03-10'), 1);
      expect(TrDate.daysBetweenKeys('2026-02-28', '2026-03-01'), 1);
      expect(TrDate.daysBetweenKeys('2026-03-10', '2026-03-09'), -1);
      expect(TrDate.daysBetweenKeys('nonsense', '2026-03-09'), isNull);
    });
  });
}
