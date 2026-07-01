import '../../../core/constants/enums.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/match_setup_draft_models.dart';

/// Validates who may start a live stream for a match.
class StreamPermissionService {
  const StreamPermissionService();

  bool canStartStream({
    required MatchModel match,
    required String? userId,
    required UserRole role,
    bool isTournamentOrganizer = false,
  }) {
    if (userId == null || role == UserRole.viewer) return false;
    if (match.createdBy == userId) return true;
    if (isTournamentOrganizer) return true;
    if (_isAssignedStreamer(match, userId)) return true;
    if (match.scorerIds.contains(userId)) return true;
    if (match.scorer1UserId == userId || match.scorer2UserId == userId) {
      return true;
    }
    return false;
  }

  bool _isAssignedStreamer(MatchModel match, String userId) {
    final streamers = match.setup?.liveStreamers ?? const [];
    for (final official in streamers) {
      if (_officialMatchesUser(official, userId)) return true;
    }
    return false;
  }

  bool _officialMatchesUser(MatchOfficialEntry official, String userId) {
    if (official.userId == userId) return true;
    return false;
  }
}
