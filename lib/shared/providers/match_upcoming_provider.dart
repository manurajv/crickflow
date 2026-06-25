import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/match_model.dart';
import '../../data/models/player_model.dart';
import '../../data/models/team_model.dart';
import '../../domain/services/match_upcoming_models.dart';
import '../../domain/services/match_upcoming_service.dart';
import 'match_info_provider.dart';
import 'match_squads_provider.dart';
import 'providers.dart';
import 'tournament_match_providers.dart';

final matchUpcomingServiceProvider = Provider((ref) => MatchUpcomingService());

final headToHeadMatchesProvider =
    FutureProvider.family<List<MatchModel>, String>((ref, matchId) async {
  final match = await ref.watch(matchProvider(matchId).future);
  if (match == null) return const [];
  final teamAId = match.teamAId;
  final teamBId = match.teamBId;
  if (teamAId == null ||
      teamBId == null ||
      teamAId.isEmpty ||
      teamBId.isEmpty) {
    return const [];
  }
  return ref.read(matchRepositoryProvider).fetchHeadToHeadMatches(
        teamAId: teamAId,
        teamBId: teamBId,
      );
});

final matchUpcomingProvider =
    FutureProvider.family<UpcomingMatchSnapshot, String>((ref, matchId) async {
  final match = await ref.watch(matchProvider(matchId).future);
  if (match == null) return UpcomingMatchSnapshot.empty;

  final history = await ref.watch(headToHeadMatchesProvider(matchId).future);

  TeamModel? teamA;
  TeamModel? teamB;
  final teamRepo = ref.read(teamRepositoryProvider);
  if (match.teamAId != null && match.teamAId!.isNotEmpty) {
    teamA = await teamRepo.getTeam(match.teamAId!);
  }
  if (match.teamBId != null && match.teamBId!.isNotEmpty) {
    teamB = await teamRepo.getTeam(match.teamBId!);
  }

  String? tournamentName;
  String? tournamentRoundName;
  String? tournamentGroupName;
  final tournamentId = match.tournamentId;
  if (tournamentId != null && tournamentId.isNotEmpty) {
    tournamentName =
        ref.read(matchInfoTournamentNameProvider(tournamentId)).valueOrNull;
    if (match.roundName?.trim().isNotEmpty == true) {
      tournamentRoundName = match.roundName!.trim();
    } else if (match.roundId != null && match.roundId!.isNotEmpty) {
      tournamentRoundName = ref
          .read(
            tournamentRoundByIdProvider(
              (tournamentId: tournamentId, roundId: match.roundId),
            ),
          )
          ?.name;
    }
    if (match.groupId != null && match.groupId!.isNotEmpty) {
      tournamentGroupName = ref
          .read(
            tournamentGroupByIdProvider(
              (tournamentId: tournamentId, groupId: match.groupId),
            ),
          )
          ?.name;
    }
  }

  final squads = await ref.watch(matchDualSquadsProvider(matchId).future);
  final squadPlayers = [
    ...squads.teamA.playing,
    ...squads.teamB.playing,
  ];

  final playerRepo = ref.read(playerRepositoryProvider);
  final milestonePlayers = <PlayerModel>[];
  for (final snap in squadPlayers) {
    final player = await playerRepo.getPlayer(snap.id);
    if (player != null) milestonePlayers.add(player);
  }

  return ref.read(matchUpcomingServiceProvider).build(
        match: match,
        headToHeadHistory: history,
        teamA: teamA,
        teamB: teamB,
        tournamentName: tournamentName,
        tournamentRoundName: tournamentRoundName,
        tournamentGroupName: tournamentGroupName,
        squadPlayers: squadPlayers,
        milestonePlayers: milestonePlayers,
      );
});
