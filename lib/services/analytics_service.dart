import 'dart:developer' as developer;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';

/// Canonical event names. Keeping them in one enum stops typos from silently
/// breaking the funnel dashboards.
class AnalyticsEvents {
  const AnalyticsEvents._();

  static const String appOpen = 'app_open';
  static const String onboardingStarted = 'onboarding_started';
  static const String onboardingCompleted = 'onboarding_completed';
  static const String signupStarted = 'signup_started';
  static const String signupCompleted = 'signup_completed';
  static const String quizStarted = 'quiz_started';
  static const String questionAnswered = 'question_answered';
  static const String quizCompleted = 'quiz_completed';
  static const String dailyQuestCompleted = 'daily_quest_completed';
  static const String streakIncremented = 'streak_incremented';
  static const String levelUp = 'level_up';
  static const String leaderboardViewed = 'leaderboard_viewed';
  static const String premiumScreenViewed = 'premium_screen_viewed';
  static const String subscriptionStarted = 'subscription_started';
  static const String subscriptionSuccess = 'subscription_success';
  static const String subscriptionFailed = 'subscription_failed';
  static const String rewardedAdOffered = 'rewarded_ad_offered';
  static const String rewardedAdStarted = 'rewarded_ad_started';
  static const String rewardedAdCompleted = 'rewarded_ad_completed';
  static const String interstitialShown = 'interstitial_shown';
}

/// Wraps Firebase Analytics so the rest of the app never has to care whether
/// Firebase is configured. No PII is ever sent — only gameplay dimensions.
class AnalyticsService {
  AnalyticsService([this._analytics]);

  final FirebaseAnalytics? _analytics;

  FirebaseAnalyticsObserver? get navigatorObserver => _analytics == null
      ? null
      : FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logEvent(
    String name, [
    Map<String, Object?> parameters = const <String, Object?>{},
  ]) async {
    final sanitized = <String, Object>{};
    parameters.forEach((key, value) {
      if (value == null) return;
      sanitized[key] = value is num || value is String ? value : value.toString();
    });

    if (AppConfig.verboseLogging) {
      developer.log('[analytics] $name $sanitized', name: 'YKSLevel');
    }

    if (_analytics == null) return;
    try {
      await _analytics.logEvent(name: name, parameters: sanitized);
    } catch (error, stack) {
      debugPrintStack(stackTrace: stack, label: 'analytics: $error');
    }
  }

  Future<void> setUserProperties({
    required bool isPremium,
    required String examTrack,
    required int level,
  }) async {
    if (_analytics == null) return;
    try {
      await _analytics.setUserProperty(
        name: 'is_premium',
        value: isPremium.toString(),
      );
      await _analytics.setUserProperty(name: 'exam_track', value: examTrack);
      await _analytics.setUserProperty(name: 'level', value: level.toString());
    } catch (_) {
      // Analytics must never break the app.
    }
  }
}
