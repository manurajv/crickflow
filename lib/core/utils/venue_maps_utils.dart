import 'package:url_launcher/url_launcher.dart';

/// Opens Google Maps directions to [destination] from the user's current location.
Future<bool> openVenueDirections({required String destination}) async {
  final query = destination.trim();
  if (query.isEmpty) return false;

  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(query)}',
  );

  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
