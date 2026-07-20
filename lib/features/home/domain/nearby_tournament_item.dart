import '../../../data/models/tournament_model.dart';
import '../../../data/services/google_maps_location_service.dart';

class NearbyTournamentItem {
  const NearbyTournamentItem({
    required this.tournament,
    this.distanceKm,
    this.regionFallback = false,
  });

  final TournamentModel tournament;
  final double? distanceKm;
  final bool regionFallback;
}

enum NearbyTournamentsStatus {
  loading,
  ready,
  permissionDenied,
  serviceDisabled,
  empty,
  error,
}

class NearbyTournamentsState {
  const NearbyTournamentsState({
    this.status = NearbyTournamentsStatus.loading,
    this.items = const [],
    this.userCoords,
    this.regionLabel = '',
    this.message = '',
  });

  final NearbyTournamentsStatus status;
  final List<NearbyTournamentItem> items;
  final GeoCoords? userCoords;
  final String regionLabel;
  final String message;
}
