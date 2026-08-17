import 'package:flutter_test/flutter_test.dart';
import 'package:yks_level/services/ad_service.dart';
import 'package:yks_level/services/local_store.dart';

import '../helpers.dart';

/// The interstitial frequency cap is the one piece of ad policy that must not
/// regress: showing one after every session is the fastest way to lose D1.
void main() {
  late LocalStore store;

  setUp(() async {
    store = await createTestStore();
  });

  test('counter starts at zero', () {
    expect(store.completedSessionsSinceInterstitial, 0);
  });

  test('the cap is one interstitial every three sessions', () {
    expect(AdMobService.interstitialSessionInterval, 3);
  });

  test('the no-op service never shows anything', () async {
    const service = NoopAdService();
    expect(await service.maybeShowInterstitial(), isFalse);
    expect(await service.showRewarded(), isFalse);
    expect(service.isRewardedReady, isFalse);
  });

  test('session counter persists across reads', () async {
    await store.setCompletedSessionsSinceInterstitial(2);
    expect(store.completedSessionsSinceInterstitial, 2);
    await store.setCompletedSessionsSinceInterstitial(0);
    expect(store.completedSessionsSinceInterstitial, 0);
  });
}
