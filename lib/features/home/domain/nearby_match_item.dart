import '../../../data/models/match_model.dart';
import '../../../data/services/google_maps_location_service.dart';

/// A match with distance from the user (when GPS radius matching applied).
class NearbyMatchItem {
  const NearbyMatchItem({
    required this.match,
    this.distanceKm,
    this.regionFallback = false,
  });

  final MatchModel match;
  final double? distanceKm;

  /// True when shown via city/state fallback (not precise km).
  final bool regionFallback;
}

enum NearbyMatchesStatus {
  loading,
  ready,
  permissionDenied,
  serviceDisabled,
  empty,
  error,
}

class NearbyMatchesState {
  const NearbyMatchesState({
    this.status = NearbyMatchesStatus.loading,
    this.items = const [],
    this.userCoords,
    this.regionLabel = '',
    this.message = '',
  });

  final NearbyMatchesStatus status;
  final List<NearbyMatchItem> items;
  final GeoCoords? userCoords;
  final String regionLabel;
  final String message;

  NearbyMatchesState copyWith({
    NearbyMatchesStatus? status,
    List<NearbyMatchItem>? items,
    GeoCoords? userCoords,
    String? regionLabel,
    String? message,
  }) {
    return NearbyMatchesState(
      status: status ?? this.status,
      items: items ?? this.items,
      userCoords: userCoords ?? this.userCoords,
      regionLabel: regionLabel ?? this.regionLabel,
      message: message ?? this.message,
    );
  }
}
