import 'package:equatable/equatable.dart';

class LocationModel extends Equatable {
  const LocationModel({
    this.country = '',
    this.stateProvince = '',
    this.district = '',
    this.city = '',
    this.latitude,
    this.longitude,
  });

  final String country;
  final String stateProvince;
  final String district;
  final String city;

  /// Optional GPS from ground picker / reverse geocode. Null for legacy docs.
  final double? latitude;
  final double? longitude;

  bool get isEmpty =>
      country.isEmpty &&
      stateProvince.isEmpty &&
      district.isEmpty &&
      city.isEmpty &&
      !hasCoordinates;

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite;

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
      latitude: (map['latitude'] as num?)?.toDouble() ??
          (map['lat'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble() ??
          (map['lng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'country': country,
        'stateProvince': stateProvince,
        'district': district,
        'city': city,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  LocationModel copyWith({
    String? country,
    String? stateProvince,
    String? district,
    String? city,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
  }) {
    return LocationModel(
      country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      district: district ?? this.district,
      city: city ?? this.city,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
    );
  }

  @override
  List<Object?> get props =>
      [country, stateProvince, district, city, latitude, longitude];
}
