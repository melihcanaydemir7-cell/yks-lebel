import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yks_level/core/widgets/state_views.dart';
import 'package:yks_level/data/models/content.dart';
import 'package:yks_level/features/home/home_screen.dart';
import 'package:yks_level/services/local_store.dart';
import 'package:yks_level/state/content_providers.dart';
import 'package:yks_level/state/providers.dart';

import '../helpers.dart';

const _question = Question(
  id: 'demo-mat-001',
  examType: 'TYT',
  subjectCode: 'tyt_matematik',
  topicCode: 'temel_kavramlar',
  text: 'a = 5 ve b = -3 olduğuna göre, 2a - 3b kaçtır?',
  optionA: '1',
  optionB: '11',
  optionC: '19',
  optionD: '21',
  optionE: '29',
  correctOption: 'C',
);

const _fact = DailyFact(
  id: 'fact-001',
  text: 'Bir üçgende iç açıların ölçüleri toplamı 180 derecedir.',
);

void main() {
  late LocalStore store;

  setUp(() async {
    setUpTestClock(now: DateTime.utc(2026, 3, 12, 12));
    store = await createTestStore();
  });
  tearDown(resetTestClock);

  testWidgets('shows a loading state while daily content is in flight',
      (tester) async {
    await pumpApp(
      tester,
      const HomeScreen(),
      store: store,
      overrides: [
        dailyQuestionProvider.overrideWith(
          (ref) => Completer<Question?>().future,
        ),
        dailyFactProvider.overrideWith((ref) => Completer<DailyFact?>().future),
      ],
    );

    expect(find.byType(AppLoadingView), findsWidgets);
  });

  testWidgets('renders the gamified core: level, quests, daily question, stats',
      (tester) async {
    await pumpApp(
      tester,
      const HomeScreen(),
      store: store,
      overrides: [
        dailyQuestionProvider.overrideWith((ref) async => _question),
        dailyFactProvider.overrideWith((ref) async => _fact),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('LVL 1'), findsOneWidget);
    expect(find.text('Bugünün Görevleri'), findsOneWidget);
    expect(find.text('5 soru çöz'), findsOneWidget);
    expect(find.text('Günün Sorusu'), findsOneWidget);
    expect(find.text('Bugünün Bilgisi'), findsOneWidget);
    expect(find.text('Bugünkü Özetin'), findsOneWidget);
    expect(find.textContaining('Bir sonraki seviyeye'), findsOneWidget);
  });

  testWidgets('shows a Turkish error with retry when daily content fails',
      (tester) async {
    await pumpApp(
      tester,
      const HomeScreen(),
      store: store,
      overrides: [
        dailyQuestionProvider.overrideWith(
          (ref) => Future<Question?>.error(Exception('offline')),
        ),
        dailyFactProvider.overrideWith((ref) async => _fact),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorView), findsOneWidget);
    expect(
      find.text('Bir şeyler ters gitti. Tekrar deneyebilirsin.'),
      findsOneWidget,
    );
    expect(find.text('Tekrar Dene'), findsOneWidget);
  });

  testWidgets('offers account creation to a guest when auth is configured',
      (tester) async {
    await pumpApp(
      tester,
      const HomeScreen(),
      store: store,
      overrides: [
        authAvailableProvider.overrideWithValue(true),
        dailyQuestionProvider.overrideWith((ref) async => _question),
        dailyFactProvider.overrideWith((ref) async => _fact),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('İlerlemeni kaybetme'), findsOneWidget);
    expect(find.text('Hesap Oluştur'), findsOneWidget);
  });

  testWidgets('hides the account CTA when Supabase is not configured',
      (tester) async {
    await pumpApp(
      tester,
      const HomeScreen(),
      store: store,
      overrides: [
        dailyQuestionProvider.overrideWith((ref) async => _question),
        dailyFactProvider.overrideWith((ref) async => _fact),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Hesap Oluştur'), findsNothing);
    // The study loop itself still works without any backend.
    expect(find.text('Bugünün Görevleri'), findsOneWidget);
  });
}
