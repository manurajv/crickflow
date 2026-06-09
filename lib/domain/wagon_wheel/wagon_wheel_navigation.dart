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
    if (filter.bowlerId != null) q['bowlerId'] = filter.bowlerId!;
    if (filter.teamId != null) q['teamId'] = filter.teamId!;
    if (filter.matchId != null) q['matchId'] = filter.matchId!;
    if (filter.tournamentId != null) q['tournamentId'] = filter.tournamentId!;
    if (filter.inningsNumber != null) {
      q['innings'] = '${filter.inningsNumber}';
    }
    if (filter.runFilter != WagonWheelRunFilter.all) {
      q['runs'] = filter.runFilter.name;
    }
    if (filter.viewMode != WagonWheelViewMode.lines) {
      q['view'] = filter.viewMode.name;
    }
    if (filter.fromDate != null) {
      q['from'] = filter.fromDate!.toIso8601String();
    }
    if (filter.toDate != null) {
      q['to'] = filter.toDate!.toIso8601String();
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
