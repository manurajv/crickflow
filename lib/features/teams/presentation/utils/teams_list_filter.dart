import '../../../../core/utils/cf_team_id_format.dart';
import '../../../../data/models/location_filter_selection.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/player_model.dart';
import '../../../../data/models/team_model.dart';
import '../widgets/team_list_scope.dart';

/// Client-side team list filtering (search + location + scope).
class TeamsListFilter {
  TeamsListFilter._();

  /// Teams where [uid] is on the roster (not merely the creator).
  static Set<String> memberTeamIds({
    required List<TeamModel> teams,
    required String? uid,
    PlayerModel? player,
  }) {
    if (uid == null || uid.isEmpty) return {};
    final ids = <String>{};
    if (player != null) {
      ids.addAll(player.effectiveTeamIds);
    }

    for (final t in teams) {
      if (t.playerIds.contains(uid)) ids.add(t.id);
      if (player != null &&
          player.id.isNotEmpty &&
          t.playerIds.contains(player.id)) {
        ids.add(t.id);
      }
    }
    return ids;
  }

  /// Opponent team ids from matches involving any of [memberTeamIds].
  static Set<String> opponentTeamIds({
    required List<MatchModel> matches,
    required Set<String> memberTeamIds,
  }) {
    if (memberTeamIds.isEmpty) return {};
    final ids = <String>{};
    for (final m in matches) {
      final a = m.teamAId;
      final b = m.teamBId;
      if (a == null || a.isEmpty || b == null || b.isEmpty) continue;

      if (memberTeamIds.contains(a) && !memberTeamIds.contains(b)) {
        ids.add(b);
      } else if (memberTeamIds.contains(b) && !memberTeamIds.contains(a)) {
        ids.add(a);
      }
    }
    return ids;
  }

  static List<TeamModel> apply({
    required List<TeamModel> teams,
    required TeamListScope scope,
    String query = '',
    List<LocationFilterSelection> locations = const [],
    Set<String> memberTeamIds = const {},
    Set<String> opponentTeamIds = const {},
  }) {
    var list = teams.where((t) {
      switch (scope) {
        case TeamListScope.yours:
          if (!memberTeamIds.contains(t.id)) return false;
        case TeamListScope.opponents:
          if (!opponentTeamIds.contains(t.id)) return false;
        case TeamListScope.all:
          break;
      }
      if (!locationMatchesAnySelection(t.location, locations)) return false;
      return true;
    }).toList();

    final q = query.trim();
    if (q.isEmpty) return _sortByName(list);

    final qLower = q.toLowerCase();

    list = list.where((t) {
      if (t.name.toLowerCase().contains(qLower)) return true;
      if (CfTeamIdFormat.matchesPartialQuery(t.teamCode, q)) return true;
      if (t.location.city.toLowerCase().contains(qLower)) return true;
      if (t.location.country.toLowerCase().contains(qLower)) return true;
      return false;
    }).toList();

    return _sortByName(list, query: q, queryPrefix: qLower);
  }

  static List<String> distinctCities(
    List<TeamModel> teams, {
    String country = '',
  }) {
    final cities = <String>{};
    for (final t in teams) {
      final city = t.location.city.trim();
      if (city.isEmpty) continue;
      if (country.isNotEmpty &&
          !t.location.country.toLowerCase().contains(country.toLowerCase())) {
        continue;
      }
      cities.add(city);
    }
    final sorted = cities.toList()..sort((a, b) => a.compareTo(b));
    return sorted;
  }

  static List<TeamModel> _sortByName(
    List<TeamModel> list, {
    String queryPrefix = '',
    String query = '',
  }) {
    list.sort((a, b) {
      if (query.isNotEmpty) {
        final aCode = CfTeamIdFormat.matchesPartialQuery(a.teamCode, query);
        final bCode = CfTeamIdFormat.matchesPartialQuery(b.teamCode, query);
        if (aCode != bCode) return aCode ? -1 : 1;
      }
      if (queryPrefix.isNotEmpty) {
        final aStarts = a.name.toLowerCase().startsWith(queryPrefix);
        final bStarts = b.name.toLowerCase().startsWith(queryPrefix);
        if (aStarts != bStarts) return aStarts ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });
    return list;
  }
}
