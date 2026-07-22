import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../../data/models/location_model.dart';
import '../../data/services/google_maps_location_service.dart';

/// Shared "near you" radius (Home nearby sections + Community Near filter).
const double kNearbyRadiusKm = 30;

/// Earth-surface distance in kilometres between two coordinates.
double distanceKmBetween(GeoCoords a, GeoCoords b) {
  return Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      ) /
      1000.0;
}

/// Formats a distance for UI, e.g. `3.8 km away` or `850 m away`.
String formatDistanceAway(double km) {
  if (km < 1) {
    final meters = (km * 1000).round();
    return '$meters m away';
  }
  final rounded = km < 10 ? km.toStringAsFixed(1) : km.round().toString();
  return '$rounded km away';
}

/// Returns true when [location] has usable GPS coordinates.
bool locationHasCoords(LocationModel location) => location.hasCoordinates;

/// Rough bounding-box filter before precise distance (degrees ≈ km/111).
bool withinApproxBoundingBox({
  required GeoCoords origin,
  required double lat,
  required double lng,
  required double radiusKm,
}) {
  final delta = radiusKm / 111.0;
  if ((lat - origin.latitude).abs() > delta) return false;
  final cosLat = math.cos(origin.latitude * math.pi / 180).abs().clamp(0.2, 1.0);
  final lngDelta = radiusKm / (111.0 * cosLat);
  return (lng - origin.longitude).abs() <= lngDelta;
}
