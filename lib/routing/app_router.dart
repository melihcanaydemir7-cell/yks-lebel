import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/quiz.dart';
import '../features/achievements/achievements_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/home/home_screen.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/profile_setup_screen.dart';
import '../features/premium/premium_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/quiz/quiz_result_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/study/study_screen.dart';
import '../features/study/topic_list_screen.dart';
import '../state/app_flow_controller.dart';
import '../state/providers.dart';
import 'app_shell.dart';

class AppRoutes {
  const AppRoutes._();

  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String setup = '/setup';
  static const String home = '/home';
  static const String study = '/study';
  static const String league = '/league';
  static const String profile = '/profile';
  static const String achievements = '/profile/achievements';
  static const String settings = '/settings';
  static const String premium = '/premium';
  static const String quiz = '/quiz';
  static const String quizResult = '/quiz/result';

  static String subjectTopics(String subjectCode) => '/study/$subjectCode';
}

/// Arguments for a quiz session, passed through GoRouter `extra`.
class QuizArgs {
  const QuizArgs({
    required this.subjectCode,
    required this.source,
    this.topicCode,
    this.questionCount,
  });

  final String subjectCode;
  final String? topicCode;
  final QuizSource source;
  final int? questionCount;
}

/// Exposed so post-frame bootstrap code can reach a context that sits
/// *below* MaterialApp and therefore has Localizations available.
final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _FlowRefreshNotifier();
  ref.listen<AppFlowState>(
    appFlowControllerProvider,
    (_, _) => refresh.bump(),
  );
  ref.onDispose(refresh.dispose);

  // Automatic screen_view tracking; null (and therefore absent) when Firebase
  // is not configured.
  final analyticsObserver = ref.watch(analyticsProvider).navigatorObserver;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    observers: [?analyticsObserver],
    redirect: (context, state) {
      final flow = ref.read(appFlowControllerProvider);
      final path = state.matchedLocation;

      if (!flow.onboardingCompleted) {
        return path == AppRoutes.onboarding ? null : AppRoutes.onboarding;
      }
      if (!flow.authGateCompleted) {
        return path == AppRoutes.auth ? null : AppRoutes.auth;
      }
      if (!flow.profileReady) {
        return path == AppRoutes.setup ? null : AppRoutes.setup;
      }
      if (path == AppRoutes.onboarding ||
          path == AppRoutes.auth ||
          path == AppRoutes.setup) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(path: AppRoutes.auth, builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: AppRoutes.setup,
        builder: (_, _) => const ProfileSetupScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (_, _) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.study,
            pageBuilder: (_, _) => const NoTransitionPage(child: StudyScreen()),
          ),
          GoRoute(
            path: AppRoutes.league,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: LeaderboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/study/:subjectCode',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => TopicListScreen(
          subjectCode: state.pathParameters['subjectCode']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.achievements,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const AchievementsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.premium,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PremiumScreen(),
      ),
      GoRoute(
        path: AppRoutes.quiz,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => QuizScreen(args: state.extra! as QuizArgs),
      ),
      GoRoute(
        path: AppRoutes.quizResult,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            QuizResultScreen(args: state.extra! as QuizResultArgs),
      ),
    ],
  );
});

class _FlowRefreshNotifier extends ChangeNotifier {
  void bump() => notifyListeners();
}
