enum QuestKind { solveQuestions, correctAnswers, subjectSession, dailyQuestion }

class QuestDefinition {
  const QuestDefinition({
    required this.id,
    required this.kind,
    required this.target,
    required this.xpReward,
    this.subjectCode,
  });

  final String id;
  final QuestKind kind;
  final int target;
  final int xpReward;
  final String? subjectCode;
}

/// A quest definition combined with the user's progress for the current day.
class QuestProgress {
  const QuestProgress({required this.definition, required this.progress});

  final QuestDefinition definition;
  final int progress;

  int get target => definition.target;
  bool get isCompleted => progress >= target;
  double get ratio => target <= 0 ? 1 : (progress / target).clamp(0.0, 1.0);
}

class DailyQuests {
  const DailyQuests._();

  static const String solveFive = 'solve_5';
  static const String correctFive = 'correct_5';
  static const String mathSession = 'math_session';
  static const String dailyQuestion = 'daily_question';

  static const String mathSubjectCode = 'tyt_matematik';

  /// The MVP ships a fixed daily set. The schema (`daily_quests` +
  /// `user_daily_quests`) already supports rotating them per date later.
  static const List<QuestDefinition> all = <QuestDefinition>[
    QuestDefinition(
      id: solveFive,
      kind: QuestKind.solveQuestions,
      target: 5,
      xpReward: 20,
    ),
    QuestDefinition(
      id: correctFive,
      kind: QuestKind.correctAnswers,
      target: 5,
      xpReward: 30,
    ),
    QuestDefinition(
      id: mathSession,
      kind: QuestKind.subjectSession,
      target: 1,
      xpReward: 50,
      subjectCode: mathSubjectCode,
    ),
    QuestDefinition(
      id: dailyQuestion,
      kind: QuestKind.dailyQuestion,
      target: 1,
      xpReward: 75,
    ),
  ];

  static List<QuestDefinition> forDate(String dayKey) => all;

  static QuestDefinition? byId(String id) {
    for (final quest in all) {
      if (quest.id == id) return quest;
    }
    return null;
  }
}
