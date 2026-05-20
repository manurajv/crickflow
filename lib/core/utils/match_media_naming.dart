/// Sequential match media codes: CM1, CM2, CM3, …
class MatchMediaNaming {
  MatchMediaNaming._();

  static const String prefix = 'CM';

  /// Display/storage code for the 1-based index (1 → CM1).
  static String codeForIndex(int index) => '$prefix$index';

  /// Next index after existing codes (CM1, CM3 → 4).
  static int nextIndex(Iterable<String> codes) {
    var max = 0;
    for (final raw in codes) {
      if (!raw.startsWith(prefix)) continue;
      final n = int.tryParse(raw.substring(prefix.length));
      if (n != null && n > max) max = n;
    }
    return max + 1;
  }

  static String? parseIndex(String code) {
    if (!code.startsWith(prefix)) return null;
    return code.substring(prefix.length);
  }
}
