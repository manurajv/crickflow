import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';
import 'player_cricket_profile_models.dart';
import 'player_typed_stats_service.dart';

String profileMatchTypeFilterLabel(CricketMatchType type) => switch (type) {
      CricketMatchType.limitedOvers => 'Limited overs',
      CricketMatchType.indoor => 'Indoor',
      CricketMatchType.testMatch => 'Test',
    };

String profileMatchOversFilterLabel(int overs) =>
    overs == -1 ? 'Test' : '$overs overs';

String profileMatchBallTypeFilterLabel(CricketBallType type) =>
    cricketBallTypeLabel(type);

List<MatchModel> filterProfileMatches(
  List<MatchModel> matches,
  ProfileMatchFilters filters,
) {
  return matches.where((m) => _matchesFilters(m, filters)).toList();
}

bool _matchesFilters(MatchModel m, ProfileMatchFilters filters) {
  if (filters.overs != null) {
    if (filters.overs == -1) {
      if (m.rules.cricketMatchType != CricketMatchType.testMatch) return false;
    } else if (m.rules.totalOvers != filters.overs) {
      return false;
    }
  }

  if (filters.ballType != null &&
      m.rules.resolvedBallType != filters.ballType) {
    return false;
  }

  if (filters.matchType != null &&
      m.rules.cricketMatchType != filters.matchType) {
    return false;
  }

  if (filters.year != null) {
    final date = m.completedAt ?? m.scheduledAt ?? m.startedAt;
    if (date == null || date.year != filters.year) return false;
  }

  if (filters.teamId != null && filters.teamId!.isNotEmpty) {
    if (m.teamAId != filters.teamId && m.teamBId != filters.teamId) {
      return false;
    }
  }

  if (filters.tournamentId != null && filters.tournamentId!.isNotEmpty) {
    if (m.tournamentId != filters.tournamentId) return false;
  }

  return true;
}

/// Extract unique filter option values from a player's matches.
class ProfileMatchFilterOptions {
  const ProfileMatchFilterOptions({
    this.years = const [],
    this.teamIds = const {},
    this.tournamentIds = const {},
  });

  final List<int> years;
  final Map<String, String> teamIds;
  final Map<String, String> tournamentIds;

  factory ProfileMatchFilterOptions.fromMatches(List<MatchModel> matches) {
    final years = <int>{};
    final teams = <String, String>{};
    final tournaments = <String, String>{};

    for (final m in matches) {
      final date = m.completedAt ?? m.scheduledAt ?? m.startedAt;
      if (date != null) years.add(date.year);
      if (m.teamAId != null && m.teamAName.isNotEmpty) {
        teams[m.teamAId!] = m.teamAName;
      }
      if (m.teamBId != null && m.teamBName.isNotEmpty) {
        teams[m.teamBId!] = m.teamBName;
      }
      if (m.tournamentId != null && m.tournamentId!.isNotEmpty) {
        tournaments[m.tournamentId!] =
            m.title.contains(' — ') ? m.title.split(' — ').first : m.title;
      }
    }

    return ProfileMatchFilterOptions(
      years: years.toList()..sort((a, b) => b.compareTo(a)),
      teamIds: teams,
      tournamentIds: tournaments,
    );
  }
}
