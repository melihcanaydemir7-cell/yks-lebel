import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_settings.dart';
import 'providers.dart';

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(localStoreProvider).readSettings();

  Future<void> _save(AppSettings next) async {
    state = next;
    await ref.read(localStoreProvider).writeSettings(next);
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _save(state.copyWith(themeMode: mode));

  Future<void> setNotificationsEnabled(bool enabled) =>
      _save(state.copyWith(notificationsEnabled: enabled));

  Future<void> setReminderTime(TimeOfDay time) => _save(
    state.copyWith(reminderHour: time.hour, reminderMinute: time.minute),
  );

  Future<void> setSoundEnabled(bool enabled) =>
      _save(state.copyWith(soundEnabled: enabled));

  Future<void> setHapticsEnabled(bool enabled) =>
      _save(state.copyWith(hapticsEnabled: enabled));
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
