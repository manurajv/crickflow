import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/maps_config.dart';
import '../models/location_model.dart';

class GeoCoords {
  const GeoCoords({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.description,
  });

  final String placeId;
  final String description;
}

class ResolvedPlace {
  const ResolvedPlace({
    required this.location,
    required this.coords,
  });

  final LocationModel location;
  final GeoCoords coords;
}

enum LocationAccessStatus {
  granted,
  serviceDisabled,
  denied,
  deniedForever,
}

/// Resolves addresses via Google Geocoding + Places, with device geocoding fallback.
class GoogleMapsLocationService {
  static const _defaultCoords = GeoCoords(latitude: 6.9271, longitude: 79.8612);

  Future<LocationAccessStatus> ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccessStatus.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationAccessStatus.deniedForever;
    }
    if (permission == LocationPermission.denied) {
      return LocationAccessStatus.denied;
    }
    return LocationAccessStatus.granted;
  }

  Future<GeoCoords?> getCurrentCoords() async {
    final access = await ensureLocationPermission();
    if (access != LocationAccessStatus.granted) return null;
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return GeoCoords(latitude: pos.latitude, longitude: pos.longitude);
  }

  Future<ResolvedPlace> reverseGeocode(GeoCoords coords) async {
    try {
      return await _reverseGeocodeGoogle(coords);
    } catch (_) {
      return _reverseGeocodeDevice(coords);
    }
  }

  Future<ResolvedPlace> _reverseGeocodeGoogle(GeoCoords coords) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '${coords.latitude},${coords.longitude}',
        'key': MapsConfig.apiKey,
      },
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Geocoding HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String? ?? 'UNKNOWN';
    if (status != 'OK') {
      final err = body['error_message'] as String? ?? status;
      throw Exception('Geocoding API: $err');
    }
    final results = body['results'] as List<dynamic>;
    if (results.isEmpty) {
      throw Exception('No address found for this point');
    }
    final best = _pickBestGeocodeResult(results);
    final components =
        best['address_components'] as List<dynamic>? ?? const [];
    final formatted = best['formatted_address'] as String? ?? '';
    final location = _parseAddressComponents(
      components,
      fallbackDescription: formatted,
    );
    return ResolvedPlace(
      location: location.copyWith(
        latitude: coords.latitude,
        longitude: coords.longitude,
      ),
      coords: coords,
    );
  }

  /// Prefer a geocode result that names a local settlement, not only a route.
  Map<String, dynamic> _pickBestGeocodeResult(List<dynamic> results) {
    Map<String, dynamic>? withSublocality;
    Map<String, dynamic>? withLocality;
    Map<String, dynamic>? withNeighborhood;

    for (final raw in results) {
      final map = raw as Map<String, dynamic>;
      final components =
          map['address_components'] as List<dynamic>? ?? const [];
      var hasSublocality = false;
      var hasLocality = false;
      var hasNeighborhood = false;
      for (final c in components) {
        final types = List<String>.from(
          (c as Map<String, dynamic>)['types'] as List? ?? const [],
        );
        if (types.contains('sublocality') ||
            types.contains('sublocality_level_1')) {
          hasSublocality = true;
        }
        if (types.contains('locality')) hasLocality = true;
        if (types.contains('neighborhood')) hasNeighborhood = true;
      }
      if (hasNeighborhood) withNeighborhood ??= map;
      if (hasSublocality) withSublocality ??= map;
      if (hasLocality) withLocality ??= map;
    }

    return withNeighborhood ??
        withSublocality ??
        withLocality ??
        results.first as Map<String, dynamic>;
  }

  Future<ResolvedPlace> _reverseGeocodeDevice(GeoCoords coords) async {
    final placemarks = await placemarkFromCoordinates(
      coords.latitude,
      coords.longitude,
    );
    if (placemarks.isEmpty) {
      throw Exception('Could not resolve address on this device');
    }
    final p = placemarks.first;
    final subLocality = p.subLocality?.trim() ?? '';
    final locality = p.locality?.trim() ?? '';
    final subAdmin = p.subAdministrativeArea?.trim() ?? '';
    final city = subLocality.isNotEmpty
        ? subLocality
        : (locality.isNotEmpty ? locality : subAdmin);
    var district = subAdmin;
    if (district.isEmpty &&
        locality.isNotEmpty &&
        locality.toLowerCase() != city.toLowerCase()) {
      district = locality;
    }
    if (district.toLowerCase() == city.toLowerCase()) {
      district = '';
    }
    return ResolvedPlace(
      location: LocationModel(
        country: p.country ?? '',
        stateProvince: p.administrativeArea ?? '',
        district: district,
        city: city,
        latitude: coords.latitude,
        longitude: coords.longitude,
      ),
      coords: coords,
    );
  }

  /// [bias] ranks autocomplete results nearer this point (does not hard-filter).
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    GeoCoords? bias,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    final params = <String, String>{
      'input': trimmed,
      'key': MapsConfig.apiKey,
    };
    if (bias != null) {
      params['location'] = '${bias.latitude},${bias.longitude}';
      params['radius'] = '80000';
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      params,
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String? ?? 'UNKNOWN';
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      final err = body['error_message'] as String? ?? status;
      throw Exception('Places API: $err');
    }

    final predictions = body['predictions'] as List<dynamic>? ?? const [];
    return predictions
        .map(
          (p) => PlaceSuggestion(
            placeId: p['place_id'] as String,
            description: p['description'] as String? ?? '',
          ),
        )
        .where((p) => p.placeId.isNotEmpty && p.description.isNotEmpty)
        .toList();
  }

  Future<ResolvedPlace> resolvePlace(
    String placeId, {
    String? fallbackDescription,
  }) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'address_component,geometry,name,types,formatted_address',
        'key': MapsConfig.apiKey,
      },
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Could not load place (${response.statusCode})');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String? ?? 'UNKNOWN';
    if (status != 'OK') {
      final err = body['error_message'] as String? ?? status;
      throw Exception('Place details: $err');
    }
    final result = body['result'] as Map<String, dynamic>;
    final components =
        result['address_components'] as List<dynamic>? ?? const [];
    final geometry = result['geometry'] as Map<String, dynamic>?;
    final loc = geometry?['location'] as Map<String, dynamic>?;
    final coords = GeoCoords(
      latitude: (loc?['lat'] as num?)?.toDouble() ?? _defaultCoords.latitude,
      longitude: (loc?['lng'] as num?)?.toDouble() ?? _defaultCoords.longitude,
    );

    final placeName = (result['name'] as String?)?.trim() ?? '';
    final placeTypes = List<String>.from(result['types'] as List? ?? const []);
    final formatted =
        (result['formatted_address'] as String?)?.trim() ?? '';

    var location = _parseAddressComponents(
      components,
      placeName: placeName,
      placeTypes: placeTypes,
      fallbackDescription: fallbackDescription?.trim().isNotEmpty == true
          ? fallbackDescription!.trim()
          : formatted,
    );

    // POIs / grounds often attach to a parent city. Reverse-geocode the pin
    // so city/district reflect the nearest settlement, then keep a more
    // specific place name when Google named the venue itself.
    final isPoi = placeTypes.any(
      (t) =>
          t == 'establishment' ||
          t == 'point_of_interest' ||
          t == 'premise' ||
          t == 'street_address' ||
          t == 'route',
    );
    if (isPoi) {
      try {
        final nearby = await reverseGeocode(coords);
        location = nearby.location.copyWith(
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
        if (placeName.isNotEmpty &&
            !_sameName(placeName, location.country) &&
            !_sameName(placeName, location.stateProvince) &&
            !_sameName(placeName, location.district) &&
            !_sameName(placeName, location.city)) {
          // Keep the searched/nearby town as city; venue name is not a city.
        }
      } catch (_) {
        // Keep component parse.
      }
    }

    return ResolvedPlace(
      location: location.copyWith(
        latitude: coords.latitude,
        longitude: coords.longitude,
      ),
      coords: coords,
    );
  }

  LocationModel _parseAddressComponents(
    List<dynamic> components, {
    String placeName = '',
    List<String> placeTypes = const [],
    String fallbackDescription = '',
  }) {
    var country = '';
    var province = '';
    var district = '';
    var locality = '';
    var postalTown = '';
    var sublocality = '';
    var neighborhood = '';
    var admin3 = '';

    for (final raw in components) {
      final map = raw as Map<String, dynamic>;
      final types = List<String>.from(map['types'] as List? ?? const []);
      final longName = map['long_name'] as String? ?? '';
      if (longName.isEmpty) continue;

      if (types.contains('country')) {
        country = longName;
      } else if (types.contains('administrative_area_level_1')) {
        province = longName;
      } else if (types.contains('administrative_area_level_2')) {
        district = longName;
      } else if (types.contains('locality')) {
        locality = longName;
      } else if (types.contains('postal_town')) {
        postalTown = longName;
      } else if (types.contains('sublocality') ||
          types.contains('sublocality_level_1') ||
          types.contains('sublocality_level_2')) {
        if (sublocality.isEmpty) sublocality = longName;
      } else if (types.contains('neighborhood')) {
        neighborhood = longName;
      } else if (types.contains('administrative_area_level_3')) {
        admin3 = longName;
      }
    }

    // Most-specific settlement first. Never promote admin_level_2 (district)
    // over a real locality — that was swapping nearby towns for another city.
    var city = [
      neighborhood,
      sublocality,
      locality,
      postalTown,
      admin3,
    ].firstWhere((s) => s.isNotEmpty, orElse: () => '');

    final settlementTypes = {
      'locality',
      'sublocality',
      'sublocality_level_1',
      'neighborhood',
      'postal_town',
      'administrative_area_level_3',
    };
    if (placeName.isNotEmpty &&
        placeTypes.any(settlementTypes.contains) &&
        !_sameName(placeName, country) &&
        !_sameName(placeName, province)) {
      city = placeName;
    }

    if (city.isEmpty && fallbackDescription.isNotEmpty) {
      city = _cityFromDescription(
        fallbackDescription,
        country: country,
        province: province,
        district: district,
      );
    }

    if (city.isEmpty && district.isNotEmpty) {
      city = district;
      district = '';
    }

    if (_sameName(district, city)) {
      district = '';
    }

    return LocationModel(
      country: country,
      stateProvince: province,
      district: district,
      city: city,
    );
  }

  /// Pulls a place/town token from "Name, Town, Province, Country".
  String _cityFromDescription(
    String description, {
    required String country,
    required String province,
    required String district,
  }) {
    final parts = description
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';

    final skip = {country, province, district}
        .where((s) => s.isNotEmpty)
        .map((s) => s.toLowerCase())
        .toSet();

    for (final part in parts.reversed) {
      if (skip.contains(part.toLowerCase())) continue;
      // Skip obvious street tokens.
      if (RegExp(r'\d').hasMatch(part) && part.length > 24) continue;
      return part;
    }
    return parts.first;
  }

  bool _sameName(String a, String b) =>
      a.trim().isNotEmpty &&
      b.trim().isNotEmpty &&
      a.trim().toLowerCase() == b.trim().toLowerCase();

  String messageForAccessStatus(LocationAccessStatus status) {
    return switch (status) {
      LocationAccessStatus.granted => '',
      LocationAccessStatus.serviceDisabled =>
        'Location is turned off. Enable GPS in device settings, then tap the location icon.',
      LocationAccessStatus.denied =>
        'Location permission denied. Allow location access for CrickFlow in app settings.',
      LocationAccessStatus.deniedForever =>
        'Location permission blocked. Open app settings and allow location access.',
    };
  }
}
