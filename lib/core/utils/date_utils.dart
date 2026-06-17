import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static String formatMatchDate(DateTime date) {
    return DateFormat('EEE, d MMM yyyy • h:mm a').format(date);
  }

  static String formatShort(DateTime date) {
    return DateFormat('d MMM yyyy').format(date);
  }

  /// Short day + date, no year. e.g. "Wed, 18 Jun"
  static String formatShortDay(DateTime date) {
    return DateFormat('EEE, d MMM').format(date);
  }

  /// Time only. e.g. "3:30 PM"
  static String formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
