class QuestionAttempt {
  const QuestionAttempt({
    required this.questionId,
    required this.subjectCode,
    required this.topicCode,
    required this.selectedOption,
    required this.isCorrect,
    required this.responseTimeMs,
    required this.xpAwarded,
    required this.answeredAt,
  });

  final String questionId;
  final String subjectCode;
  final String topicCode;
  final String selectedOption;
  final bool isCorrect;
  final int responseTimeMs;
  final int xpAwarded;
  final DateTime answeredAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'question_id': questionId,
    'selected_answer': selectedOption,
    'is_correct': isCorrect,
    'response_time_ms': responseTimeMs,
    'xp_awarded': xpAwarded,
    'answered_at': answeredAt.toUtc().toIso8601String(),
  };
}

/// Where a quiz session was launched from — used for analytics and for the
/// "daily question" quest.
enum QuizSource { topic, subject, dailyQuestion, quickStart }

class QuizResult {
  const QuizResult({
    required this.subjectCode,
    required this.topicCode,
    required this.source,
    required this.total,
    required this.correct,
    required this.baseXp,
    required this.bestCombo,
    required this.duration,
    required this.attempts,
    this.bonusXp = 0,
  });

  final String subjectCode;
  final String? topicCode;
  final QuizSource source;
  final int total;
  final int correct;
  final int baseXp;
  final int bonusXp;
  final int bestCombo;
  final Duration duration;
  final List<QuestionAttempt> attempts;

  int get totalXp => baseXp + bonusXp;
  double get accuracy => total == 0 ? 0 : correct / total;

}
