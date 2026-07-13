import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/location_model.dart';
import 'providers.dart';

/// Resolves the guest device's current city/country for nearby discovery lists.
final guestDeviceLocationProvider = FutureProvider<LocationModel?>((ref) async {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid != null) return null;

  final service = ref.watch(googleMapsLocationServiceProvider);
  final coords = await service.getCurrentCoords();
  if (coords == null) return null;

  try {
    final resolved = await service.reverseGeocode(coords);
    return resolved.location;
  } catch (_) {
    return null;
  }
});
