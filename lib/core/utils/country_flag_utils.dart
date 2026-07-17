/// Utility to convert country names to Unicode flag emojis.
///
/// Uses regional indicator symbols (U+1F1E6–U+1F1FF) derived from
/// ISO 3166-1 alpha-2 country codes.
class CountryFlagUtils {
  CountryFlagUtils._();

  /// Returns a flag emoji for the given [countryName], or empty string
  /// if the country is not recognized.
  static String flagForCountry(String countryName) {
    if (countryName.isEmpty) return '';
    final code = _countryToCode[countryName.trim().toLowerCase()];
    if (code == null || code.length != 2) return '';
    return _codeToEmoji(code);
  }

  /// Converts a 2-letter ISO country code to regional indicator emoji.
  static String _codeToEmoji(String code) {
    final upper = code.toUpperCase();
    final first = upper.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final second = upper.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCodes([first, second]);
  }

  /// Maps lowercase country names to ISO 3166-1 alpha-2 codes.
  /// Covers all ICC member nations and common cricket-playing countries.
  static const _countryToCode = <String, String>{
    // Full members
    'india': 'IN',
    'australia': 'AU',
    'england': 'GB',
    'south africa': 'ZA',
    'pakistan': 'PK',
    'new zealand': 'NZ',
    'sri lanka': 'LK',
    'west indies': 'WI', // No standard flag; handled below
    'bangladesh': 'BD',
    'zimbabwe': 'ZW',
    'afghanistan': 'AF',
    'ireland': 'IE',

    // Associate members & common cricket nations
    'united states': 'US',
    'usa': 'US',
    'united states of america': 'US',
    'canada': 'CA',
    'scotland': 'GB',
    'netherlands': 'NL',
    'the netherlands': 'NL',
    'nepal': 'NP',
    'oman': 'OM',
    'uae': 'AE',
    'united arab emirates': 'AE',
    'namibia': 'NA',
    'kenya': 'KE',
    'bermuda': 'BM',
    'hong kong': 'HK',
    'papua new guinea': 'PG',
    'singapore': 'SG',
    'malaysia': 'MY',
    'thailand': 'TH',
    'japan': 'JP',
    'china': 'CN',
    'germany': 'DE',
    'france': 'FR',
    'italy': 'IT',
    'spain': 'ES',
    'portugal': 'PT',
    'uganda': 'UG',
    'tanzania': 'TZ',
    'nigeria': 'NG',
    'ghana': 'GH',
    'rwanda': 'RW',
    'mozambique': 'MZ',
    'botswana': 'BW',
    'zambia': 'ZM',
    'malawi': 'MW',
    'qatar': 'QA',
    'bahrain': 'BH',
    'kuwait': 'KW',
    'saudi arabia': 'SA',
    'maldives': 'MV',
    'bhutan': 'BT',
    'myanmar': 'MM',
    'fiji': 'FJ',
    'vanuatu': 'VU',
    'samoa': 'WS',
    'argentina': 'AR',
    'brazil': 'BR',
    'chile': 'CL',
    'mexico': 'MX',

    // Aliases / common variants
    'uk': 'GB',
    'united kingdom': 'GB',
    'great britain': 'GB',
    'nz': 'NZ',
    'sa': 'ZA',
    'aus': 'AU',
    'eng': 'GB',
    'ind': 'IN',
    'pak': 'PK',
    'ban': 'BD',
    'slk': 'LK',
    'zim': 'ZW',
    'afg': 'AF',
    'ire': 'IE',
    'ned': 'NL',
    'nam': 'NA',
    'png': 'PG',
    'uga': 'UG',
  };

  /// Returns the flag emoji for a country code directly.
  /// For "WI" (West Indies), returns a cricket-stump emoji as placeholder.
  static String flagForCode(String code) {
    if (code.isEmpty) return '';
    if (code.toUpperCase() == 'WI') return '🏏';
    if (code.length != 2) return '';
    return _codeToEmoji(code);
  }
}
