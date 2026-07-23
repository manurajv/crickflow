import 'location_model.dart';

/// One selectable location node (country / state / district / city).
class LocationFilterSelection {
  const LocationFilterSelection({
    this.country = '',
    this.stateProvince = '',
    this.district = '',
    this.city = '',
  });

  final String country;
  final String stateProvince;
  final String district;
  final String city;

  bool get isEmpty =>
      country.isEmpty &&
      stateProvince.isEmpty &&
      district.isEmpty &&
      city.isEmpty;

  String get label {
    final parts = <String>[
      if (city.isNotEmpty) city,
      if (district.isNotEmpty) district,
      if (stateProvince.isNotEmpty) stateProvince,
      if (country.isNotEmpty) country,
    ];
    return parts.join(', ');
  }

  Map<String, dynamic> toMap() => {
        'country': country,
        'stateProvince': stateProvince,
        'district': district,
        'city': city,
      };

  factory LocationFilterSelection.fromMap(Map<String, dynamic> map) {
    return LocationFilterSelection(
      country: map['country'] as String? ?? '',
      stateProvince: map['stateProvince'] as String? ?? '',
      district: map['district'] as String? ?? '',
      city: map['city'] as String? ?? '',
    );
  }

  /// True when [loc] matches this selection (broader selections match more).
  bool matches(LocationModel loc) {
    if (isEmpty) return true;
    bool eq(String a, String b) =>
        a.trim().toLowerCase() == b.trim().toLowerCase();

    if (country.isNotEmpty && !eq(loc.country, country)) return false;
    if (stateProvince.isNotEmpty &&
        !eq(loc.stateProvince, stateProvince)) {
      return false;
    }
    if (district.isNotEmpty && !eq(loc.district, district)) return false;
    if (city.isNotEmpty && !eq(loc.city, city)) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is LocationFilterSelection &&
      other.country == country &&
      other.stateProvince == stateProvince &&
      other.district == district &&
      other.city == city;

  @override
  int get hashCode => Object.hash(country, stateProvince, district, city);
}

/// True when [loc] matches any of [selections]. Empty [selections] = no filter.
bool locationMatchesAnySelection(
  LocationModel loc,
  List<LocationFilterSelection> selections,
) {
  if (selections.isEmpty) return true;
  return selections.any((s) => s.matches(loc));
}
