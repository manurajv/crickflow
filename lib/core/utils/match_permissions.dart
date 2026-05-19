import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';

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

/// Viewer is read-only; everyone else (including players) can create matches.
bool canCreateMatches(UserRole role) => role != UserRole.viewer;

String homeRouteForRole(UserRole role) => '/home';
