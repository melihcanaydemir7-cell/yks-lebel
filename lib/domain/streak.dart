import '../core/utils/tr_date.dart';

/// Result of re-evaluating the streak for a given day.
class StreakResult {
  const StreakResult({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastCompletedDate,
    required this.incremented,
  });

  final int currentStreak;
  final int longestStreak;
  final String? lastCompletedDate;

  /// True when this evaluation is what pushed the streak forward, so the UI
  /// can celebrate exactly once.
  final bool incremented;
}

/// Streak rules:
/// * a day counts as completed once the user answers `questionsForStreakDay`
///   questions on that Istanbul day;
/// * completing today right after yesterday extends the streak;
/// * a missed day resets it to 1 on the next completed day.
class StreakService {
  const StreakService._();

  /// Called when today's question target has just been reached.
  static StreakResult completeDay({
    required String today,
    required String? lastCompletedDate,
    required int currentStreak,
    required int longestStreak,
  }) {
    if (lastCompletedDate == today) {
      return StreakResult(
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        lastCompletedDate: lastCompletedDate,
        incremented: false,
      );
    }

    final gap = lastCompletedDate == null
        ? null
        : TrDate.daysBetweenKeys(lastCompletedDate, today);

    final next = gap == 1 ? currentStreak + 1 : 1;

    return StreakResult(
      currentStreak: next,
      longestStreak: next > longestStreak ? next : longestStreak,
      lastCompletedDate: today,
      incremented: true,
    );
  }

  /// The streak value that should be *displayed* right now. A streak stays
  /// alive on the day after the last completed day (the user still has time to
  /// solve their questions), and dies after that.
  static int visibleStreak({
    required String today,
    required String? lastCompletedDate,
    required int storedStreak,
  }) {
    if (lastCompletedDate == null || storedStreak <= 0) return 0;
    final gap = TrDate.daysBetweenKeys(lastCompletedDate, today);
    if (gap == null || gap < 0) return 0;
    return gap <= 1 ? storedStreak : 0;
  }

  static bool isAtRisk({
    required String today,
    required String? lastCompletedDate,
    required bool completedToday,
  }) {
    if (completedToday || lastCompletedDate == null) return false;
    return TrDate.daysBetweenKeys(lastCompletedDate, today) == 1;
  }
}
