// lib/core/utils/date_utils.dart
import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static final _dateFormat = DateFormat('yyyy-MM-dd');
  static final _displayDate = DateFormat('dd MMM yyyy');
  static final _displayDateTime = DateFormat('dd MMM yyyy, HH:mm');
  static final _timeOnly = DateFormat('HH:mm');
  static final _displayMonth = DateFormat('MMM yyyy');

  static String toApiDate(DateTime date) => _dateFormat.format(date);

  static String toDisplayDate(DateTime date) => _displayDate.format(date);

  static String toDisplayDateTime(String? isoString) {
    if (isoString == null) return '—';
    try {
      return _displayDateTime.format(DateTime.parse(isoString).toLocal());
    } catch (_) {
      return isoString;
    }
  }

  static String toTimeOnly(String? isoString) {
    if (isoString == null) return '—';
    try {
      return _timeOnly.format(DateTime.parse(isoString).toLocal());
    } catch (_) {
      return isoString;
    }
  }

  static String toDisplayMonth(DateTime date) => _displayMonth.format(date);

  static String timeAgo(String? isoString) {
    if (isoString == null) return 'unknown';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '—';
    }
  }

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59);
}
