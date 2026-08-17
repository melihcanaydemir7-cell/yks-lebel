import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/config/app_config.dart';
import 'analytics_service.dart';
import 'local_store.dart';

/// Abstraction so the UI (and tests) never touch the ads SDK directly.
abstract class AdService {
  Future<void> initialize();

  /// Preloads the rewarded ad so the result screen can offer it instantly.
  Future<void> preloadRewarded();

  bool get isRewardedReady;

  /// Shows the rewarded ad. Resolves `true` only when the SDK fires the
  /// user-earned-reward callback — never on dismissal or failure.
  Future<bool> showRewarded();

  /// Shows an interstitial if the frequency cap allows it. Returns whether one
  /// was actually shown.
  Future<bool> maybeShowInterstitial();

  void dispose();
}

/// Used for premium users, when ads are disabled by config, and in tests.
class NoopAdService implements AdService {
  const NoopAdService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> preloadRewarded() async {}

  @override
  bool get isRewardedReady => false;

  @override
  Future<bool> showRewarded() async => false;

  @override
  Future<bool> maybeShowInterstitial() async => false;

  @override
  void dispose() {}
}

class AdMobService implements AdService {
  AdMobService(this._store, this._analytics);

  /// At most one interstitial every N completed quiz sessions.
  static const int interstitialSessionInterval = 3;

  final LocalStore _store;
  final AnalyticsService _analytics;

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  bool _initialized = false;
  bool _loadingRewarded = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await MobileAds.instance.initialize();
      unawaited(preloadRewarded());
      unawaited(_preloadInterstitial());
    } catch (error) {
      debugPrint('AdMob init failed: $error');
    }
  }

  @override
  bool get isRewardedReady => _rewardedAd != null;

  @override
  Future<void> preloadRewarded() async {
    if (_rewardedAd != null || _loadingRewarded) return;
    _loadingRewarded = true;
    try {
      await RewardedAd.load(
        adUnitId: AppConfig.rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _loadingRewarded = false;
          },
          onAdFailedToLoad: (error) {
            _rewardedAd = null;
            _loadingRewarded = false;
            debugPrint('Rewarded ad failed: ${error.message}');
          },
        ),
      );
    } catch (error) {
      _loadingRewarded = false;
      debugPrint('Rewarded ad load threw: $error');
    }
  }

  @override
  Future<bool> showRewarded() async {
    final ad = _rewardedAd;
    if (ad == null) {
      unawaited(preloadRewarded());
      return false;
    }
    _rewardedAd = null;

    final completer = Completer<bool>();
    var earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(preloadRewarded());
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        unawaited(preloadRewarded());
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    unawaited(_analytics.logEvent(AnalyticsEvents.rewardedAdStarted));

    try {
      await ad.show(
        onUserEarnedReward: (_, _) {
          earned = true;
        },
      );
    } catch (error) {
      debugPrint('Rewarded ad show failed: $error');
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future;
  }

  @override
  Future<bool> maybeShowInterstitial() async {
    final counter = _store.completedSessionsSinceInterstitial + 1;
    if (counter < interstitialSessionInterval) {
      await _store.setCompletedSessionsSinceInterstitial(counter);
      return false;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      // Keep the counter pinned at the cap so the next session tries again.
      await _store.setCompletedSessionsSinceInterstitial(
        interstitialSessionInterval - 1,
      );
      unawaited(_preloadInterstitial());
      return false;
    }

    _interstitialAd = null;
    await _store.setCompletedSessionsSinceInterstitial(0);

    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(_preloadInterstitial());
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        unawaited(_preloadInterstitial());
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      await ad.show();
      unawaited(_analytics.logEvent(AnalyticsEvents.interstitialShown));
    } catch (error) {
      debugPrint('Interstitial show failed: $error');
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future;
  }

  Future<void> _preloadInterstitial() async {
    if (_interstitialAd != null) return;
    try {
      await InterstitialAd.load(
        adUnitId: AppConfig.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => _interstitialAd = ad,
          onAdFailedToLoad: (error) {
            _interstitialAd = null;
            debugPrint('Interstitial failed: ${error.message}');
          },
        ),
      );
    } catch (error) {
      debugPrint('Interstitial load threw: $error');
    }
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd = null;
    _interstitialAd = null;
  }
}

/// Ads only make sense on mobile builds with a configured AdMob app id.
bool get adsSupportedOnThisPlatform {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}
