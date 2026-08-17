import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/app_settings.dart';
import '../data/models/progress.dart';

/// Thin, typed wrapper around SharedPreferences. The app is local-first: this
/// is where the authoritative game state lives on device.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _kOnboardingDone = 'onboarding_completed';
  static const String _kAuthGateDone = 'auth_gate_completed';
  static const String _kProgress = 'user_progress';
  static const String _kSettings = 'app_settings';
  static const String _kPremium = 'premium_status';
  static const String _kInterstitialCounter = 'interstitial_session_counter';

  static Future<LocalStore> create() async =>
      LocalStore(await SharedPreferences.getInstance());

  // ------------------------------------------------------------- onboarding
  bool get onboardingCompleted => _prefs.getBool(_kOnboardingDone) ?? false;

  Future<void> setOnboardingCompleted(bool value) =>
      _prefs.setBool(_kOnboardingDone, value);

  bool get authGateCompleted => _prefs.getBool(_kAuthGateDone) ?? false;

  Future<void> setAuthGateCompleted(bool value) =>
      _prefs.setBool(_kAuthGateDone, value);

  // --------------------------------------------------------------- progress
  UserProgress? readProgress() {
    final raw = _prefs.getString(_kProgress);
    if (raw == null) return null;
    try {
      return UserProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeProgress(UserProgress progress) =>
      _prefs.setString(_kProgress, jsonEncode(progress.toJson()));

  Future<void> clearProgress() => _prefs.remove(_kProgress);

  // --------------------------------------------------------------- settings
  AppSettings readSettings() {
    final raw = _prefs.getString(_kSettings);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> writeSettings(AppSettings settings) =>
      _prefs.setString(_kSettings, jsonEncode(settings.toJson()));

  // ---------------------------------------------------------------- premium
  /// Cached entitlement so premium users never see an ad on a cold start
  /// before the store finishes responding.
  bool get cachedPremium => _prefs.getBool(_kPremium) ?? false;

  Future<void> setCachedPremium(bool value) => _prefs.setBool(_kPremium, value);

  // ------------------------------------------------------------------- ads
  int get completedSessionsSinceInterstitial =>
      _prefs.getInt(_kInterstitialCounter) ?? 0;

  Future<void> setCompletedSessionsSinceInterstitial(int value) =>
      _prefs.setInt(_kInterstitialCounter, value);

  Future<void> clearAll() async {
    await _prefs.remove(_kProgress);
    await _prefs.remove(_kPremium);
    await _prefs.remove(_kInterstitialCounter);
  }
}
