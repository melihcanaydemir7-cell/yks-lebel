import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yks_level/features/quiz/quiz_screen.dart';
import 'package:yks_level/services/local_store.dart';

import '../helpers.dart';

void main() {
  late LocalStore store;

  setUp(() async {
    setUpTestClock();
    store = await createTestStore();
  });
  tearDown(resetTestClock);

  group('AnswerOption', () {
    testWidgets('reports taps while idle', (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        Scaffold(
          body: AnswerOption(
            optionKey: 'C',
            text: '19',
            state: AnswerState.idle,
            onTap: () => taps++,
          ),
        ),
        store: store,
      );

      expect(find.text('C'), findsOneWidget);
      expect(find.text('19'), findsOneWidget);

      await tester.tap(find.text('19'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('ignores taps once the answer is locked in', (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        Scaffold(
          body: Column(
            children: [
              AnswerOption(
                optionKey: 'A',
                text: 'yanlış',
                state: AnswerState.wrong,
                onTap: null,
              ),
              AnswerOption(
                optionKey: 'C',
                text: 'doğru',
                state: AnswerState.correct,
                onTap: () => taps++,
              ),
            ],
          ),
        ),
        store: store,
      );

      await tester.tap(find.text('yanlış'));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('marks the correct and the wrong option differently',
        (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: Column(
            children: [
              AnswerOption(
                optionKey: 'A',
                text: 'yanlış',
                state: AnswerState.wrong,
                onTap: null,
              ),
              AnswerOption(
                optionKey: 'C',
                text: 'doğru',
                state: AnswerState.correct,
                onTap: null,
              ),
              AnswerOption(
                optionKey: 'D',
                text: 'diğer',
                state: AnswerState.dimmed,
                onTap: null,
              ),
            ],
          ),
        ),
        store: store,
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    });
  });
}
