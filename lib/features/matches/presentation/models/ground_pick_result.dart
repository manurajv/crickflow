import '../../../../data/models/location_model.dart';
import '../../../../data/services/google_maps_location_service.dart';

/// Result from [GroundMapPickerScreen] or ground place search.
class GroundPickResult {
  const GroundPickResult({
    required this.groundName,
    required this.location,
    this.coords,
  });

  final String groundName;
  final LocationModel location;

  /// Pin coordinates when the user picked a place on the map / Places API.
  final GeoCoords? coords;
}

String groundNameFromPlaceDescription(String description) {
  final trimmed = description.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.split(',').first.trim();
}
