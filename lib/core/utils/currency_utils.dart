/// ISO 4217 currency code for a country name or ISO alpha-2 code.
///
/// Unknown countries return an empty string so UI can omit a currency label
/// instead of hardcoding INR/LKR.
String currencyCodeForCountry(String? countryOrCode) {
  final raw = countryOrCode?.trim() ?? '';
  if (raw.isEmpty) return '';

  final upper = raw.toUpperCase();
  if (upper.length == 2 && _codeToCurrency.containsKey(upper)) {
    return _codeToCurrency[upper]!;
  }

  return _nameToCurrency[raw.toLowerCase()] ?? '';
}

/// Section label like `Per day (in LKR):` or `Per day:` when unknown.
String budgetRangeSectionLabel({
  required String base,
  required String? countryOrCode,
}) {
  final code = currencyCodeForCountry(countryOrCode);
  if (code.isEmpty) return '$base:';
  return '$base (in $code):';
}

/// Display prefix for amounts (e.g. `₹`, `Rs.`, `LKR `).
String currencyDisplayPrefix(String? currencyCode) {
  final code = currencyCode?.trim().toUpperCase() ?? '';
  if (code.isEmpty) return '';
  return switch (code) {
    'INR' => '₹',
    'LKR' || 'PKR' || 'NPR' => 'Rs.',
    'USD' || 'CAD' || 'SGD' || 'HKD' || 'AUD' || 'NZD' => '\$',
    'GBP' => '£',
    'EUR' => '€',
    'BDT' => '৳',
    'JPY' || 'CNY' => '¥',
    'AED' => 'AED ',
    'SAR' => 'SAR ',
    'ZAR' => 'R',
    _ => '$code ',
  };
}

/// Formats a fee using country or an explicit ISO currency code.
String formatCurrencyAmount(
  double? amount, {
  String? countryOrCode,
  String? currencyCode,
  String empty = '—',
}) {
  if (amount == null) return empty;
  final code = (currencyCode != null && currencyCode.trim().isNotEmpty)
      ? currencyCode.trim().toUpperCase()
      : currencyCodeForCountry(countryOrCode);
  final value = amount == amount.roundToDouble()
      ? '${amount.toInt()}'
      : amount.toStringAsFixed(0);
  final prefix = currencyDisplayPrefix(code);
  if (prefix.isEmpty) return value;
  return '$prefix$value';
}

/// Cricket + common host nations.
const _codeToCurrency = <String, String>{
  'IN': 'INR',
  'LK': 'LKR',
  'AU': 'AUD',
  'GB': 'GBP',
  'PK': 'PKR',
  'BD': 'BDT',
  'NZ': 'NZD',
  'ZA': 'ZAR',
  'AF': 'AFN',
  'ZW': 'ZWL',
  'IE': 'EUR',
  'NP': 'NPR',
  'AE': 'AED',
  'US': 'USD',
  'CA': 'CAD',
  'SG': 'SGD',
  'MY': 'MYR',
  'QA': 'QAR',
  'OM': 'OMR',
  'KW': 'KWD',
  'BH': 'BHD',
  'SA': 'SAR',
  'NL': 'EUR',
  'DE': 'EUR',
  'FR': 'EUR',
  'IT': 'EUR',
  'ES': 'EUR',
  'PT': 'EUR',
  'HK': 'HKD',
  'JP': 'JPY',
  'CN': 'CNY',
  'TH': 'THB',
  'ID': 'IDR',
  'PH': 'PHP',
  'KE': 'KES',
  'UG': 'UGX',
  'TZ': 'TZS',
  'NG': 'NGN',
  'GH': 'GHS',
  'FJ': 'FJD',
  'PG': 'PGK',
  'TT': 'TTD',
  'JM': 'JMD',
  'BB': 'BBD',
  'GY': 'GYD',
};

const _nameToCurrency = <String, String>{
  'india': 'INR',
  'sri lanka': 'LKR',
  'australia': 'AUD',
  'england': 'GBP',
  'united kingdom': 'GBP',
  'scotland': 'GBP',
  'wales': 'GBP',
  'pakistan': 'PKR',
  'bangladesh': 'BDT',
  'new zealand': 'NZD',
  'south africa': 'ZAR',
  'west indies': 'USD',
  'afghanistan': 'AFN',
  'zimbabwe': 'ZWL',
  'ireland': 'EUR',
  'nepal': 'NPR',
  'united arab emirates': 'AED',
  'uae': 'AED',
  'united states': 'USD',
  'usa': 'USD',
  'canada': 'CAD',
  'singapore': 'SGD',
  'malaysia': 'MYR',
  'qatar': 'QAR',
  'oman': 'OMR',
  'kuwait': 'KWD',
  'bahrain': 'BHD',
  'saudi arabia': 'SAR',
  'hong kong': 'HKD',
  'japan': 'JPY',
  'china': 'CNY',
  'thailand': 'THB',
  'indonesia': 'IDR',
  'philippines': 'PHP',
  'kenya': 'KES',
  'uganda': 'UGX',
  'tanzania': 'TZS',
  'nigeria': 'NGN',
  'ghana': 'GHS',
  'fiji': 'FJD',
  'papua new guinea': 'PGK',
  'trinidad and tobago': 'TTD',
  'jamaica': 'JMD',
  'barbados': 'BBD',
  'guyana': 'GYD',
};
