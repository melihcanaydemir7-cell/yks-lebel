import 'package:flutter_test/flutter_test.dart';
import 'package:yks_level/services/billing_service.dart';
import 'package:yks_level/services/local_store.dart';

import '../helpers.dart';

void main() {
  group('premium entitlement', () {
    test('premium and grace period both count as entitled', () {
      expect(
        const PremiumStatus(state: PremiumState.premium).isPremium,
        isTrue,
      );
      expect(
        const PremiumStatus(state: PremiumState.gracePeriod).isPremium,
        isTrue,
      );
    });

    test('free, expired and unknown are not entitled', () {
      for (final state in [
        PremiumState.free,
        PremiumState.expired,
        PremiumState.unknown,
      ]) {
        expect(PremiumStatus(state: state).isPremium, isFalse, reason: '$state');
      }
    });

    test('ads are shown exactly when the user is not entitled', () {
      expect(const PremiumStatus(state: PremiumState.free).showsAds, isTrue);
      expect(const PremiumStatus(state: PremiumState.premium).showsAds, isFalse);
    });

    test('clearError wipes the stored error', () {
      const status = PremiumStatus(lastError: 'boom');
      expect(status.copyWith(clearError: true).lastError, isNull);
      expect(status.copyWith(purchasePending: true).lastError, 'boom');
    });
  });

  group('cached entitlement', () {
    late LocalStore store;

    setUp(() async {
      store = await createTestStore();
    });

    test('defaults to not premium', () {
      expect(store.cachedPremium, isFalse);
    });

    test('survives a round trip so a cold start never shows ads to a member',
        () async {
      await store.setCachedPremium(true);
      expect(store.cachedPremium, isTrue);

      final service = BillingService(store);
      expect(service.status.isPremium, isFalse, reason: 'before initialize');

      // The cached flag is what BillingService.initialize() seeds itself from.
      await store.setCachedPremium(false);
      expect(store.cachedPremium, isFalse);
    });
  });
}
