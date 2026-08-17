enum AchievementKind {
  questionsSolved,
  streakDays,
  bestCombo,
  subjectQuestionsSolved,
}

class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.kind,
    required this.threshold,
    required this.icon,
    this.subjectCode,
  });

  final String id;
  final AchievementKind kind;
  final int threshold;

  /// Emoji used on the achievement card. Kept out of l10n because it does not
  /// need translating.
  final String icon;
  final String? subjectCode;
}

/// Snapshot of the counters achievements are evaluated against.
class AchievementStats {
  const AchievementStats({
    required this.totalQuestions,
    required this.currentStreak,
    required this.bestCombo,
    required this.questionsBySubject,
  });

  final int totalQuestions;
  final int currentStreak;
  final int bestCombo;
  final Map<String, int> questionsBySubject;
}

class Achievements {
  const Achievements._();

  static const List<AchievementDefinition> all = <AchievementDefinition>[
    AchievementDefinition(
      id: 'first_step',
      kind: AchievementKind.questionsSolved,
      threshold: 1,
      icon: '🚀',
    ),
    AchievementDefinition(
      id: 'warming_up',
      kind: AchievementKind.questionsSolved,
      threshold: 10,
      icon: '🔥',
    ),
    AchievementDefinition(
      id: 'hundred',
      kind: AchievementKind.questionsSolved,
      threshold: 100,
      icon: '💯',
    ),
    AchievementDefinition(
      id: 'streak_start',
      kind: AchievementKind.streakDays,
      threshold: 3,
      icon: '📅',
    ),
    AchievementDefinition(
      id: 'one_week',
      kind: AchievementKind.streakDays,
      threshold: 7,
      icon: '🗓️',
    ),
    AchievementDefinition(
      id: 'on_fire',
      kind: AchievementKind.bestCombo,
      threshold: 10,
      icon: '⚡',
    ),
    AchievementDefinition(
      id: 'mathematician',
      kind: AchievementKind.subjectQuestionsSolved,
      threshold: 100,
      icon: '📐',
      subjectCode: 'tyt_matematik',
    ),
  ];

  static AchievementDefinition? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  static int progressFor(
    AchievementDefinition definition,
    AchievementStats stats,
  ) {
    switch (definition.kind) {
      case AchievementKind.questionsSolved:
        return stats.totalQuestions;
      case AchievementKind.streakDays:
        return stats.currentStreak;
      case AchievementKind.bestCombo:
        return stats.bestCombo;
      case AchievementKind.subjectQuestionsSolved:
        return stats.questionsBySubject[definition.subjectCode] ?? 0;
    }
  }

  static bool isUnlocked(
    AchievementDefinition definition,
    AchievementStats stats,
  ) =>
      progressFor(definition, stats) >= definition.threshold;

  /// Achievements that became unlocked with [stats] and were not in
  /// [alreadyUnlocked].
  static List<AchievementDefinition> newlyUnlocked({
    required AchievementStats stats,
    required Set<String> alreadyUnlocked,
  }) {
    return all
        .where((a) => !alreadyUnlocked.contains(a.id) && isUnlocked(a, stats))
        .toList(growable: false);
  }
}
