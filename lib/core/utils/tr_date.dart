import 'package:timezone/timezone.dart' as tz;

import '../config/app_config.dart';

/// All gameplay day boundaries (streak, daily quests, weekly leaderboard) are
/// evaluated in Europe/Istanbul regardless of the device timezone. Keeping this
/// in one place is the only reliable way to avoid off-by-one-day bugs.
class TrDate {
  const TrDate._();

  static tz.Location? _location;

  static tz.Location get location {
    return _location ??= tz.getLocation(AppConfig.timeZone);
  }

  /// Overridable clock so tests can pin "now" deterministically.
  static DateTime Function() clock = DateTime.now;

  static tz.TZDateTime now() => tz.TZDateTime.from(clock(), location);

  /// `yyyy-MM-dd` key for the current Istanbul day.
  static String todayKey() => dayKey(now());

  static String dayKey(DateTime date) {
    final local = date is tz.TZDateTime
        ? date
        : tz.TZDateTime.from(date, location);
    return _format(local);
  }

  static String yesterdayKey() =>
      dayKey(now().subtract(const Duration(days: 1)));

  /// Monday 00:00 of the week the given day belongs to, as a `yyyy-MM-dd` key.
  static String weekStartKey([DateTime? date]) {
    final local = date == null
        ? now()
        : tz.TZDateTime.from(date, location);
    final monday = local.subtract(Duration(days: local.weekday - 1));
    return _format(monday);
  }

  /// Difference in whole Istanbul days between two `yyyy-MM-dd` keys.
  /// Returns `null` when either key cannot be parsed.
  static int? daysBetweenKeys(String from, String to) {
    final a = parseKey(from);
    final b = parseKey(to);
    if (a == null || b == null) return null;
    return b.difference(a).inDays;
  }

  static DateTime? parseKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime.utc(year, month, day);
  }

  /// Stable non-negative hash for a day key, used to pick the daily question
  /// and the daily fact deterministically.
  static int dayHash(String key) {
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  static String _format(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
