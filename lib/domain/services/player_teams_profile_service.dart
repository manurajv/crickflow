import '../../core/utils/cricket_math.dart';
import '../../data/models/match_model.dart';
import '../../data/models/player_model.dart';
import '../../data/models/team_model.dart';
import '../../features/my_cricket/my_cricket_filters.dart';
import 'player_cricket_profile_models.dart';

class PlayerTeamsProfileService {
  const PlayerTeamsProfileService();

  List<PlayerTeamProfile> compute({
    required PlayerModel player,
    required List<TeamModel> teams,
    required List<MatchModel> completedMatches,
    String? authUid,
    Set<String> userTeamIds = const {},
  }) {
    final teamMap = {for (final t in teams) t.id: t};
    final profiles = <PlayerTeamProfile>[];

    for (final teamId in player.effectiveTeamIds) {
      final team = teamMap[teamId];
      if (team == null) continue;

      var matches = 0;
      var wins = 0;
      var losses = 0;
      var runs = 0;
      var wickets = 0;
      var balls = 0;
      var captainMatches = 0;
      DateTime? since;

      for (final match in completedMatches) {
        final isTeamA = match.teamAId == teamId;
        final isTeamB = match.teamBId == teamId;
        if (!isTeamA && !isTeamB) continue;

        if (!userParticipatedInMatch(
          match,
          uid: authUid,
          player: player,
          userTeamIds: userTeamIds,
        )) {
          continue;
        }

        matches += 1;
        final date = match.completedAt ?? match.scheduledAt;
        if (date != null && (since == null || date.isBefore(since))) {
          since = date;
        }

        if (match.winnerTeamId == teamId) {
          wins += 1;
        } else if (match.winnerTeamId != null) {
          losses += 1;
        }

        final setup = match.setup;
        if (setup != null &&
            (setup.teamACaptainId == player.id ||
                setup.teamBCaptainId == player.id)) {
          captainMatches += 1;
        }

        for (final inn in match.innings) {
          for (final b in inn.batsmen) {
            if (b.playerId != player.id) continue;
            runs += b.runs;
            balls += b.balls;
          }
          for (final bowler in inn.bowlers) {
            if (bowler.playerId != player.id) continue;
            wickets += bowler.wickets;
          }
        }
      }

      final role = _teamRole(team, player.id);
      profiles.add(
        PlayerTeamProfile(
          teamId: teamId,
          teamName: team.name,
          logoUrl: team.logoUrl,
          since: since ?? team.createdAt,
          matches: matches,
          wins: wins,
          losses: losses,
          runs: runs,
          wickets: wickets,
          captainMatches: captainMatches,
          teamRole: role,
          avgScore: matches == 0 ? 0 : runs / matches,
          strikeRate: CricketMath.strikeRate(runs, balls),
          winPct: matches == 0 ? 0 : (wins / matches) * 100,
        ),
      );
    }

    return profiles;
  }

  String _teamRole(TeamModel team, String playerId) {
    if (team.captainId == playerId) return 'Captain';
    if (team.viceCaptainId == playerId) return 'Vice Captain';
    if (team.createdBy == playerId) return 'Owner';
    return 'Player';
  }
}

enum PlayerTeamSort { recent, mostMatches, bestPerformance }

List<PlayerTeamProfile> sortTeamProfiles(
  List<PlayerTeamProfile> teams,
  PlayerTeamSort sort,
) {
  final list = List<PlayerTeamProfile>.from(teams);
  switch (sort) {
    case PlayerTeamSort.recent:
      list.sort((a, b) =>
          (b.since ?? DateTime(2000)).compareTo(a.since ?? DateTime(2000)));
    case PlayerTeamSort.mostMatches:
      list.sort((a, b) => b.matches.compareTo(a.matches));
    case PlayerTeamSort.bestPerformance:
      list.sort((a, b) {
        final aScore = a.winPct * 0.6 + a.strikeRate * 0.4;
        final bScore = b.winPct * 0.6 + b.strikeRate * 0.4;
        return bScore.compareTo(aScore);
      });
  }
  return list;
}
