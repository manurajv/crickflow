import 'package:url_launcher/url_launcher.dart';

/// Opens Google Maps to show [query] on the map (search / place view).
Future<bool> openVenueInGoogleMaps({required String query}) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return false;

  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(trimmed)}',
  );

  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Opens Google Maps directions to a destination.
///
/// Prefers [latitude]/[longitude] when both are set; otherwise uses [destination].
Future<bool> openVenueDirections({
  String? destination,
  double? latitude,
  double? longitude,
}) async {
  final hasCoords = latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite;
  final query = hasCoords
      ? '$latitude,$longitude'
      : (destination?.trim() ?? '');
  if (query.isEmpty) return false;

  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(query)}',
  );

  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
