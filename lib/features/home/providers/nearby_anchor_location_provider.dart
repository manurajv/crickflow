import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/location_text_filter.dart';
import '../../../data/models/location_model.dart';

/// Home nearby sections anchor. `null` = live device GPS ("Near You").
final nearbyAnchorLocationProvider =
    StateProvider<LocationModel?>((ref) => null);

/// City filter (or no filter / GPS) uses 50 km radius; country/state uses text match.
bool nearbyFilterUsesRadius(LocationModel? anchor) {
  if (anchor == null || anchor.isEmpty) return true;
  return anchor.city.trim().isNotEmpty;
}

/// Short place name for titles (city → state → country), same as rankings.
String nearbyAnchorShortName(LocationModel location) {
  final label = locationFilterSummaryLabel(location);
  if (label.isNotEmpty) return label;
  for (final p in [location.district, location.placeName]) {
    final t = p.trim();
    if (t.isNotEmpty) return t;
  }
  return 'this area';
}

String nearbyMatchesSectionTitle(LocationModel? anchor) {
  if (anchor == null || anchor.isEmpty) return 'Matches Near You';
  return 'Matches in ${nearbyAnchorShortName(anchor)}';
}

String nearbyTournamentsSectionTitle(LocationModel? anchor) {
  if (anchor == null || anchor.isEmpty) return 'Tournaments Near You';
  return 'Tournaments in ${nearbyAnchorShortName(anchor)}';
}
