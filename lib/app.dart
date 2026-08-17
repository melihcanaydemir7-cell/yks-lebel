import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/tr_date.dart';
import 'l10n/app_localizations.dart';
import 'routing/app_router.dart';
import 'services/analytics_service.dart';
import 'state/progress_controller.dart';
import 'state/providers.dart';
import 'state/settings_controller.dart';

class YksLevelApp extends ConsumerStatefulWidget {
  const YksLevelApp({super.key});

  @override
  ConsumerState<YksLevelApp> createState() => _YksLevelAppState();
}

class _YksLevelAppState extends ConsumerState<YksLevelApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapServices());
  }

  /// Services that are not needed to paint the first frame are started after
  /// it, so cold start stays fast.
  Future<void> _bootstrapServices() async {
    final analytics = ref.read(analyticsProvider);
    unawaited(analytics.logEvent(AnalyticsEvents.appOpen));

    unawaited(ref.read(billingServiceProvider).initialize());
    unawaited(ref.read(adServiceProvider).initialize());

    final settings = ref.read(settingsControllerProvider);
    // `context` here sits above MaterialApp and has no Localizations ancestor,
    // so the reminder strings come from the router's navigator context.
    final localizedContext = rootNavigatorKey.currentContext;
    if (settings.notificationsEnabled && mounted && localizedContext != null) {
      final l10n = L10n.of(localizedContext);
      final notifications = ref.read(notificationServiceProvider);
      await notifications.initialize(
        channelName: l10n.notificationChannelName,
      );
      await notifications.scheduleDailyReminder(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
        title: l10n.notificationTitle,
        body: TrDate.dayHash(TrDate.todayKey()).isEven
            ? l10n.notificationBody
            : l10n.notificationBodyAlt,
      );
    }

    final progress = ref.read(progressControllerProvider);
    unawaited(
      analytics.setUserProperties(
        isPremium: ref.read(isPremiumProvider),
        examTrack: progress.examTrack.storageValue,
        level: ref.read(levelProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(
      settingsControllerProvider.select((s) => s.themeMode),
    );

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      builder: (context, child) {
        // Respect the user's font size preference but keep the gamified layout
        // from breaking on extreme values.
        final scale = MediaQuery.textScalerOf(
          context,
        ).clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child!,
        );
      },
    );
  }
}
