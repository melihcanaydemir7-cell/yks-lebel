import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.notificationsEnabled = true,
    this.reminderHour = 19,
    this.reminderMinute = 0,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
  });

  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool soundEnabled;
  final bool hapticsEnabled;

  TimeOfDay get reminderTime =>
      TimeOfDay(hour: reminderHour, minute: reminderMinute);

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? soundEnabled,
    bool? hapticsEnabled,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'theme_mode': themeMode.name,
    'notifications_enabled': notificationsEnabled,
    'reminder_hour': reminderHour,
    'reminder_minute': reminderMinute,
    'sound_enabled': soundEnabled,
    'haptics_enabled': hapticsEnabled,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    themeMode: ThemeMode.values.firstWhere(
      (m) => m.name == json['theme_mode'],
      orElse: () => ThemeMode.system,
    ),
    notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
    reminderHour: (json['reminder_hour'] as num?)?.toInt() ?? 19,
    reminderMinute: (json['reminder_minute'] as num?)?.toInt() ?? 0,
    soundEnabled: json['sound_enabled'] as bool? ?? true,
    hapticsEnabled: json['haptics_enabled'] as bool? ?? true,
  );
}
