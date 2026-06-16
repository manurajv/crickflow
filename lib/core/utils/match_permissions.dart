import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';

/// Effective active scorer — falls back for matches created before ownership fields.
String? effectiveScorerId(MatchModel match) {
  final id = match.currentScorerId;
  if (id != null && id.isNotEmpty) return id;
  if (match.createdBy != null && match.createdBy!.isNotEmpty) {
    return match.createdBy;
  }
  if (match.scorerIds.isNotEmpty) return match.scorerIds.first;
  return null;
}

bool isActiveScorer({
  required MatchModel match,
  required String? userId,
}) {
  if (userId == null) return false;
  return effectiveScorerId(match) == userId;
}

/// Who can score, stream, or complete a match.
/// All signed-in users except [UserRole.viewer] may organize and score.
bool canManageMatch({
  required MatchModel match,
  required String? userId,
  required UserRole role,
}) {
  if (userId == null || role == UserRole.viewer) return false;
  if (match.createdBy == userId) return true;
  if (match.scorerIds.contains(userId)) return true;
  return role != UserRole.viewer;
}

/// Only the active scorer may enter balls, undo, or change match state.
bool canScoreMatch({
  required MatchModel match,
  required String? userId,
  required UserRole role,
}) {
  if (userId == null || role == UserRole.viewer) return false;
  return isActiveScorer(match: match, userId: userId);
}

/// Read-only live scoring for organizers/scorers who lost active ownership.
bool canViewLiveScoring({
  required MatchModel match,
  required String? userId,
  required UserRole role,
}) {
  return canManageMatch(match: match, userId: userId, role: role);
}

bool canInitiateScorerTransfer({
  required MatchModel match,
  required String? userId,
}) {
  return isActiveScorer(match: match, userId: userId);
}

/// Viewer is read-only; everyone else (including players) can create matches.
/// Guests and incomplete onboarding users are blocked from write actions.
bool canCreateMatches(UserRole role, {bool isGuest = false, bool onboardingComplete = true}) {
  if (isGuest || !onboardingComplete) return false;
  return role != UserRole.viewer;
}

String homeRouteForRole(UserRole role) => '/home';
