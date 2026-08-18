// Renders the real screens headlessly and writes PNGs to screenshots/.
//
// This is a generator, not an assertion: it is skipped during a normal
// `flutter test` run and only executes when GENERATE_SCREENSHOTS=1 is set.
//
//   GENERATE_SCREENSHOTS=1 EMOJI_FONT=/path/to/NotoColorEmoji.ttf \
//     flutter test test/screenshots
//
// Useful for store listings and for reviewing UI changes without a device.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:yks_level/core/theme/app_theme.dart';
import 'package:yks_level/core/utils/tr_date.dart';
import 'package:yks_level/data/content_repository.dart';
import 'package:yks_level/data/models/content.dart';
import 'package:yks_level/data/models/leaderboard.dart';
import 'package:yks_level/data/models/progress.dart';
import 'package:yks_level/data/models/quiz.dart';
import 'package:yks_level/domain/daily_quest.dart';
import 'package:yks_level/domain/progress_engine.dart';
import 'package:yks_level/domain/xp.dart';
import 'package:yks_level/features/achievements/achievements_screen.dart';
import 'package:yks_level/features/auth/auth_screen.dart';
import 'package:yks_level/features/home/home_screen.dart';
import 'package:yks_level/features/leaderboard/leaderboard_screen.dart';
import 'package:yks_level/features/onboarding/onboarding_screen.dart';
import 'package:yks_level/features/onboarding/profile_setup_screen.dart';
import 'package:yks_level/features/premium/premium_screen.dart';
import 'package:yks_level/features/profile/profile_screen.dart';
import 'package:yks_level/features/quiz/quiz_result_screen.dart';
import 'package:yks_level/features/quiz/quiz_screen.dart';
import 'package:yks_level/features/settings/settings_screen.dart';
import 'package:yks_level/features/study/study_screen.dart';
import 'package:yks_level/features/study/topic_list_screen.dart';
import 'package:yks_level/l10n/app_localizations.dart';
import 'package:yks_level/routing/app_router.dart';
import 'package:yks_level/routing/app_shell.dart';
import 'package:yks_level/services/ad_service.dart';
import 'package:yks_level/services/auth_service.dart';
import 'package:yks_level/services/billing_service.dart';
import 'package:yks_level/services/local_store.dart';
import 'package:yks_level/state/content_providers.dart';
import 'package:yks_level/state/providers.dart';

final bool _enabled = Platform.environment['GENERATE_SCREENSHOTS'] == '1';
final String _outputDir = Platform.environment['SCREENSHOT_DIR'] ?? 'screenshots';

/// A Thursday afternoon in Istanbul — keeps day and week keys deterministic.
final DateTime _now = DateTime.utc(2026, 3, 12, 12);

const Size _phone = Size(390, 844);
const double _pixelRatio = 3;

// ---------------------------------------------------------------- demo data

const Question _mathQuestion = Question(
  id: 'demo-mat-001',
  examType: 'TYT',
  subjectCode: 'tyt_matematik',
  topicCode: 'temel_kavramlar',
  text: 'x ve y tam sayıları için x · y = 24 ve x + y = 11 olduğuna göre, '
      'x² + y² kaçtır?',
  optionA: '49',
  optionB: '61',
  optionC: '73',
  optionD: '85',
  optionE: '97',
  correctOption: 'C',
  explanation: '(x + y)² = x² + y² + 2xy eşitliğinden 121 = x² + y² + 48 olur. '
      'Buradan x² + y² = 73 bulunur.',
);

const DailyFact _fact = DailyFact(
  id: 'fact-001',
  text: 'Bir üçgende iç açıların ölçüleri toplamı 180°’dir.',
);

const List<(String, int, int)> _leaderboard = [
  ('Zeynep', 4, 2140),
  ('Emir', 1, 1980),
  ('Elif', 6, 1875),
  ('Melih', 3, 1240),
  ('Yusuf', 2, 1120),
  ('Defne', 7, 980),
  ('Kerem', 0, 815),
  ('Azra', 5, 690),
];

UserProgress _seededProgress() => UserProgress(
  username: 'Melih',
  avatarId: 3,
  examTrack: ExamTrack.sayisal,
  today: const DailyProgress(
    date: '2026-03-12',
    solved: 3,
    correct: 2,
    xpEarned: 34,
  ),
  totalXp: XpService.cumulativeXpForLevel(12) + 380,
  currentStreak: 12,
  longestStreak: 21,
  lastCompletedDate: '2026-03-11',
  totalQuestions: 157,
  totalCorrect: 117,
  bestCombo: 9,
  studyDays: {for (var i = 0; i < 24; i++) '2026-02-${(i + 1).toString().padLeft(2, '0')}'},
  subjectStats: const {
    'tyt_matematik': SubjectStats(solved: 84, correct: 62),
    'tyt_turkce': SubjectStats(solved: 51, correct: 40),
    'tyt_fizik': SubjectStats(solved: 22, correct: 15),
  },
  weeklyXp: {TrDate.weekStartKey(): 1240},
  unlockedAchievements: const {
    'first_step',
    'warming_up',
    'hundred',
    'streak_start',
    'one_week',
  },
);

// ------------------------------------------------------------------- fakes

/// Returns the same question ten times over. The session shuffles its pool, so
/// identical entries are what make the captured question — and therefore the
/// correct option — deterministic, while the header still reads a realistic
/// "1 / 10".
class _FixedQuestions implements ContentSource {
  const _FixedQuestions();

  static List<Question> get _pool => <Question>[
    for (var i = 0; i < 10; i++)
      Question(
        id: 'demo-mat-001-$i',
        examType: _mathQuestion.examType,
        subjectCode: _mathQuestion.subjectCode,
        topicCode: _mathQuestion.topicCode,
        text: _mathQuestion.text,
        optionA: _mathQuestion.optionA,
        optionB: _mathQuestion.optionB,
        optionC: _mathQuestion.optionC,
        optionD: _mathQuestion.optionD,
        optionE: _mathQuestion.optionE,
        correctOption: _mathQuestion.correctOption,
        explanation: _mathQuestion.explanation,
      ),
  ];

  @override
  Future<List<Subject>> fetchSubjects() async => const [];

  @override
  Future<List<DailyFact>> fetchFacts() async => const [_fact];

  @override
  Future<List<Question>> fetchQuestions({
    String? subjectCode,
    String? topicCode,
    int limit = 50,
  }) async => _pool;
}

class _RewardedReadyAds implements AdService {
  const _RewardedReadyAds();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> preloadRewarded() async {}

  @override
  bool get isRewardedReady => true;

  @override
  Future<bool> showRewarded() async => true;

  @override
  Future<bool> maybeShowInterstitial() async => false;

  @override
  void dispose() {}
}

// ------------------------------------------------------------------ harness

const String _emojiFamily = 'NotoColorEmoji';
bool _emojiAvailable = false;

/// Emoji carry real meaning in this UI (streak flame, level-up, medals), so the
/// harness wires a colour-emoji fallback into the text theme.
ThemeData _withEmojiFallback(ThemeData base) {
  if (!_emojiAvailable) return base;
  const fallback = <String>[_emojiFamily];
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamilyFallback: fallback),
  );
}

Future<ByteData> _readFont(String path) async =>
    ByteData.view(Uint8List.fromList(await File(path).readAsBytes()).buffer);

Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final emojiFont = Platform.environment['EMOJI_FONT'];

  final nunito = FontLoader('Nunito');
  for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    nunito.addFont(_readFont('assets/fonts/Nunito-$weight.ttf'));
  }
  await nunito.load();

  // Registered as its own family and wired in through fontFamilyFallback,
  // which is how the engine resolves glyphs Nunito has no coverage for.
  if (emojiFont != null && File(emojiFont).existsSync()) {
    final emoji = FontLoader(_emojiFamily)..addFont(_readFont(emojiFont));
    await emoji.load();
    _emojiAvailable = true;
  }

  if (flutterRoot != null) {
    final fonts = '$flutterRoot/bin/cache/artifacts/material_fonts';
    final icons = FontLoader('MaterialIcons')
      ..addFont(_readFont('$fonts/MaterialIcons-Regular.otf'));
    await icons.load();

    final roboto = FontLoader('Roboto')
      ..addFont(_readFont('$fonts/Roboto-Regular.ttf'))
      ..addFont(_readFont('$fonts/Roboto-Medium.ttf'))
      ..addFont(_readFont('$fonts/Roboto-Bold.ttf'));
    await roboto.load();
  }
}

final AssetContentSource _bundledContent = AssetContentSource();

Future<void> _warmBundledContent() async {
  await _bundledContent.fetchSubjects();
  await _bundledContent.fetchQuestions(limit: 200);
  await _bundledContent.fetchFacts();
}

Future<LocalStore> _store({UserProgress? progress}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'onboarding_completed': true,
    'auth_gate_completed': true,
    if (progress != null) 'user_progress': jsonEncode(progress.toJson()),
  });
  return LocalStore.create();
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required LocalStore store,
  List<Override> overrides = const [],
  bool dark = false,
}) async {
  tester.view
    ..devicePixelRatio = _pixelRatio
    ..physicalSize = _phone * _pixelRatio;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        contentRepositoryProvider.overrideWithValue(
          ContentRepository(null, _bundledContent),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _withEmojiFallback(dark ? AppTheme.dark() : AppTheme.light()),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        locale: const Locale('tr'),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _shoot(WidgetTester tester, String name) async {
  final element = find.byType(MaterialApp).evaluate().single;
  // Rasterising needs the real event loop: awaiting it inside the fake-async
  // test zone deadlocks until the 10-minute test timeout.
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outputDir/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() async {
    if (!_enabled) return;
    tz_data.initializeTimeZones();
    TrDate.clock = () => _now;
    await _loadFonts();
    await _warmBundledContent();
  });

  tearDownAll(() => TrDate.clock = DateTime.now);

  testWidgets('01 onboarding', (tester) async {
    await _pump(tester, const OnboardingScreen(), store: await _store());
    await _shoot(tester, '01_onboarding');
  }, skip: !_enabled);

  testWidgets('02 auth', (tester) async {
    await _pump(tester, const AuthScreen(), store: await _store());
    await _shoot(tester, '02_auth');
  }, skip: !_enabled);

  testWidgets('03 profile setup', (tester) async {
    await _pump(tester, const ProfileSetupScreen(), store: await _store());
    await _shoot(tester, '03_profile_setup');
  }, skip: !_enabled);

  testWidgets('04 home', (tester) async {
    await _pump(
      tester,
      const AppShell(location: AppRoutes.home, child: HomeScreen()),
      store: await _store(progress: _seededProgress()),
      overrides: [
        authAvailableProvider.overrideWithValue(true),
        dailyQuestionProvider.overrideWith((ref) async => _mathQuestion),
        dailyFactProvider.overrideWith((ref) async => _fact),
      ],
    );
    await _shoot(tester, '04_home');
  }, skip: !_enabled);

  testWidgets('05 home dark', (tester) async {
    await _pump(
      tester,
      const AppShell(location: AppRoutes.home, child: HomeScreen()),
      store: await _store(progress: _seededProgress()),
      dark: true,
      overrides: [
        authAvailableProvider.overrideWithValue(true),
        dailyQuestionProvider.overrideWith((ref) async => _mathQuestion),
        dailyFactProvider.overrideWith((ref) async => _fact),
      ],
    );
    await _shoot(tester, '05_home_dark');
  }, skip: !_enabled);

  testWidgets('06 study', (tester) async {
    await _pump(
      tester,
      const AppShell(location: AppRoutes.study, child: StudyScreen()),
      store: await _store(progress: _seededProgress()),
    );
    await _shoot(tester, '06_study');
  }, skip: !_enabled);

  testWidgets('07 topics', (tester) async {
    await _pump(
      tester,
      const TopicListScreen(subjectCode: 'tyt_matematik'),
      store: await _store(progress: _seededProgress()),
    );
    await _shoot(tester, '07_topics');
  }, skip: !_enabled);

  testWidgets('08+09 quiz question and feedback', (tester) async {
    await _pump(
      tester,
      const QuizScreen(
        args: QuizArgs(
          subjectCode: 'tyt_matematik',
          topicCode: 'temel_kavramlar',
          source: QuizSource.topic,
        ),
      ),
      store: await _store(progress: _seededProgress()),
      overrides: [
        contentRepositoryProvider.overrideWithValue(
          ContentRepository(const _FixedQuestions(), _bundledContent),
        ),
      ],
    );
    await _shoot(tester, '08_quiz_question');

    await tester.tap(find.text('73'));
    await tester.pumpAndSettle();
    await _shoot(tester, '09_quiz_correct');
  }, skip: !_enabled);

  testWidgets('10 quiz result', (tester) async {
    await _pump(
      tester,
      QuizResultScreen(
        args: QuizResultArgs(
          result: QuizResult(
            subjectCode: 'tyt_matematik',
            topicCode: 'temel_kavramlar',
            source: QuizSource.topic,
            total: 10,
            correct: 8,
            baseXp: 115,
            bestCombo: 5,
            duration: const Duration(minutes: 4, seconds: 32),
            attempts: const [],
          ),
          rewards: SessionRewards(
            sessionXp: 115,
            questXp: 50,
            levelBefore: 12,
            levelAfter: 12,
            streak: 13,
            streakIncremented: true,
            completedQuests: [DailyQuests.byId(DailyQuests.solveFive)!],
          ),
          origin: const QuizArgs(
            subjectCode: 'tyt_matematik',
            source: QuizSource.topic,
          ),
        ),
      ),
      store: await _store(progress: _seededProgress()),
      overrides: [adServiceProvider.overrideWithValue(const _RewardedReadyAds())],
    );
    await _shoot(tester, '10_quiz_result');
  }, skip: !_enabled);

  testWidgets('11 leaderboard', (tester) async {
    var rank = 0;
    final entries = _leaderboard.map((row) {
      rank++;
      return LeaderboardEntry(
        rank: rank,
        userId: 'user-$rank',
        username: row.$1,
        avatarId: row.$2,
        weeklyXp: row.$3,
        isCurrentUser: row.$1 == 'Melih',
      );
    }).toList();

    await _pump(
      tester,
      const AppShell(location: AppRoutes.league, child: LeaderboardScreen()),
      store: await _store(progress: _seededProgress()),
      overrides: [
        currentUserProvider.overrideWithValue(
          const AppUser(id: 'user-4', email: 'a@b.c', isGuest: false),
        ),
        leaderboardAvailableProvider.overrideWithValue(true),
        leaderboardProvider.overrideWith(
          (ref) async => LeaderboardPage(entries: entries),
        ),
      ],
    );
    await _shoot(tester, '11_leaderboard');
  }, skip: !_enabled);

  testWidgets('12 profile', (tester) async {
    await _pump(
      tester,
      const AppShell(location: AppRoutes.profile, child: ProfileScreen()),
      store: await _store(progress: _seededProgress()),
    );
    await _shoot(tester, '12_profile');
  }, skip: !_enabled);

  testWidgets('13 achievements', (tester) async {
    await _pump(
      tester,
      const AchievementsScreen(),
      store: await _store(progress: _seededProgress()),
    );
    await _shoot(tester, '13_achievements');
  }, skip: !_enabled);

  testWidgets('14 premium', (tester) async {
    await _pump(
      tester,
      const PremiumScreen(),
      store: await _store(progress: _seededProgress()),
      overrides: [
        premiumStatusProvider.overrideWith(
          (ref) => Stream.value(
            const PremiumStatus(
              state: PremiumState.free,
              storeAvailable: true,
              priceLabel: '₺59,99',
            ),
          ),
        ),
      ],
    );
    await _shoot(tester, '14_premium');
  }, skip: !_enabled);

  testWidgets('15 settings', (tester) async {
    await _pump(
      tester,
      const SettingsScreen(),
      store: await _store(progress: _seededProgress()),
      dark: true,
    );
    await _shoot(tester, '15_settings');
  }, skip: !_enabled);
}
