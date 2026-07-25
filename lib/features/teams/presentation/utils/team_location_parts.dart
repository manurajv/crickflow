import '../../../../data/models/location_model.dart';

/// Splits / merges team region vs Google home-ground on the shared [LocationModel].
class TeamLocationParts {
  const TeamLocationParts({
    required this.teamLocation,
    required this.homeGround,
  });

  /// Country / province / city (no venue name).
  final LocationModel teamLocation;

  /// Google place / map pin for home ground.
  final LocationModel homeGround;

  factory TeamLocationParts.fromStored(LocationModel stored) {
    final hasGround = stored.placeName.trim().isNotEmpty;
    return TeamLocationParts(
      teamLocation: LocationModel(
        country: stored.country,
        stateProvince: stored.stateProvince,
        district: stored.district,
        city: stored.city,
        latitude: hasGround ? null : stored.latitude,
        longitude: hasGround ? null : stored.longitude,
      ),
      homeGround: hasGround
          ? LocationModel(
              placeName: stored.placeName,
              city: stored.city,
              district: stored.district,
              stateProvince: stored.stateProvince,
              country: stored.country,
              latitude: stored.latitude,
              longitude: stored.longitude,
            )
          : const LocationModel(),
    );
  }

  LocationModel merge() {
    final groundName = homeGround.placeName.trim();
    final useGroundCoords = homeGround.hasCoordinates;
    return LocationModel(
      country: teamLocation.country,
      stateProvince: teamLocation.stateProvince,
      district: teamLocation.district,
      city: teamLocation.city,
      placeName: groundName,
      latitude: useGroundCoords
          ? homeGround.latitude
          : teamLocation.latitude,
      longitude: useGroundCoords
          ? homeGround.longitude
          : teamLocation.longitude,
    );
  }
}
