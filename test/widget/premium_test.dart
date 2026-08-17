import 'package:flutter_test/flutter_test.dart';
import 'package:yks_level/features/premium/premium_screen.dart';
import 'package:yks_level/services/billing_service.dart';
import 'package:yks_level/services/local_store.dart';
import 'package:yks_level/state/providers.dart';

import '../helpers.dart';

void main() {
  late LocalStore store;

  setUp(() async {
    setUpTestClock();
    store = await createTestStore();
  });
  tearDown(resetTestClock);

  testWidgets('lists every benefit in Turkish', (tester) async {
    await pumpApp(tester, const PremiumScreen(), store: store);
    await tester.pump();

    expect(find.text('YKS Level Premium'), findsWidgets);
    expect(find.text('Reklamsız deneyim'), findsOneWidget);
    expect(find.text('Gelişmiş istatistikler'), findsOneWidget);
    expect(find.text('Özel profil rozeti'), findsOneWidget);
    expect(find.text('Ek çalışma modları'), findsOneWidget);
    expect(find.text('Satın Alımları Geri Yükle'), findsOneWidget);
    expect(find.text('Gizlilik Politikası'), findsOneWidget);
    expect(find.text('Kullanım Koşulları'), findsOneWidget);
  });

  testWidgets('shows the localized store price, never a hardcoded one',
      (tester) async {
    await pumpApp(
      tester,
      const PremiumScreen(),
      store: store,
      overrides: [
        premiumStatusProvider.overrideWith(
          (ref) => Stream.value(
            const PremiumStatus(
              state: PremiumState.free,
              storeAvailable: true,
              priceLabel: '₺49,99',
            ),
          ),
        ),
      ],
    );
    await tester.pump();

    expect(find.text('₺49,99 / ay'), findsOneWidget);
  });

  testWidgets('disables the CTA when the store is unavailable', (tester) async {
    await pumpApp(
      tester,
      const PremiumScreen(),
      store: store,
      overrides: [
        premiumStatusProvider.overrideWith(
          (ref) => Stream.value(const PremiumStatus(state: PremiumState.free)),
        ),
      ],
    );
    await tester.pump();

    expect(find.text('Şu an kullanılamıyor'), findsOneWidget);
  });

  testWidgets('celebrates an active subscription instead of selling again',
      (tester) async {
    await pumpApp(
      tester,
      const PremiumScreen(),
      store: store,
      overrides: [
        premiumStatusProvider.overrideWith(
          (ref) => Stream.value(
            const PremiumStatus(
              state: PremiumState.premium,
              storeAvailable: true,
              priceLabel: '₺49,99',
            ),
          ),
        ),
      ],
    );
    await tester.pump();

    expect(find.text('Premium aktif 🎉'), findsOneWidget);
    expect(find.text('₺49,99 / ay'), findsNothing);
  });

  testWidgets('surfaces a grace-period warning', (tester) async {
    await pumpApp(
      tester,
      const PremiumScreen(),
      store: store,
      overrides: [
        premiumStatusProvider.overrideWith(
          (ref) => Stream.value(
            const PremiumStatus(
              state: PremiumState.gracePeriod,
              storeAvailable: true,
            ),
          ),
        ),
      ],
    );
    await tester.pump();

    expect(
      find.text('Ödemende bir sorun var. Google Play üzerinden kontrol et.'),
      findsOneWidget,
    );
  });
}
