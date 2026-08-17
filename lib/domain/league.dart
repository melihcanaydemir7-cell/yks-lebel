/// Weekly leagues. Membership is derived purely from weekly XP, which keeps
/// the MVP free of any matchmaking infrastructure.
enum League {
  bronze(0),
  silver(500),
  gold(1000),
  platinum(2000),
  diamond(3500);

  const League(this.weeklyXpThreshold);

  final int weeklyXpThreshold;

  static League forWeeklyXp(int weeklyXp) {
    var result = League.bronze;
    for (final league in League.values) {
      if (weeklyXp >= league.weeklyXpThreshold) result = league;
    }
    return result;
  }

  League? get next {
    final i = index + 1;
    return i < League.values.length ? League.values[i] : null;
  }

  /// XP still needed to reach the next league, or null when already at the top.
  int? xpToNext(int weeklyXp) {
    final target = next;
    if (target == null) return null;
    final remaining = target.weeklyXpThreshold - weeklyXp;
    return remaining > 0 ? remaining : 0;
  }
}
