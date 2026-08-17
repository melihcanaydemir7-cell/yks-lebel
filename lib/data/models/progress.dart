import '../../core/utils/tr_date.dart';

/// Everything the user did on one Istanbul day. Reset automatically when the
/// day key changes.
class DailyProgress {
  const DailyProgress({
    required this.date,
    this.solved = 0,
    this.correct = 0,
    this.xpEarned = 0,
    this.dailyQuestionAnswered = false,
    this.completedSubjectSessions = const <String>{},
    this.claimedQuests = const <String>{},
  });

  final String date;
  final int solved;
  final int correct;
  final int xpEarned;
  final bool dailyQuestionAnswered;
  final Set<String> completedSubjectSessions;
  final Set<String> claimedQuests;

  double get accuracy => solved == 0 ? 0 : correct / solved;

  DailyProgress copyWith({
    String? date,
    int? solved,
    int? correct,
    int? xpEarned,
    bool? dailyQuestionAnswered,
    Set<String>? completedSubjectSessions,
    Set<String>? claimedQuests,
  }) => DailyProgress(
    date: date ?? this.date,
    solved: solved ?? this.solved,
    correct: correct ?? this.correct,
    xpEarned: xpEarned ?? this.xpEarned,
    dailyQuestionAnswered:
        dailyQuestionAnswered ?? this.dailyQuestionAnswered,
    completedSubjectSessions:
        completedSubjectSessions ?? this.completedSubjectSessions,
    claimedQuests: claimedQuests ?? this.claimedQuests,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'date': date,
    'solved': solved,
    'correct': correct,
    'xp_earned': xpEarned,
    'daily_question_answered': dailyQuestionAnswered,
    'completed_subject_sessions': completedSubjectSessions.toList(),
    'claimed_quests': claimedQuests.toList(),
  };

  factory DailyProgress.fromJson(Map<String, dynamic> json) => DailyProgress(
    date: json['date'] as String,
    solved: (json['solved'] as num?)?.toInt() ?? 0,
    correct: (json['correct'] as num?)?.toInt() ?? 0,
    xpEarned: (json['xp_earned'] as num?)?.toInt() ?? 0,
    dailyQuestionAnswered: json['daily_question_answered'] as bool? ?? false,
    completedSubjectSessions:
        (json['completed_subject_sessions'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toSet(),
    claimedQuests: (json['claimed_quests'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toSet(),
  );

  factory DailyProgress.empty(String date) => DailyProgress(date: date);
}

class SubjectStats {
  const SubjectStats({this.solved = 0, this.correct = 0});

  final int solved;
  final int correct;

  double get accuracy => solved == 0 ? 0 : correct / solved;

  SubjectStats add({required int solved, required int correct}) =>
      SubjectStats(solved: this.solved + solved, correct: this.correct + correct);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'solved': solved,
    'correct': correct,
  };

  factory SubjectStats.fromJson(Map<String, dynamic> json) => SubjectStats(
    solved: (json['solved'] as num?)?.toInt() ?? 0,
    correct: (json['correct'] as num?)?.toInt() ?? 0,
  );
}

enum ExamTrack {
  tyt('TYT'),
  sayisal('Sayısal'),
  esitAgirlik('Eşit Ağırlık'),
  sozel('Sözel'),
  dil('Dil'),
  undecided('Henüz seçmedim');

  const ExamTrack(this.storageValue);

  final String storageValue;

  static ExamTrack fromStorage(String? value) {
    for (final track in ExamTrack.values) {
      if (track.storageValue == value) return track;
    }
    return ExamTrack.undecided;
  }
}

/// The local, offline-first snapshot of a user's whole game state. This is the
/// source of truth on device; Supabase mirrors it for cross-device sync and the
/// leaderboard.
class UserProgress {
  const UserProgress({
    required this.username,
    required this.avatarId,
    required this.examTrack,
    required this.today,
    this.totalXp = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCompletedDate,
    this.totalQuestions = 0,
    this.totalCorrect = 0,
    this.bestCombo = 0,
    this.studyDays = const <String>{},
    this.subjectStats = const <String, SubjectStats>{},
    this.weeklyXp = const <String, int>{},
    this.unlockedAchievements = const <String>{},
    this.createdAt,
  });

  final String username;
  final int avatarId;
  final ExamTrack examTrack;
  final DailyProgress today;
  final int totalXp;
  final int currentStreak;
  final int longestStreak;
  final String? lastCompletedDate;
  final int totalQuestions;
  final int totalCorrect;
  final int bestCombo;
  final Set<String> studyDays;
  final Map<String, SubjectStats> subjectStats;
  final Map<String, int> weeklyXp;
  final Set<String> unlockedAchievements;
  final String? createdAt;

  double get accuracy => totalQuestions == 0 ? 0 : totalCorrect / totalQuestions;

  int get currentWeekXp => weeklyXp[TrDate.weekStartKey()] ?? 0;

  Map<String, int> get questionsBySubject => subjectStats.map(
    (key, value) => MapEntry(key, value.solved),
  );

  UserProgress copyWith({
    String? username,
    int? avatarId,
    ExamTrack? examTrack,
    DailyProgress? today,
    int? totalXp,
    int? currentStreak,
    int? longestStreak,
    String? lastCompletedDate,
    int? totalQuestions,
    int? totalCorrect,
    int? bestCombo,
    Set<String>? studyDays,
    Map<String, SubjectStats>? subjectStats,
    Map<String, int>? weeklyXp,
    Set<String>? unlockedAchievements,
    String? createdAt,
  }) => UserProgress(
    username: username ?? this.username,
    avatarId: avatarId ?? this.avatarId,
    examTrack: examTrack ?? this.examTrack,
    today: today ?? this.today,
    totalXp: totalXp ?? this.totalXp,
    currentStreak: currentStreak ?? this.currentStreak,
    longestStreak: longestStreak ?? this.longestStreak,
    lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
    totalQuestions: totalQuestions ?? this.totalQuestions,
    totalCorrect: totalCorrect ?? this.totalCorrect,
    bestCombo: bestCombo ?? this.bestCombo,
    studyDays: studyDays ?? this.studyDays,
    subjectStats: subjectStats ?? this.subjectStats,
    weeklyXp: weeklyXp ?? this.weeklyXp,
    unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'username': username,
    'avatar_id': avatarId,
    'exam_track': examTrack.storageValue,
    'today': today.toJson(),
    'total_xp': totalXp,
    'current_streak': currentStreak,
    'longest_streak': longestStreak,
    'last_completed_date': lastCompletedDate,
    'total_questions': totalQuestions,
    'total_correct': totalCorrect,
    'best_combo': bestCombo,
    'study_days': studyDays.toList(),
    'subject_stats': subjectStats.map((k, v) => MapEntry(k, v.toJson())),
    'weekly_xp': weeklyXp,
    'unlocked_achievements': unlockedAchievements.toList(),
    'created_at': createdAt,
  };

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    final rawSubjects =
        (json['subject_stats'] as Map<String, dynamic>? ?? const {});
    final rawWeekly = (json['weekly_xp'] as Map<String, dynamic>? ?? const {});
    return UserProgress(
      username: json['username'] as String? ?? '',
      avatarId: (json['avatar_id'] as num?)?.toInt() ?? 0,
      examTrack: ExamTrack.fromStorage(json['exam_track'] as String?),
      today: json['today'] == null
          ? DailyProgress.empty(TrDate.todayKey())
          : DailyProgress.fromJson(json['today'] as Map<String, dynamic>),
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      lastCompletedDate: json['last_completed_date'] as String?,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      totalCorrect: (json['total_correct'] as num?)?.toInt() ?? 0,
      bestCombo: (json['best_combo'] as num?)?.toInt() ?? 0,
      studyDays: (json['study_days'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toSet(),
      subjectStats: rawSubjects.map(
        (k, v) => MapEntry(k, SubjectStats.fromJson(v as Map<String, dynamic>)),
      ),
      weeklyXp: rawWeekly.map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      ),
      unlockedAchievements:
          (json['unlocked_achievements'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toSet(),
      createdAt: json['created_at'] as String?,
    );
  }

  factory UserProgress.initial({String username = ''}) => UserProgress(
    username: username,
    avatarId: 0,
    examTrack: ExamTrack.undecided,
    today: DailyProgress.empty(TrDate.todayKey()),
    createdAt: TrDate.todayKey(),
  );
}
