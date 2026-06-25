import '../constants/enums.dart';
import '../../data/models/match_model.dart';
import '../../data/models/tournament/tournament_official_model.dart';
import '../../data/models/tournament_model.dart';
import 'match_permissions.dart';

/// Active tournament official listed as a scorer (Officials tab).
bool isActiveTournamentScorerOfficial({
  required Iterable<TournamentOfficialModel> officials,
  required String? userId,
}) {
  if (userId == null || userId.isEmpty) return false;
  return officials.any(
    (o) =>
        o.isActive &&
        o.role == TournamentOfficialRole.scorer &&
        o.userId == userId,
  );
}

bool isTournamentOrganizerUser({
  required TournamentModel? tournament,
  required String? userId,
}) {
  if (userId == null || userId.isEmpty || tournament == null) return false;
  return tournament.effectiveOrganizerId == userId;
}

/// May open Live Score / match setup for a tournament fixture (not full manage).
bool canStartTournamentMatchScoring({
  required MatchModel match,
  required String? userId,
  required UserRole role,
  TournamentModel? tournament,
  Iterable<TournamentOfficialModel> officials = const [],
}) {
  if (userId == null || role == UserRole.viewer) return false;
  if (!match.isTournamentMatch) {
    return canManageMatch(match: match, userId: userId, role: role);
  }

  if (canManageMatch(match: match, userId: userId, role: role)) return true;
  if (isTournamentOrganizerUser(tournament: tournament, userId: userId)) {
    return true;
  }
  return isActiveTournamentScorerOfficial(officials: officials, userId: userId);
}

/// May record balls — assigned match scorer, organizer, or tournament scorer official.
bool canScoreTournamentMatch({
  required MatchModel match,
  required String? userId,
  required UserRole role,
  TournamentModel? tournament,
  Iterable<TournamentOfficialModel> officials = const [],
}) {
  if (canScoreMatch(match: match, userId: userId, role: role)) return true;
  if (!match.isTournamentMatch) return false;
  if (isTournamentOrganizerUser(tournament: tournament, userId: userId)) {
    return true;
  }
  return isActiveTournamentScorerOfficial(officials: officials, userId: userId);
}

/// Organizer and tournament scorer officials land on setup when starting a fixture.
bool shouldForceTournamentSetupStep({
  required MatchModel match,
  required String? userId,
  TournamentModel? tournament,
  Iterable<TournamentOfficialModel> officials = const [],
}) {
  if (!match.isTournamentMatch) return false;
  if (isTournamentOrganizerUser(tournament: tournament, userId: userId)) {
    return true;
  }
  return isActiveTournamentScorerOfficial(officials: officials, userId: userId);
}
