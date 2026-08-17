import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/tr_date.dart';

/// Local (not push) daily study reminder. Push notifications are out of scope
/// for the MVP.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int reminderId = 1001;
  static const String _channelId = 'daily_reminder';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  bool get _supported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  Future<void> initialize({required String channelName}) async {
    if (_initialized || !_supported) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          channelName,
          importance: Importance.high,
        ),
      );
      _initialized = true;
    } catch (error) {
      debugPrint('Notification init failed: $error');
    }
  }

  /// Android 13+ requires an explicit runtime permission.
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } catch (error) {
      debugPrint('Notification permission failed: $error');
      return false;
    }
  }

  /// Schedules (or reschedules) the repeating daily reminder. Uses inexact
  /// alarms on purpose: exact alarms need an extra Play Console justification
  /// and a reminder does not need minute precision.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    if (!_supported) return;
    await cancelReminder();
    try {
      await _plugin.zonedSchedule(
        id: reminderId,
        title: title,
        body: body,
        scheduledDate: _nextInstanceOf(hour, minute),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            title,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (error) {
      debugPrint('Scheduling reminder failed: $error');
    }
  }

  Future<void> cancelReminder() async {
    if (!_supported) return;
    try {
      await _plugin.cancel(id: reminderId);
    } catch (error) {
      debugPrint('Cancelling reminder failed: $error');
    }
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = TrDate.now();
    var scheduled = tz.TZDateTime(
      TrDate.location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
