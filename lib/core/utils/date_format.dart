import 'package:intl/intl.dart';

/// Date and duration formatting used across the app.
///
/// Everything the API sends is UTC ISO-8601; everything shown to a tenant is in
/// device-local time. The conversion happens once, here.
class AppDate {
  const AppDate._();

  static final DateFormat _day = DateFormat('d MMMM yyyy');
  static final DateFormat _shortDay = DateFormat('d MMM yyyy');
  static final DateFormat _dayTime = DateFormat('d MMM yyyy, HH:mm');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _time = DateFormat('HH:mm');

  /// `5 September 2026` — matches how the spec writes dates.
  static String full(DateTime date) => _day.format(date.toLocal());

  /// `5 Sep 2026`
  static String short(DateTime date) => _shortDay.format(date.toLocal());

  /// `5 Sep 2026, 14:30`
  static String dateTime(DateTime date) => _dayTime.format(date.toLocal());

  /// `September 2026` — for billing periods (section 35).
  static String monthYear(DateTime date) => _monthYear.format(date.toLocal());

  static String time(DateTime date) => _time.format(date.toLocal());

  /// `1 Sep 2026 – 30 Sep 2026`, the billing period every invoice carries.
  static String period(DateTime start, DateTime end) =>
      '${short(start)} – ${short(end)}';

  /// `in 3 days` / `2 days ago` / `today`.
  static String relativeDays(DateTime date) {
    final now = DateTime.now();
    final target = date.toLocal();
    final days = DateTime(
      target.year,
      target.month,
      target.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;

    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    if (days == -1) return 'yesterday';
    if (days > 0) return 'in $days days';
    return '${-days} days ago';
  }

  /// `47:59:12` — the booking expiry countdown from section 23.
  static String countdown(Duration remaining) {
    if (remaining.isNegative) return '00:00:00';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);
    return '${_pad(hours)}:${_pad(minutes)}:${_pad(seconds)}';
  }

  /// `2 days, 4 hours` — a gentler rendering of the same duration.
  static String humanDuration(Duration remaining) {
    if (remaining.isNegative || remaining == Duration.zero) return 'expired';
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    if (days > 0) return '$days ${_plural(days, 'day')}, $hours ${_plural(hours, 'hour')}';
    if (hours > 0) {
      return '$hours ${_plural(hours, 'hour')}, $minutes ${_plural(minutes, 'minute')}';
    }
    return '$minutes ${_plural(minutes, 'minute')}';
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');

  static String _plural(int count, String noun) => count == 1 ? noun : '${noun}s';

  /// Parses an API timestamp, tolerating a null or malformed value.
  static DateTime? tryParse(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
