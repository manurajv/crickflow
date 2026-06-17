import '../../../../data/models/location_model.dart';

/// Result from [GroundMapPickerScreen] or ground place search.
class GroundPickResult {
  const GroundPickResult({
    required this.groundName,
    required this.location,
  });

  final String groundName;
  final LocationModel location;
}

String groundNameFromPlaceDescription(String description) {
  final trimmed = description.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.split(',').first.trim();
}
