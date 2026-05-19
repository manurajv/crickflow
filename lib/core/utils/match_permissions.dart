import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';

/// Who can score, stream, or complete a match.
bool canManageMatch({
  required MatchModel match,
  required String? userId,
  required UserRole role,
}) {
  if (userId == null) return false;
  if (role == UserRole.viewer || role == UserRole.player) return false;
  if (role == UserRole.organizer || role == UserRole.scorer || role == UserRole.umpire) {
    if (match.createdBy == userId) return true;
    if (match.scorerIds.contains(userId)) return true;
    return role == UserRole.organizer || role == UserRole.scorer;
  }
  return false;
}

bool canCreateMatches(UserRole role) =>
    role == UserRole.organizer ||
    role == UserRole.scorer ||
    role == UserRole.umpire;

String homeRouteForRole(UserRole role) {
  switch (role) {
    case UserRole.player:
      return '/players';
    default:
      return '/home';
  }
}
