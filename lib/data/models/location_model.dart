import 'package:equatable/equatable.dart';

class LocationModel extends Equatable {
  const LocationModel({
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

  String get displayLabel {
    final parts =
        [city, district, stateProvince, country].where((p) => p.isNotEmpty);
    return parts.join(', ');
  }

  factory LocationModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const LocationModel();
    return LocationModel(
      country: map['country'] as String? ?? '',
      stateProvince: map['stateProvince'] as String? ?? '',
      district: map['district'] as String? ?? '',
      city: map['city'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'country': country,
        'stateProvince': stateProvince,
        'district': district,
        'city': city,
      };

  LocationModel copyWith({
    String? country,
    String? stateProvince,
    String? district,
    String? city,
  }) {
    return LocationModel(
      country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      district: district ?? this.district,
      city: city ?? this.city,
    );
  }

  @override
  List<Object?> get props => [country, stateProvince, district, city];
}
