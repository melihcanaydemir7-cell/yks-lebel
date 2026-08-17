import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../data/content_repository.dart';
import '../data/leaderboard_repository.dart';
import '../data/sync_service.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../services/feedback_service.dart';
import '../services/local_store.dart';
import '../services/notification_service.dart';
import 'settings_controller.dart';

/// Overridden in `main()` once the async bootstrap has finished.
final localStoreProvider = Provider<LocalStore>(
  (ref) => throw UnimplementedError('localStoreProvider must be overridden'),
);

final analyticsProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(),
);

final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(supabaseClientProvider)),
);

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ContentRepository(client == null ? null : SupabaseContentSource(client));
});

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>(
  (ref) => LeaderboardRepository(ref.watch(supabaseClientProvider)),
);

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(ref.watch(supabaseClientProvider)),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final billingServiceProvider = Provider<BillingService>((ref) {
  final service = BillingService(ref.watch(localStoreProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Emits the live entitlement. Ads and paywall UI both read from here.
final premiumStatusProvider = StreamProvider<PremiumStatus>((ref) {
  final billing = ref.watch(billingServiceProvider);
  return billing.statusStream;
});

final isPremiumProvider = Provider<bool>((ref) {
  final billing = ref.watch(billingServiceProvider);
  return ref
      .watch(premiumStatusProvider)
      .maybeWhen(data: (status) => status.isPremium, orElse: () => billing.status.isPremium);
});

/// Premium users and non-mobile targets get a no-op implementation, so the
/// rest of the app never has to branch on entitlement.
final adServiceProvider = Provider<AdService>((ref) {
  final isPremium = ref.watch(isPremiumProvider);
  if (isPremium || !AppConfig.adsEnabled || !adsSupportedOnThisPlatform) {
    return const NoopAdService();
  }
  final service = AdMobService(
    ref.watch(localStoreProvider),
    ref.watch(analyticsProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  final settings = ref.watch(settingsControllerProvider);
  return FeedbackService(
    hapticsEnabled: settings.hapticsEnabled,
    soundEnabled: settings.soundEnabled,
  );
});

/// False when Supabase is not configured, so the UI can hide account CTAs
/// that could not possibly succeed.
final authAvailableProvider = Provider<bool>(
  (ref) => ref.watch(authServiceProvider).isConfigured,
);

final authStateProvider = StreamProvider<AppUser>((ref) {
  final auth = ref.watch(authServiceProvider);
  return auth.authStateChanges();
});

final currentUserProvider = Provider<AppUser>((ref) {
  final auth = ref.watch(authServiceProvider);
  return ref
      .watch(authStateProvider)
      .maybeWhen(data: (user) => user, orElse: () => auth.currentUser);
});
