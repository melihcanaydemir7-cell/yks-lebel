import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/content.dart';
import 'providers.dart';

final subjectsProvider = FutureProvider<List<Subject>>(
  (ref) => ref.watch(contentRepositoryProvider).subjects(),
);

final subjectProvider = FutureProvider.family<Subject?, String>(
  (ref, code) => ref.watch(contentRepositoryProvider).subjectByCode(code),
);

final dailyQuestionProvider = FutureProvider<Question?>(
  (ref) => ref.watch(contentRepositoryProvider).questionOfTheDay(),
);

final dailyFactProvider = FutureProvider<DailyFact?>(
  (ref) => ref.watch(contentRepositoryProvider).factOfTheDay(),
);
