import 'dart:math' as math;

/// Level progression. Total XP is the single source of truth; the level is
/// always derived from it so the two can never drift apart.
class XpService {
  const XpService._();

  static const int maxLevel = 100;

  static const int baseAnswerXp = 10;
  static const int comboAnswerXp = 12;
  static const int hotComboAnswerXp = 15;

  /// Bonus applied when a rewarded ad is watched at the end of a session.
  static const double rewardedAdBonusRate = 0.25;

  /// XP required to advance from [level] to [level] + 1.
  static int requiredXpForLevel(int level) {
    if (level < 1) return 0;
    if (level >= maxLevel) return 0;
    return (100 * math.pow(level, 1.25)).round();
  }

  /// Cumulative XP needed to *reach* [level]. Level 1 starts at 0.
  static int cumulativeXpForLevel(int level) {
    var total = 0;
    for (var i = 1; i < level; i++) {
      total += requiredXpForLevel(i);
    }
    return total;
  }

  static int levelForTotalXp(int totalXp) {
    if (totalXp <= 0) return 1;
    var level = 1;
    var consumed = 0;
    while (level < maxLevel) {
      final needed = requiredXpForLevel(level);
      if (totalXp - consumed < needed) break;
      consumed += needed;
      level++;
    }
    return level;
  }

  /// XP earned inside the current level.
  static int xpIntoLevel(int totalXp) {
    final level = levelForTotalXp(totalXp);
    return math.max(0, totalXp - cumulativeXpForLevel(level));
  }

  /// XP span of the current level. Returns 0 at [maxLevel].
  static int xpForCurrentLevel(int totalXp) =>
      requiredXpForLevel(levelForTotalXp(totalXp));

  static int xpToNextLevel(int totalXp) {
    final span = xpForCurrentLevel(totalXp);
    if (span == 0) return 0;
    return math.max(0, span - xpIntoLevel(totalXp));
  }

  /// 0..1 progress through the current level.
  static double levelProgress(int totalXp) {
    final span = xpForCurrentLevel(totalXp);
    if (span <= 0) return 1;
    return (xpIntoLevel(totalXp) / span).clamp(0.0, 1.0);
  }

  /// XP awarded for a single correct answer given the combo *after* the answer
  /// (a first correct answer means a combo of 1).
  static int xpForAnswer({required bool isCorrect, required int combo}) {
    if (!isCorrect) return 0;
    if (combo >= 5) return hotComboAnswerXp;
    if (combo >= 3) return comboAnswerXp;
    return baseAnswerXp;
  }

  /// Bonus XP granted after a successfully completed rewarded ad.
  static int rewardedAdBonus(int sessionXp) {
    if (sessionXp <= 0) return 0;
    return math.max(1, (sessionXp * rewardedAdBonusRate).round());
  }
}
