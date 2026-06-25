import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../core/utils/match_permissions.dart';
import '../../core/utils/tournament_match_permissions.dart';
import '../../data/models/match_model.dart';
import '../../data/models/tournament/tournament_official_model.dart';
import '../../data/models/tournament_model.dart';
import 'providers.dart';
import 'tournament_providers.dart';

class TournamentMatchScoringAccess {
  const TournamentMatchScoringAccess({
    this.canStartSetup = false,
    this.canScoreLive = false,
    this.canManageMatch = false,
    this.forceSetupStep = false,
  });

  static const none = TournamentMatchScoringAccess();

  final bool canStartSetup;
  final bool canScoreLive;
  final bool canManageMatch;
  final bool forceSetupStep;
}

TournamentMatchScoringAccess resolveTournamentMatchScoringAccess({
  required MatchModel? match,
  required String? userId,
  required UserRole role,
  TournamentModel? tournament,
  Iterable<TournamentOfficialModel> officials = const [],
}) {
  if (match == null || userId == null) return TournamentMatchScoringAccess.none;

  final activeOfficials = officials.where((o) => o.isActive);
  final canManage = canManageMatch(match: match, userId: userId, role: role);

  if (!match.isTournamentMatch) {
    final canScore = canScoreMatch(match: match, userId: userId, role: role);
    return TournamentMatchScoringAccess(
      canStartSetup: canManage,
      canScoreLive: canScore,
      canManageMatch: canManage,
    );
  }

  final canStart = canStartTournamentMatchScoring(
    match: match,
    userId: userId,
    role: role,
    tournament: tournament,
    officials: activeOfficials,
  );
  final canScore = canScoreTournamentMatch(
    match: match,
    userId: userId,
    role: role,
    tournament: tournament,
    officials: activeOfficials,
  );

  return TournamentMatchScoringAccess(
    canStartSetup: canStart,
    canScoreLive: canScore,
    canManageMatch: canManage,
    forceSetupStep: shouldForceTournamentSetupStep(
      match: match,
      userId: userId,
      tournament: tournament,
      officials: activeOfficials,
    ),
  );
}

final tournamentMatchScoringAccessProvider = Provider.family<
    TournamentMatchScoringAccess,
    ({String matchId, String? userId})>((ref, params) {
  final match = ref.watch(matchProvider(params.matchId)).valueOrNull;
  final uid = params.userId;
  final role =
      ref.watch(currentUserProfileProvider).valueOrNull?.role ?? UserRole.organizer;

  if (match == null || uid == null) return TournamentMatchScoringAccess.none;

  final tournamentId = match.tournamentId;
  final tournament = tournamentId != null && tournamentId.isNotEmpty
      ? ref.watch(tournamentProvider(tournamentId)).valueOrNull
      : null;
  final officials = tournamentId != null && tournamentId.isNotEmpty
      ? ref.watch(tournamentOfficialsProvider(tournamentId)).valueOrNull ?? []
      : const <TournamentOfficialModel>[];

  return resolveTournamentMatchScoringAccess(
    match: match,
    userId: uid,
    role: role,
    tournament: tournament,
    officials: officials,
  );
});
