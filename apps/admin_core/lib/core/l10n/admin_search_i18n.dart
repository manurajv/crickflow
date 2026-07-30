/// Multilingual search architecture (future-ready).
///
/// Current admin search remains case-insensitive substring match.
/// This facade documents extension points for language-aware search,
/// transliteration, and synonyms without changing business queries yet.
abstract final class AdminSearchI18n {
  /// Normalize query for locale-insensitive matching.
  static String normalize(String query, {String? languageCode}) {
    var q = query.trim().toLowerCase();
    // Collapse whitespace; preserve unicode letters for si/ta/hi.
    q = q.replaceAll(RegExp(r'\s+'), ' ');
    return q;
  }

  /// Whether [haystack] matches [query] under current rules.
  static bool matches(String haystack, String query, {String? languageCode}) {
    if (query.trim().isEmpty) return true;
    return normalize(haystack, languageCode: languageCode)
        .contains(normalize(query, languageCode: languageCode));
  }

  /// Reserved: map synonyms per language (empty until content packs ship).
  static List<String> expandSynonyms(String query, String languageCode) {
    return const [];
  }

  /// Reserved: transliteration hooks (e.g. Singlish → Sinhala).
  static String? transliterate(String query, String targetLanguage) => null;
}
