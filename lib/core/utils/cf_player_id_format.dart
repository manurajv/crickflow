import '../constants/app_constants.dart';

/// Public CrickFlow player ID — prefix from app name + sequential number (e.g. CF000042).
class CfPlayerIdFormat {
  CfPlayerIdFormat._();

  static const String prefix = 'CF';

  static String format(int sequence) =>
      '$prefix${sequence.toString().padLeft(6, '0')}';

  static bool looksLikeCfPlayerId(String query) {
    final t = query.trim().toUpperCase();
    return RegExp(r'^CF\d{4,8}$').hasMatch(t);
  }

  static String normalize(String query) => query.trim().toUpperCase();

  static String displayLabel(String? cfPlayerId) =>
      cfPlayerId != null && cfPlayerId.isNotEmpty ? cfPlayerId : '—';

  static String hint() =>
      '${AppConstants.appName} player ID starts with $prefix (e.g. ${format(1)})';
}
