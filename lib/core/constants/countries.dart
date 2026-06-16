/// ISO countries with dial codes for onboarding country picker.
library;

class CountryData {
  const CountryData({
    required this.name,
    required this.code,
    required this.flag,
    required this.dialCode,
  });

  final String name;
  final String code;
  final String flag;
  final String dialCode;
}

/// Pinned cricket nations (shown first, in this order).
const pinnedCricketNationNames = [
  'India',
  'Sri Lanka',
  'Australia',
  'England',
  'Pakistan',
  'Bangladesh',
  'New Zealand',
  'South Africa',
  'West Indies',
  'Afghanistan',
  'Zimbabwe',
  'Ireland',
  'Scotland',
  'Nepal',
  'United Arab Emirates',
];

const _allCountriesRaw = <Map<String, String>>[
  {'name': 'Afghanistan', 'code': 'AF', 'flag': '🇦🇫', 'dial': '+93'},
  {'name': 'Albania', 'code': 'AL', 'flag': '🇦🇱', 'dial': '+355'},
  {'name': 'Algeria', 'code': 'DZ', 'flag': '🇩🇿', 'dial': '+213'},
  {'name': 'Andorra', 'code': 'AD', 'flag': '🇦🇩', 'dial': '+376'},
  {'name': 'Angola', 'code': 'AO', 'flag': '🇦🇴', 'dial': '+244'},
  {'name': 'Argentina', 'code': 'AR', 'flag': '🇦🇷', 'dial': '+54'},
  {'name': 'Armenia', 'code': 'AM', 'flag': '🇦🇲', 'dial': '+374'},
  {'name': 'Australia', 'code': 'AU', 'flag': '🇦🇺', 'dial': '+61'},
  {'name': 'Austria', 'code': 'AT', 'flag': '🇦🇹', 'dial': '+43'},
  {'name': 'Azerbaijan', 'code': 'AZ', 'flag': '🇦🇿', 'dial': '+994'},
  {'name': 'Bahrain', 'code': 'BH', 'flag': '🇧🇭', 'dial': '+973'},
  {'name': 'Bangladesh', 'code': 'BD', 'flag': '🇧🇩', 'dial': '+880'},
  {'name': 'Belarus', 'code': 'BY', 'flag': '🇧🇾', 'dial': '+375'},
  {'name': 'Belgium', 'code': 'BE', 'flag': '🇧🇪', 'dial': '+32'},
  {'name': 'Bhutan', 'code': 'BT', 'flag': '🇧🇹', 'dial': '+975'},
  {'name': 'Bolivia', 'code': 'BO', 'flag': '🇧🇴', 'dial': '+591'},
  {'name': 'Bosnia and Herzegovina', 'code': 'BA', 'flag': '🇧🇦', 'dial': '+387'},
  {'name': 'Botswana', 'code': 'BW', 'flag': '🇧🇼', 'dial': '+267'},
  {'name': 'Brazil', 'code': 'BR', 'flag': '🇧🇷', 'dial': '+55'},
  {'name': 'Brunei', 'code': 'BN', 'flag': '🇧🇳', 'dial': '+673'},
  {'name': 'Bulgaria', 'code': 'BG', 'flag': '🇧🇬', 'dial': '+359'},
  {'name': 'Cambodia', 'code': 'KH', 'flag': '🇰🇭', 'dial': '+855'},
  {'name': 'Cameroon', 'code': 'CM', 'flag': '🇨🇲', 'dial': '+237'},
  {'name': 'Canada', 'code': 'CA', 'flag': '🇨🇦', 'dial': '+1'},
  {'name': 'Chile', 'code': 'CL', 'flag': '🇨🇱', 'dial': '+56'},
  {'name': 'China', 'code': 'CN', 'flag': '🇨🇳', 'dial': '+86'},
  {'name': 'Colombia', 'code': 'CO', 'flag': '🇨🇴', 'dial': '+57'},
  {'name': 'Costa Rica', 'code': 'CR', 'flag': '🇨🇷', 'dial': '+506'},
  {'name': 'Croatia', 'code': 'HR', 'flag': '🇭🇷', 'dial': '+385'},
  {'name': 'Cuba', 'code': 'CU', 'flag': '🇨🇺', 'dial': '+53'},
  {'name': 'Cyprus', 'code': 'CY', 'flag': '🇨🇾', 'dial': '+357'},
  {'name': 'Czech Republic', 'code': 'CZ', 'flag': '🇨🇿', 'dial': '+420'},
  {'name': 'Denmark', 'code': 'DK', 'flag': '🇩🇰', 'dial': '+45'},
  {'name': 'Ecuador', 'code': 'EC', 'flag': '🇪🇨', 'dial': '+593'},
  {'name': 'Egypt', 'code': 'EG', 'flag': '🇪🇬', 'dial': '+20'},
  {'name': 'England', 'code': 'GB', 'flag': '🏴󠁧󠁢󠁥󠁮󠁧󠁿', 'dial': '+44'},
  {'name': 'Estonia', 'code': 'EE', 'flag': '🇪🇪', 'dial': '+372'},
  {'name': 'Ethiopia', 'code': 'ET', 'flag': '🇪🇹', 'dial': '+251'},
  {'name': 'Fiji', 'code': 'FJ', 'flag': '🇫🇯', 'dial': '+679'},
  {'name': 'Finland', 'code': 'FI', 'flag': '🇫🇮', 'dial': '+358'},
  {'name': 'France', 'code': 'FR', 'flag': '🇫🇷', 'dial': '+33'},
  {'name': 'Georgia', 'code': 'GE', 'flag': '🇬🇪', 'dial': '+995'},
  {'name': 'Germany', 'code': 'DE', 'flag': '🇩🇪', 'dial': '+49'},
  {'name': 'Ghana', 'code': 'GH', 'flag': '🇬🇭', 'dial': '+233'},
  {'name': 'Greece', 'code': 'GR', 'flag': '🇬🇷', 'dial': '+30'},
  {'name': 'Hong Kong', 'code': 'HK', 'flag': '🇭🇰', 'dial': '+852'},
  {'name': 'Hungary', 'code': 'HU', 'flag': '🇭🇺', 'dial': '+36'},
  {'name': 'Iceland', 'code': 'IS', 'flag': '🇮🇸', 'dial': '+354'},
  {'name': 'India', 'code': 'IN', 'flag': '🇮🇳', 'dial': '+91'},
  {'name': 'Indonesia', 'code': 'ID', 'flag': '🇮🇩', 'dial': '+62'},
  {'name': 'Iran', 'code': 'IR', 'flag': '🇮🇷', 'dial': '+98'},
  {'name': 'Iraq', 'code': 'IQ', 'flag': '🇮🇶', 'dial': '+964'},
  {'name': 'Ireland', 'code': 'IE', 'flag': '🇮🇪', 'dial': '+353'},
  {'name': 'Israel', 'code': 'IL', 'flag': '🇮🇱', 'dial': '+972'},
  {'name': 'Italy', 'code': 'IT', 'flag': '🇮🇹', 'dial': '+39'},
  {'name': 'Jamaica', 'code': 'JM', 'flag': '🇯🇲', 'dial': '+1'},
  {'name': 'Japan', 'code': 'JP', 'flag': '🇯🇵', 'dial': '+81'},
  {'name': 'Jordan', 'code': 'JO', 'flag': '🇯🇴', 'dial': '+962'},
  {'name': 'Kenya', 'code': 'KE', 'flag': '🇰🇪', 'dial': '+254'},
  {'name': 'Kuwait', 'code': 'KW', 'flag': '🇰🇼', 'dial': '+965'},
  {'name': 'Laos', 'code': 'LA', 'flag': '🇱🇦', 'dial': '+856'},
  {'name': 'Latvia', 'code': 'LV', 'flag': '🇱🇻', 'dial': '+371'},
  {'name': 'Lebanon', 'code': 'LB', 'flag': '🇱🇧', 'dial': '+961'},
  {'name': 'Libya', 'code': 'LY', 'flag': '🇱🇾', 'dial': '+218'},
  {'name': 'Lithuania', 'code': 'LT', 'flag': '🇱🇹', 'dial': '+370'},
  {'name': 'Luxembourg', 'code': 'LU', 'flag': '🇱🇺', 'dial': '+352'},
  {'name': 'Macau', 'code': 'MO', 'flag': '🇲🇴', 'dial': '+853'},
  {'name': 'Malaysia', 'code': 'MY', 'flag': '🇲🇾', 'dial': '+60'},
  {'name': 'Maldives', 'code': 'MV', 'flag': '🇲🇻', 'dial': '+960'},
  {'name': 'Malta', 'code': 'MT', 'flag': '🇲🇹', 'dial': '+356'},
  {'name': 'Mauritius', 'code': 'MU', 'flag': '🇲🇺', 'dial': '+230'},
  {'name': 'Mexico', 'code': 'MX', 'flag': '🇲🇽', 'dial': '+52'},
  {'name': 'Mongolia', 'code': 'MN', 'flag': '🇲🇳', 'dial': '+976'},
  {'name': 'Morocco', 'code': 'MA', 'flag': '🇲🇦', 'dial': '+212'},
  {'name': 'Myanmar', 'code': 'MM', 'flag': '🇲🇲', 'dial': '+95'},
  {'name': 'Namibia', 'code': 'NA', 'flag': '🇳🇦', 'dial': '+264'},
  {'name': 'Nepal', 'code': 'NP', 'flag': '🇳🇵', 'dial': '+977'},
  {'name': 'Netherlands', 'code': 'NL', 'flag': '🇳🇱', 'dial': '+31'},
  {'name': 'New Zealand', 'code': 'NZ', 'flag': '🇳🇿', 'dial': '+64'},
  {'name': 'Nigeria', 'code': 'NG', 'flag': '🇳🇬', 'dial': '+234'},
  {'name': 'North Korea', 'code': 'KP', 'flag': '🇰🇵', 'dial': '+850'},
  {'name': 'Norway', 'code': 'NO', 'flag': '🇳🇴', 'dial': '+47'},
  {'name': 'Oman', 'code': 'OM', 'flag': '🇴🇲', 'dial': '+968'},
  {'name': 'Pakistan', 'code': 'PK', 'flag': '🇵🇰', 'dial': '+92'},
  {'name': 'Palestine', 'code': 'PS', 'flag': '🇵🇸', 'dial': '+970'},
  {'name': 'Panama', 'code': 'PA', 'flag': '🇵🇦', 'dial': '+507'},
  {'name': 'Papua New Guinea', 'code': 'PG', 'flag': '🇵🇬', 'dial': '+675'},
  {'name': 'Paraguay', 'code': 'PY', 'flag': '🇵🇾', 'dial': '+595'},
  {'name': 'Peru', 'code': 'PE', 'flag': '🇵🇪', 'dial': '+51'},
  {'name': 'Philippines', 'code': 'PH', 'flag': '🇵🇭', 'dial': '+63'},
  {'name': 'Poland', 'code': 'PL', 'flag': '🇵🇱', 'dial': '+48'},
  {'name': 'Portugal', 'code': 'PT', 'flag': '🇵🇹', 'dial': '+351'},
  {'name': 'Qatar', 'code': 'QA', 'flag': '🇶🇦', 'dial': '+974'},
  {'name': 'Romania', 'code': 'RO', 'flag': '🇷🇴', 'dial': '+40'},
  {'name': 'Russia', 'code': 'RU', 'flag': '🇷🇺', 'dial': '+7'},
  {'name': 'Rwanda', 'code': 'RW', 'flag': '🇷🇼', 'dial': '+250'},
  {'name': 'Saudi Arabia', 'code': 'SA', 'flag': '🇸🇦', 'dial': '+966'},
  {'name': 'Scotland', 'code': 'GB-SCT', 'flag': '🏴󠁧󠁢󠁳󠁣󠁴󠁿', 'dial': '+44'},
  {'name': 'Senegal', 'code': 'SN', 'flag': '🇸🇳', 'dial': '+221'},
  {'name': 'Serbia', 'code': 'RS', 'flag': '🇷🇸', 'dial': '+381'},
  {'name': 'Singapore', 'code': 'SG', 'flag': '🇸🇬', 'dial': '+65'},
  {'name': 'Slovakia', 'code': 'SK', 'flag': '🇸🇰', 'dial': '+421'},
  {'name': 'Slovenia', 'code': 'SI', 'flag': '🇸🇮', 'dial': '+386'},
  {'name': 'South Africa', 'code': 'ZA', 'flag': '🇿🇦', 'dial': '+27'},
  {'name': 'South Korea', 'code': 'KR', 'flag': '🇰🇷', 'dial': '+82'},
  {'name': 'Spain', 'code': 'ES', 'flag': '🇪🇸', 'dial': '+34'},
  {'name': 'Sri Lanka', 'code': 'LK', 'flag': '🇱🇰', 'dial': '+94'},
  {'name': 'Sudan', 'code': 'SD', 'flag': '🇸🇩', 'dial': '+249'},
  {'name': 'Sweden', 'code': 'SE', 'flag': '🇸🇪', 'dial': '+46'},
  {'name': 'Switzerland', 'code': 'CH', 'flag': '🇨🇭', 'dial': '+41'},
  {'name': 'Syria', 'code': 'SY', 'flag': '🇸🇾', 'dial': '+963'},
  {'name': 'Taiwan', 'code': 'TW', 'flag': '🇹🇼', 'dial': '+886'},
  {'name': 'Tanzania', 'code': 'TZ', 'flag': '🇹🇿', 'dial': '+255'},
  {'name': 'Thailand', 'code': 'TH', 'flag': '🇹🇭', 'dial': '+66'},
  {'name': 'Trinidad and Tobago', 'code': 'TT', 'flag': '🇹🇹', 'dial': '+1'},
  {'name': 'Tunisia', 'code': 'TN', 'flag': '🇹🇳', 'dial': '+216'},
  {'name': 'Turkey', 'code': 'TR', 'flag': '🇹🇷', 'dial': '+90'},
  {'name': 'Uganda', 'code': 'UG', 'flag': '🇺🇬', 'dial': '+256'},
  {'name': 'Ukraine', 'code': 'UA', 'flag': '🇺🇦', 'dial': '+380'},
  {'name': 'United Arab Emirates', 'code': 'AE', 'flag': '🇦🇪', 'dial': '+971'},
  {'name': 'United Kingdom', 'code': 'GB', 'flag': '🇬🇧', 'dial': '+44'},
  {'name': 'United States', 'code': 'US', 'flag': '🇺🇸', 'dial': '+1'},
  {'name': 'Uruguay', 'code': 'UY', 'flag': '🇺🇾', 'dial': '+598'},
  {'name': 'Uzbekistan', 'code': 'UZ', 'flag': '🇺🇿', 'dial': '+998'},
  {'name': 'Venezuela', 'code': 'VE', 'flag': '🇻🇪', 'dial': '+58'},
  {'name': 'Vietnam', 'code': 'VN', 'flag': '🇻🇳', 'dial': '+84'},
  {'name': 'West Indies', 'code': 'WI', 'flag': '🏏', 'dial': '+1'},
  {'name': 'Yemen', 'code': 'YE', 'flag': '🇾🇪', 'dial': '+967'},
  {'name': 'Zambia', 'code': 'ZM', 'flag': '🇿🇲', 'dial': '+260'},
  {'name': 'Zimbabwe', 'code': 'ZW', 'flag': '🇿🇼', 'dial': '+263'},
];

List<CountryData> buildSortedCountryList() {
  final byName = {
    for (final raw in _allCountriesRaw)
      raw['name']!: CountryData(
        name: raw['name']!,
        code: raw['code']!,
        flag: raw['flag']!,
        dialCode: raw['dial']!,
      ),
  };

  final pinned = <CountryData>[];
  for (final name in pinnedCricketNationNames) {
    final c = byName[name];
    if (c != null) pinned.add(c);
  }

  final pinnedSet = pinnedCricketNationNames.toSet();
  final rest = byName.values.where((c) => !pinnedSet.contains(c.name)).toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  return [...pinned, ...rest];
}

/// Unique dial codes for phone prefix dropdown (sorted by code).
List<String> buildPhoneDialCodes(List<CountryData> countries) {
  final codes = countries.map((c) => c.dialCode).toSet().toList()
    ..sort((a, b) {
      final na = int.tryParse(a.replaceAll('+', '')) ?? 0;
      final nb = int.tryParse(b.replaceAll('+', '')) ?? 0;
      return na.compareTo(nb);
    });
  return codes;
}
