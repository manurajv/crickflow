import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';
import 'match_scorer_utils.dart';

/// Effective active scorer — falls back for matches created before ownership fields.
String? effectiveScorerId(MatchModel match) {
  final id = match.currentScorerId;
  if (id != null && id.isNotEmpty) return id;
  if (match.scorer1UserId != null && match.scorer1UserId!.isNotEmpty) {
    return match.scorer1UserId;
  }
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

/// Who can manage match settings (legacy — creator or listed scorers).
bool canManageMatch({
  required MatchModel match,
  required String? userId,
  required UserRole role,
}) {
  if (userId == null || role == UserRole.viewer) return false;
  if (isAssignedMatchScorer(match: match, userId: userId)) return true;
  if (match.createdBy == userId) return true;
  return false;
}

/// Assigned Scorer 1 or Scorer 2 may enter balls, undo, and change match state.
bool canScoreMatch({
  required MatchModel match,
  required String? userId,
  required UserRole role,
}) {
  if (userId == null || role == UserRole.viewer) return false;
  return isAssignedMatchScorer(match: match, userId: userId);
}

/// Any signed-in user can open live scoring; non-scorers get read-only view.
bool canViewLiveScoring({
  required MatchModel match,
  required String? userId,
  required UserRole role,
}) {
  if (userId == null || role == UserRole.viewer) return false;
  return true;
}

bool canInitiateScorerTransfer({
  required MatchModel match,
  required String? userId,
}) {
  return isAssignedMatchScorer(match: match, userId: userId);
}

/// Viewer is read-only; everyone else (including players) can create matches.
/// Guests and incomplete onboarding users are blocked from write actions.
bool canCreateMatches(UserRole role, {bool isGuest = false, bool onboardingComplete = true}) {
  if (isGuest || !onboardingComplete) return false;
  return role != UserRole.viewer;
}

String homeRouteForRole(UserRole role) => '/home';
