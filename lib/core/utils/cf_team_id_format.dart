/// Public CrickFlow team code — TM prefix + 5 digits (e.g. TM00042).
class CfTeamIdFormat {
  CfTeamIdFormat._();

  static const String prefix = 'TM';

  static String format(int sequence) =>
      '$prefix${sequence.toString().padLeft(5, '0')}';

  static String normalize(String query) =>
      query.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  static bool looksLikeTeamCode(String query) {
    final t = normalize(query);
    return RegExp(r'^TM\d{4,6}$').hasMatch(t);
  }

  /// Partial match for list search — same idea as public player ID search.
  static bool matchesPartialQuery(String? teamCode, String query) {
    if (teamCode == null || teamCode.isEmpty) return false;
    final q = normalize(query);
    if (q.isEmpty) return false;
    final code = normalize(teamCode);
    if (code.contains(q)) return true;
    final qDigits = q.replaceAll(RegExp(r'[^0-9]'), '');
    if (qDigits.isNotEmpty) {
      final codeDigits = code.replaceAll(RegExp(r'[^0-9]'), '');
      if (codeDigits.contains(qDigits)) return true;
    }
    return false;
  }

  static String displayLabel(String? teamCode) {
    if (teamCode == null || teamCode.isEmpty) return '—';
    return normalize(teamCode);
  }

  static String hint() => 'Team ID starts with $prefix (e.g. ${format(1)})';
}
