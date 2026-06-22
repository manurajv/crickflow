import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/player_model.dart';
import '../../data/models/team_model.dart';
import '../../data/repositories/match_repository.dart';
import '../../features/my_cricket/my_cricket_filters.dart';
import 'captain_stats_service.dart';
import 'player_badge_catalog_service.dart';
import 'player_cluster_service.dart';
import 'player_cricket_profile_models.dart';
import 'player_teams_profile_service.dart';
import 'player_trophy_service.dart';

/// Aggregates all cricket profile data from match history (cached via Riverpod).
class PlayerCricketProfileService {
  PlayerCricketProfileService({
    this.clusterService = const PlayerClusterService(),
    this.captainService = const CaptainStatsService(),
    PlayerTrophyService? trophyService,
    this.badgeService = const PlayerBadgeCatalogService(),
    this.teamsService = const PlayerTeamsProfileService(),
  }) : trophyService = trophyService ?? PlayerTrophyService();

  final PlayerClusterService clusterService;
  final CaptainStatsService captainService;
  final PlayerTrophyService trophyService;
  final PlayerBadgeCatalogService badgeService;
  final PlayerTeamsProfileService teamsService;

  Future<PlayerCricketProfileSnapshot> build({
    required PlayerModel player,
    required List<MatchModel> allMatches,
    required List<TeamModel> teams,
    required MatchRepository matchRepo,
    String? authUid,
    Set<String> userTeamIds = const {},
  }) async {
    final participated = allMatches
        .where(
          (m) => userParticipatedInMatch(
            m,
            uid: authUid,
            player: player,
            userTeamIds: userTeamIds,
          ),
        )
        .toList();

    final completed = participated
        .where((m) => m.status == MatchStatus.completed)
        .toList();

    final ballEventsByMatch = await _fetchBallEventsForMatches(
      matchRepo,
      completed,
      maxMatches: 30,
    );

    final captainStats = captainService.compute(
      playerId: player.id,
      completedMatches: completed,
    );

    return PlayerCricketProfileSnapshot(
      player: player,
      clusters: clusterService.compute(
        playerId: player.id,
        completedMatches: completed,
        ballEventsByMatch: ballEventsByMatch,
      ),
      captainStats: captainStats,
      trophies: trophyService.compute(
        playerId: player.id,
        completedMatches: completed,
        ballEventsByMatch: ballEventsByMatch,
      ),
      badges: badgeService.evaluate(
        player: player,
        completedMatches: completed,
        captainStats: captainStats,
        ballEventsByMatch: ballEventsByMatch,
      ),
      teams: teamsService.compute(
        player: player,
        teams: teams,
        completedMatches: completed,
        authUid: authUid,
        userTeamIds: userTeamIds,
      ),
      participatedMatches: participated,
    );
  }

  Future<Map<String, List<BallEventModel>>> _fetchBallEventsForMatches(
    MatchRepository repo,
    List<MatchModel> matches, {
    int maxMatches = 30,
  }) async {
    final out = <String, List<BallEventModel>>{};
    final slice = matches.take(maxMatches).toList();
    for (final match in slice) {
      try {
        final events = await repo.getBallEvents(match.id);
        if (events.isNotEmpty) out[match.id] = events;
      } catch (_) {}
    }
    return out;
  }
}
