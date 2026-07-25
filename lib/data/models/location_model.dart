import 'package:equatable/equatable.dart';

class LocationModel extends Equatable {
  const LocationModel({
    this.country = '',
    this.stateProvince = '',
    this.district = '',
    this.city = '',
    this.placeName = '',
    this.latitude,
    this.longitude,
  });

  final String country;
  final String stateProvince;
  final String district;
  final String city;

  /// Exact venue / ground name from Places or map pin (optional).
  final String placeName;

  /// Optional GPS from ground picker / reverse geocode. Null for legacy docs.
  final double? latitude;
  final double? longitude;

  bool get isEmpty =>
      country.isEmpty &&
      stateProvince.isEmpty &&
      district.isEmpty &&
      city.isEmpty &&
      placeName.isEmpty &&
      !hasCoordinates;

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite;

  String get displayLabel {
    final parts = <String>[];
    for (final p in [placeName, city, district, stateProvince, country]) {
      if (p.isEmpty) continue;
      if (parts.isNotEmpty &&
          parts.last.toLowerCase() == p.toLowerCase()) {
        continue;
      }
      parts.add(p);
    }
    return parts.join(', ');
  }

  factory LocationModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const LocationModel();
    return LocationModel(
      country: map['country'] as String? ?? '',
      stateProvince: map['stateProvince'] as String? ?? '',
      district: map['district'] as String? ?? '',
      city: map['city'] as String? ?? '',
      placeName: map['placeName'] as String? ??
          map['venue'] as String? ??
          map['groundName'] as String? ??
          '',
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
        if (placeName.isNotEmpty) 'placeName': placeName,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  LocationModel copyWith({
    String? country,
    String? stateProvince,
    String? district,
    String? city,
    String? placeName,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
    bool clearPlaceName = false,
  }) {
    return LocationModel(
      country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      district: district ?? this.district,
      city: city ?? this.city,
      placeName: clearPlaceName ? '' : (placeName ?? this.placeName),
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
    );
  }

  @override
  List<Object?> get props => [
        country,
        stateProvince,
        district,
        city,
        placeName,
        latitude,
        longitude,
      ];
}
