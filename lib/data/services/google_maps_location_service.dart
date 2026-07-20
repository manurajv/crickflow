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
    final first = results.first as Map<String, dynamic>;
    final components =
        first['address_components'] as List<dynamic>? ?? const [];
    final location = _parseAddressComponents(components);
    return ResolvedPlace(
      location: location.copyWith(
        latitude: coords.latitude,
        longitude: coords.longitude,
      ),
      coords: coords,
    );
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
    return ResolvedPlace(
      location: LocationModel(
        country: p.country ?? '',
        stateProvince: p.administrativeArea ?? '',
        city: p.locality?.isNotEmpty == true
            ? p.locality!
            : (p.subAdministrativeArea ?? p.subLocality ?? ''),
        latitude: coords.latitude,
        longitude: coords.longitude,
      ),
      coords: coords,
    );
  }

  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': trimmed,
        'key': MapsConfig.apiKey,
      },
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

  Future<ResolvedPlace> resolvePlace(String placeId) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'address_component,geometry',
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
    return ResolvedPlace(
      location: _parseAddressComponents(components).copyWith(
        latitude: coords.latitude,
        longitude: coords.longitude,
      ),
      coords: coords,
    );
  }

  LocationModel _parseAddressComponents(List<dynamic> components) {
    var country = '';
    var province = '';
    var city = '';

    for (final raw in components) {
      final map = raw as Map<String, dynamic>;
      final types = List<String>.from(map['types'] as List? ?? const []);
      final longName = map['long_name'] as String? ?? '';

      if (types.contains('country')) {
        country = longName;
      } else if (types.contains('administrative_area_level_1')) {
        province = longName;
      } else if (types.contains('locality')) {
        city = longName;
      } else if (city.isEmpty && types.contains('administrative_area_level_2')) {
        city = longName;
      } else if (city.isEmpty && types.contains('postal_town')) {
        city = longName;
      }
    }

    return LocationModel(
      country: country,
      stateProvince: province,
      city: city,
    );
  }

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
