import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:yks_level/core/theme/app_theme.dart';
import 'package:yks_level/core/utils/tr_date.dart';
import 'package:yks_level/data/models/quiz.dart';
import 'package:yks_level/l10n/app_localizations.dart';
import 'package:yks_level/services/local_store.dart';
import 'package:yks_level/state/providers.dart';

/// Installs the timezone database once per test file and pins "now" so day and
/// week boundaries are deterministic.
void setUpTestClock({DateTime? now}) {
  tz_data.initializeTimeZones();
  if (now != null) TrDate.clock = () => now;
}

void resetTestClock() {
  TrDate.clock = DateTime.now;
}

Future<LocalStore> createTestStore([
  Map<String, Object> initialValues = const {},
]) async {
  SharedPreferences.setMockInitialValues(initialValues);
  return LocalStore.create();
}

/// Wraps a widget with everything the app's screens expect: Riverpod, the
/// Turkish localizations and the real theme.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  required LocalStore store,
  List<Override> overrides = const [],
  // Tall enough that a whole scrolling screen is laid out at once, so tests
  // can assert on content without scripting scrolls.
  Size surfaceSize = const Size(420, 2400),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(store), ...overrides],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        locale: const Locale('tr'),
        home: child,
      ),
    ),
  );
  await tester.pump();
}

QuizResult buildQuizResult({
  String subjectCode = 'tyt_matematik',
  String? topicCode = 'temel_kavramlar',
  QuizSource source = QuizSource.topic,
  int total = 10,
  int correct = 8,
  int baseXp = 100,
  int bestCombo = 5,
  Duration duration = const Duration(minutes: 4, seconds: 32),
}) => QuizResult(
  subjectCode: subjectCode,
  topicCode: topicCode,
  source: source,
  total: total,
  correct: correct,
  baseXp: baseXp,
  bestCombo: bestCombo,
  duration: duration,
  attempts: const [],
);
