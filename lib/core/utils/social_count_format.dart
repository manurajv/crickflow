import 'package:intl/intl.dart';

/// Compact labels for followers, views, etc.
class SocialCountFormat {
  SocialCountFormat._();

  static final _compact = NumberFormat.compact();

  static String label(int count, String noun) {
    final value = _compact.format(count);
    return '$value $noun${count == 1 ? '' : 's'}';
  }

  static String short(int count) => _compact.format(count);
}
