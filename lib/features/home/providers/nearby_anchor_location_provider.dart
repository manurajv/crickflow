import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/location_model.dart';

/// Home nearby sections anchor. `null` = device location → state/province.
final nearbyAnchorLocationProvider =
    StateProvider<LocationModel?>((ref) => null);

/// Country + state/province only (city ignored for home nearby filtering).
LocationModel nearbyRegionFilter(LocationModel location) {
  return LocationModel(
    country: location.country.trim(),
    stateProvince: location.stateProvince.trim().isNotEmpty
        ? location.stateProvince.trim()
        : (location.district.trim().isNotEmpty
            ? location.district.trim()
            : ''),
  );
}

/// Label for titles: state/province → country.
String nearbyRegionLabel(LocationModel location) {
  final region = nearbyRegionFilter(location);
  if (region.stateProvince.isNotEmpty) return region.stateProvince;
  if (region.country.isNotEmpty) return region.country;
  return '';
}

String nearbyAnchorShortName(LocationModel location) {
  final label = nearbyRegionLabel(location);
  return label.isNotEmpty ? label : 'this area';
}

String nearbyMatchesSectionTitle(LocationModel? anchor) {
  if (anchor == null || anchor.isEmpty) return 'Matches Near You';
  return 'Matches in ${nearbyAnchorShortName(anchor)}';
}

String nearbyTournamentsSectionTitle(LocationModel? anchor) {
  if (anchor == null || anchor.isEmpty) return 'Tournaments Near You';
  return 'Tournaments in ${nearbyAnchorShortName(anchor)}';
}
