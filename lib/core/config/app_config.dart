import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Build flavour. Selected with `--dart-define=APP_ENV=production`.
enum AppEnvironment { development, production }

/// Single source of truth for branding, remote credentials and store product
/// identifiers. Nothing here should be duplicated anywhere else in the app.
class AppConfig {
  const AppConfig._();

  // ---------------------------------------------------------------- branding
  static const String appName = 'YKS Level';
  static const String packageName = 'com.example.ykslevel';
  static const String supportEmail = 'destek@ykslevel.app';
  static const String privacyPolicyUrl = 'https://ykslevel.app/gizlilik';
  static const String termsUrl = 'https://ykslevel.app/kullanim-kosullari';

  // ------------------------------------------------------------- environment
  static const AppEnvironment environment = _envName == 'production'
      ? AppEnvironment.production
      : AppEnvironment.development;

  static const String _envName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static bool get isProduction => environment == AppEnvironment.production;
  static bool get isDevelopment => environment == AppEnvironment.development;

  /// Verbose logging is only enabled outside of production builds.
  static bool get verboseLogging => isDevelopment;

  // ---------------------------------------------------------------- supabase
  static String get supabaseUrl => _read('SUPABASE_URL');
  static String get supabaseAnonKey => _read('SUPABASE_ANON_KEY');

  /// `--dart-define` values win over `.env`, so CI can inject configuration
  /// without ever writing it to disk.
  static const Map<String, String> _defines = <String, String>{
    'SUPABASE_URL': String.fromEnvironment('SUPABASE_URL'),
    'SUPABASE_ANON_KEY': String.fromEnvironment('SUPABASE_ANON_KEY'),
    'ADMOB_REWARDED_AD_UNIT_ID': String.fromEnvironment(
      'ADMOB_REWARDED_AD_UNIT_ID',
    ),
    'ADMOB_INTERSTITIAL_AD_UNIT_ID': String.fromEnvironment(
      'ADMOB_INTERSTITIAL_AD_UNIT_ID',
    ),
    'ADS_ENABLED': String.fromEnvironment('ADS_ENABLED'),
  };

  /// When Supabase is not configured the app still runs end-to-end using the
  /// bundled demo content and local-only progress. See README "Known
  /// Limitations".
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Deep link used by the Supabase OAuth (Google) flow. Must match the
  /// intent-filter declared in AndroidManifest.xml.
  static const String authRedirectUrl = '$packageName://login-callback';

  // ------------------------------------------------------------------- ads
  /// Official Google test ad units. Never ship these in a production build —
  /// production values come from `.env`.
  static const String _testRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';

  static String get rewardedAdUnitId => isProduction
      ? _read('ADMOB_REWARDED_AD_UNIT_ID', fallback: _testRewardedId)
      : _testRewardedId;

  static String get interstitialAdUnitId => isProduction
      ? _read('ADMOB_INTERSTITIAL_AD_UNIT_ID', fallback: _testInterstitialId)
      : _testInterstitialId;

  /// Ads are disabled entirely when the config explicitly turns them off,
  /// which keeps widget tests and CI runs free of the ads SDK.
  static bool get adsEnabled => _read('ADS_ENABLED', fallback: 'true') != 'false';

  // --------------------------------------------------------------- billing
  static const String premiumProductId = 'premium_monthly';
  static const Set<String> billingProductIds = {premiumProductId};

  // --------------------------------------------------------------- gameplay
  static const String timeZone = 'Europe/Istanbul';
  static const int questionsPerSession = 10;
  static const int questionsForStreakDay = 5;

  static String _read(String key, {String fallback = ''}) {
    final define = _defines[key];
    if (define != null && define.isNotEmpty) return define;
    try {
      final value = dotenv.env[key]?.trim();
      return (value == null || value.isEmpty) ? fallback : value;
    } catch (_) {
      // dotenv was never loaded (unit tests, early startup failures).
      return fallback;
    }
  }
}
