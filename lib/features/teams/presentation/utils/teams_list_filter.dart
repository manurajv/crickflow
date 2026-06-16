import '../../../../core/utils/cf_team_id_format.dart';
import '../../../../data/models/team_model.dart';
import '../../../../shared/widgets/location_filter_bar.dart';

/// Client-side team list filtering (search + location + ownership).
class TeamsListFilter {
  TeamsListFilter._();

  static List<TeamModel> apply({
    required List<TeamModel> teams,
    String query = '',
    String country = '',
    String city = '',
    String? uid,
    bool yoursOnly = false,
    bool opponentsOnly = false,
  }) {
    var list = teams.where((t) {
      if (yoursOnly && uid != null && t.createdBy != uid) return false;
      if (opponentsOnly && uid != null && t.createdBy == uid) return false;
      if (!locationMatchesFilter(t.location, country, city)) return false;
      return true;
    }).toList();

    final q = query.trim();
    if (q.isEmpty) return _sortByName(list);

    final qLower = q.toLowerCase();
    final normalizedCode = CfTeamIdFormat.normalize(q);

    list = list.where((t) {
      if (t.name.toLowerCase().contains(qLower)) return true;
      if (t.teamCode != null &&
          CfTeamIdFormat.normalize(t.teamCode!) == normalizedCode) {
        return true;
      }
      if (t.teamCode != null &&
          t.teamCode!.toUpperCase().contains(normalizedCode)) {
        return true;
      }
      if (t.location.city.toLowerCase().contains(qLower)) return true;
      if (t.location.country.toLowerCase().contains(qLower)) return true;
      return false;
    }).toList();

    return _sortByName(list, queryPrefix: qLower);
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
          !t.location.country
              .toLowerCase()
              .contains(country.toLowerCase())) {
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
  }) {
    list.sort((a, b) {
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
