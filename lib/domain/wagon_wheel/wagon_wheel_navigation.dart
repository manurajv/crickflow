import 'package:go_router/go_router.dart';
import 'wagon_wheel_filter.dart';

/// Builds `/wagon-wheel` routes with query parameters.
class WagonWheelNavigation {
  WagonWheelNavigation._();

  static String path({
    required WagonWheelFilter filter,
    String title = 'Wagon wheel',
  }) {
    final q = <String, String>{'title': title};
    if (filter.batterId != null) q['batterId'] = filter.batterId!;
    if (filter.bowlerNameKey != null) q['bowlerNameKey'] = filter.bowlerNameKey!;
    if (filter.bowlerId != null) q['bowlerId'] = filter.bowlerId!;
    if (filter.teamId != null) q['teamId'] = filter.teamId!;
    if (filter.matchId != null) q['matchId'] = filter.matchId!;
    if (filter.tournamentId != null) q['tournamentId'] = filter.tournamentId!;
    if (filter.inningsNumber != null) {
      q['innings'] = '${filter.inningsNumber}';
    }
    if (filter.opponentTeamFilter) q['opponentTeam'] = '1';
    if (filter.batterCareerMode) q['career'] = '1';
    if (filter.runFilter != WagonWheelRunFilter.all) {
      q['runs'] = filter.runFilter.name;
    }
    final query = q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '/wagon-wheel?$query';
  }

  static void open(
    GoRouter router, {
    required WagonWheelFilter filter,
    String title = 'Wagon wheel',
  }) {
    router.push(path(filter: filter, title: title));
  }
}
