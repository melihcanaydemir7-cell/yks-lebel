import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/tr_date.dart';
import 'models/content.dart';

/// Thrown when neither Supabase nor the bundled assets could provide content.
class ContentUnavailableException implements Exception {
  const ContentUnavailableException(this.message);
  final String message;

  @override
  String toString() => 'ContentUnavailableException: $message';
}

abstract class ContentSource {
  Future<List<Subject>> fetchSubjects();

  Future<List<Question>> fetchQuestions({
    String? subjectCode,
    String? topicCode,
    int limit,
  });

  Future<List<DailyFact>> fetchFacts();
}

/// Bundled demo content. Guarantees the app is fully usable before any backend
/// is wired up, and acts as the offline fallback afterwards.
class AssetContentSource implements ContentSource {
  static const String catalogPath = 'assets/seed/catalog.json';
  static const String questionsPath = 'assets/seed/questions.json';
  static const String factsPath = 'assets/seed/facts.json';

  List<Subject>? _subjects;
  List<Question>? _questions;
  List<DailyFact>? _facts;

  @override
  Future<List<Subject>> fetchSubjects() async {
    if (_subjects != null) return _subjects!;
    final raw = jsonDecode(await rootBundle.loadString(catalogPath))
        as Map<String, dynamic>;
    _subjects =
        (raw['subjects'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(Subject.fromJson)
            .toList(growable: false)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return _subjects!;
  }

  @override
  Future<List<Question>> fetchQuestions({
    String? subjectCode,
    String? topicCode,
    int limit = 50,
  }) async {
    _questions ??= (jsonDecode(await rootBundle.loadString(questionsPath))
            as Map<String, dynamic>)['questions']
        .cast<Map<String, dynamic>>()
        .map<Question>(Question.fromJson)
        .toList(growable: false);

    final filtered = _questions!.where((q) {
      if (subjectCode != null && q.subjectCode != subjectCode) return false;
      if (topicCode != null && q.topicCode != topicCode) return false;
      return true;
    }).toList(growable: false);

    return filtered.take(limit).toList(growable: false);
  }

  @override
  Future<List<DailyFact>> fetchFacts() async {
    if (_facts != null) return _facts!;
    final raw = jsonDecode(await rootBundle.loadString(factsPath))
        as Map<String, dynamic>;
    _facts = (raw['facts'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(DailyFact.fromJson)
        .toList(growable: false);
    return _facts!;
  }
}

class SupabaseContentSource implements ContentSource {
  SupabaseContentSource(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Subject>> fetchSubjects() async {
    final subjects = await _client
        .from('subjects')
        .select('code, name, exam_type, icon, color, sort_order, is_active')
        .order('sort_order');

    final topics = await _client
        .from('topics')
        .select('code, name, sort_order, is_active, subjects!inner(code)')
        .eq('is_active', true)
        .order('sort_order');

    final topicsBySubject = <String, List<Map<String, dynamic>>>{};
    for (final row in topics as List<dynamic>) {
      final map = row as Map<String, dynamic>;
      final subjectCode =
          (map['subjects'] as Map<String, dynamic>?)?['code'] as String?;
      if (subjectCode == null) continue;
      topicsBySubject.putIfAbsent(subjectCode, () => []).add(map);
    }

    return (subjects as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => Subject.fromJson({
            ...row,
            'topics': topicsBySubject[row['code']] ?? const [],
          }),
        )
        .toList(growable: false);
  }

  @override
  Future<List<Question>> fetchQuestions({
    String? subjectCode,
    String? topicCode,
    int limit = 50,
  }) async {
    var query = _client
        .from('questions')
        .select(
          'id, exam_type, year, question_text, question_image_url, '
          'option_a, option_b, option_c, option_d, option_e, correct_option, '
          'explanation, difficulty, subjects!inner(code), topics(code)',
        )
        .eq('is_active', true);

    if (subjectCode != null) {
      query = query.eq('subjects.code', subjectCode);
    }
    if (topicCode != null) {
      query = query.eq('topics.code', topicCode);
    }

    final rows = await query.limit(limit);
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => Question.fromJson({
            ...row,
            'subject': (row['subjects'] as Map<String, dynamic>?)?['code'],
            'topic': (row['topics'] as Map<String, dynamic>?)?['code'] ?? '',
          }),
        )
        .toList(growable: false);
  }

  @override
  Future<List<DailyFact>> fetchFacts() async {
    final rows = await _client
        .from('app_content')
        .select('id, body, subject_code')
        .eq('content_type', 'daily_fact')
        .eq('is_active', true)
        .limit(100);

    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => DailyFact(
            id: row['id'].toString(),
            text: row['body'] as String,
            subjectCode: row['subject_code'] as String?,
          ),
        )
        .toList(growable: false);
  }
}

/// Reads from the remote source when available and transparently falls back to
/// the bundled demo content, so a network blip never blocks studying.
class ContentRepository {
  ContentRepository([this._remote, AssetContentSource? bundled])
    : _bundled = bundled ?? AssetContentSource();

  final ContentSource? _remote;
  final AssetContentSource _bundled;

  List<Subject>? _subjectCache;
  final Map<String, List<Question>> _questionCache = {};
  List<DailyFact>? _factCache;

  Future<List<Subject>> subjects({bool refresh = false}) async {
    if (!refresh && _subjectCache != null) return _subjectCache!;
    final result = await _withFallback(
      remote: () => _remote?.fetchSubjects(),
      bundled: _bundled.fetchSubjects,
      label: 'subjects',
    );
    return _subjectCache = result;
  }

  Future<Subject?> subjectByCode(String code) async {
    final all = await subjects();
    for (final subject in all) {
      if (subject.code == code) return subject;
    }
    return null;
  }

  Future<List<Question>> questions({
    String? subjectCode,
    String? topicCode,
    int limit = 50,
  }) async {
    final key = '${subjectCode ?? '*'}|${topicCode ?? '*'}|$limit';
    final cached = _questionCache[key];
    if (cached != null) return cached;

    final result = await _withFallback(
      remote: () => _remote?.fetchQuestions(
        subjectCode: subjectCode,
        topicCode: topicCode,
        limit: limit,
      ),
      bundled: () => _bundled.fetchQuestions(
        subjectCode: subjectCode,
        topicCode: topicCode,
        limit: limit,
      ),
      label: 'questions',
    );

    // An empty remote result for a topic that has no content yet should still
    // fall back to the demo bank so the user is never stuck on an empty quiz.
    if (result.isEmpty && _remote != null) {
      final fallback = await _bundled.fetchQuestions(
        subjectCode: subjectCode,
        topicCode: topicCode,
        limit: limit,
      );
      if (fallback.isNotEmpty) return _questionCache[key] = fallback;
    }

    return _questionCache[key] = result;
  }

  /// Builds a session: shuffled, at most [count] questions. Falls back to the
  /// whole subject when a topic has too little content.
  Future<List<Question>> sessionQuestions({
    required int count,
    String? subjectCode,
    String? topicCode,
    int? seed,
  }) async {
    var pool = await questions(
      subjectCode: subjectCode,
      topicCode: topicCode,
      limit: 200,
    );

    if (pool.length < count && topicCode != null) {
      pool = await questions(subjectCode: subjectCode, limit: 200);
    }
    if (pool.length < count && subjectCode != null) {
      pool = await questions(limit: 200);
    }
    if (pool.isEmpty) {
      throw const ContentUnavailableException('no questions available');
    }

    final shuffled = List<Question>.of(pool)..shuffle(Random(seed));
    return shuffled.take(count).toList(growable: false);
  }

  Future<List<DailyFact>> facts() async {
    if (_factCache != null) return _factCache!;
    return _factCache = await _withFallback(
      remote: () => _remote?.fetchFacts(),
      bundled: _bundled.fetchFacts,
      label: 'facts',
    );
  }

  /// Deterministic per-day picks so every user sees the same daily content and
  /// it stays stable across app restarts.
  Future<DailyFact?> factOfTheDay([String? dayKey]) async {
    final all = await facts();
    if (all.isEmpty) return null;
    final key = dayKey ?? TrDate.todayKey();
    return all[TrDate.dayHash(key) % all.length];
  }

  Future<Question?> questionOfTheDay([String? dayKey]) async {
    final pool = await questions(limit: 200);
    if (pool.isEmpty) return null;
    final key = dayKey ?? TrDate.todayKey();
    final sorted = List<Question>.of(pool)
      ..sort((a, b) => a.id.compareTo(b.id));
    return sorted[TrDate.dayHash(key) % sorted.length];
  }

  void invalidate() {
    _subjectCache = null;
    _questionCache.clear();
    _factCache = null;
  }

  Future<List<T>> _withFallback<T>({
    required Future<List<T>>? Function() remote,
    required Future<List<T>> Function() bundled,
    required String label,
  }) async {
    try {
      final future = remote();
      if (future != null) {
        final result = await future;
        if (result.isNotEmpty) return result;
      }
    } catch (error) {
      debugPrint('Remote $label failed, using bundled content: $error');
    }
    return bundled();
  }
}
