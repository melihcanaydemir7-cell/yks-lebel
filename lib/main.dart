import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'app.dart';
import 'core/config/app_config.dart';
import 'services/analytics_service.dart';
import 'services/local_store.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Every optional integration is allowed to fail: the app must still start and
  // be fully playable with bundled content and local progress.
  await _loadEnv();
  tz_data.initializeTimeZones();

  final firebaseReady = await _initFirebase();
  final supabaseClient = await _initSupabase();
  final store = await LocalStore.create();

  runApp(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        supabaseClientProvider.overrideWithValue(supabaseClient),
        if (firebaseReady)
          analyticsProvider.overrideWithValue(
            AnalyticsService(FirebaseAnalytics.instance),
          ),
      ],
      child: const YksLevelApp(),
    ),
  );
}

Future<void> _loadEnv() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // No .env bundled — AppConfig falls back to safe development defaults.
  }
}

Future<bool> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
    return true;
  } catch (error) {
    debugPrint('Firebase not configured, analytics disabled: $error');
    return false;
  }
}

Future<SupabaseClient?> _initSupabase() async {
  if (!AppConfig.hasSupabase) return null;
  try {
    final instance = await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
      debug: AppConfig.verboseLogging,
    );
    return instance.client;
  } catch (error) {
    debugPrint('Supabase init failed, running offline: $error');
    return null;
  }
}
