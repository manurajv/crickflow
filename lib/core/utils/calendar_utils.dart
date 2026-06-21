import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/match_model.dart';

/// Opens Google Calendar with a pre-filled event for the match.
Future<bool> addMatchToCalendar(MatchModel match) async {
  final start = match.scheduledAt;
  if (start == null) return false;

  final end = start.add(const Duration(hours: 3));
  final fmt = DateFormat("yyyyMMdd'T'HHmmss'Z'");
  final dates =
      '${fmt.format(start.toUtc())}/${fmt.format(end.toUtc())}';

  final title = Uri.encodeComponent(match.title);
  final details = Uri.encodeComponent(
    '${match.teamAName} vs ${match.teamBName}',
  );
  final location = Uri.encodeComponent(_venue(match));

  final uri = Uri.parse(
    'https://calendar.google.com/calendar/render?action=TEMPLATE'
    '&text=$title&dates=$dates&details=$details&location=$location',
  );
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _venue(MatchModel match) {
  final venue = match.venue.trim();
  final city = match.location.city.trim();
  if (venue.isEmpty) return city;
  if (city.isEmpty) return venue;
  return '$venue, $city';
}
