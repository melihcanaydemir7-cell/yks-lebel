class Topic {
  const Topic({
    required this.code,
    required this.name,
    required this.sortOrder,
    required this.subjectCode,
  });

  final String code;
  final String name;
  final int sortOrder;
  final String subjectCode;

  factory Topic.fromJson(Map<String, dynamic> json, String subjectCode) => Topic(
    code: json['code'] as String,
    name: json['name'] as String,
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    subjectCode: subjectCode,
  );
}

class Subject {
  const Subject({
    required this.code,
    required this.name,
    required this.examType,
    required this.icon,
    required this.color,
    required this.sortOrder,
    required this.isActive,
    required this.topics,
  });

  final String code;
  final String name;
  final String examType;
  final String icon;
  final int color;
  final int sortOrder;
  final bool isActive;
  final List<Topic> topics;

  factory Subject.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String;
    final rawTopics = (json['topics'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return Subject(
      code: code,
      name: json['name'] as String,
      examType: json['exam_type'] as String? ?? 'TYT',
      icon: json['icon'] as String? ?? 'school',
      color: _parseColor(json['color'] as String?),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      topics: rawTopics
          .map((t) => Topic.fromJson(t, code))
          .toList(growable: false)
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    );
  }

  static int _parseColor(String? hex) {
    if (hex == null) return 0xFF4F6BFF;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return 0xFF4F6BFF;
    return cleaned.length <= 6 ? 0xFF000000 | value : value;
  }
}

enum QuestionDifficulty { easy, medium, hard }

class Question {
  const Question({
    required this.id,
    required this.examType,
    required this.subjectCode,
    required this.topicCode,
    required this.text,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    this.optionE,
    this.explanation,
    this.imageUrl,
    this.year,
    this.difficulty = QuestionDifficulty.medium,
  });

  final String id;
  final String examType;
  final String subjectCode;
  final String topicCode;
  final String text;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String? optionE;
  final String correctOption;
  final String? explanation;
  final String? imageUrl;
  final int? year;
  final QuestionDifficulty difficulty;

  /// Option letters that actually exist for this question (E is optional).
  List<String> get optionKeys => <String>[
    'A',
    'B',
    'C',
    'D',
    if ((optionE ?? '').isNotEmpty) 'E',
  ];

  String optionText(String key) {
    switch (key) {
      case 'A':
        return optionA;
      case 'B':
        return optionB;
      case 'C':
        return optionC;
      case 'D':
        return optionD;
      case 'E':
        return optionE ?? '';
      default:
        return '';
    }
  }

  bool isCorrect(String key) => key.toUpperCase() == correctOption.toUpperCase();

  factory Question.fromJson(Map<String, dynamic> json) {
    final optionE = json['option_e'] as String?;
    return Question(
      id: json['id'].toString(),
      examType: json['exam_type'] as String? ?? 'TYT',
      subjectCode: (json['subject'] ?? json['subject_code']) as String,
      topicCode: (json['topic'] ?? json['topic_code']) as String? ?? '',
      text: json['question_text'] as String,
      optionA: json['option_a'] as String,
      optionB: json['option_b'] as String,
      optionC: json['option_c'] as String,
      optionD: json['option_d'] as String,
      optionE: (optionE == null || optionE.isEmpty) ? null : optionE,
      correctOption: (json['correct_option'] as String).toUpperCase(),
      explanation: json['explanation'] as String?,
      imageUrl: json['question_image_url'] as String?,
      year: (json['year'] as num?)?.toInt(),
      difficulty: _difficulty(json['difficulty'] as String?),
    );
  }

  static QuestionDifficulty _difficulty(String? raw) {
    switch (raw) {
      case 'easy':
        return QuestionDifficulty.easy;
      case 'hard':
        return QuestionDifficulty.hard;
      default:
        return QuestionDifficulty.medium;
    }
  }
}

class DailyFact {
  const DailyFact({required this.id, required this.text, this.subjectCode});

  final String id;
  final String text;
  final String? subjectCode;

  factory DailyFact.fromJson(Map<String, dynamic> json) => DailyFact(
    id: json['id'].toString(),
    text: (json['text'] ?? json['body']) as String,
    subjectCode: json['subject'] as String?,
  );
}
