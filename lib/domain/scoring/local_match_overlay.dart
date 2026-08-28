import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';
import 'match_completion_policy.dart';

/// Chooses a local Hive snapshot over a stale remote live document.
class LocalMatchOverlay {
  LocalMatchOverlay._();

  /// Local finished the match; remote still says live/break/toss.
  static bool isTerminalAhead(MatchModel local, MatchModel remote) {
    if (remote.status == MatchStatus.completed ||
        remote.status == MatchStatus.abandoned) {
      return false;
    }
    if (local.status == MatchStatus.completed ||
        local.status == MatchStatus.abandoned) {
      return true;
    }
    final remoteActive = remote.status == MatchStatus.live ||
        remote.status == MatchStatus.inningsBreak ||
        remote.status == MatchStatus.tossCompleted;
    return remoteActive && MatchCompletionPolicy.isMatchComplete(local);
  }

  static bool preferLocal({
    required MatchModel local,
    required MatchModel remote,
    required bool pendingSync,
  }) {
    if (pendingSync) return true;
    return isTerminalAhead(local, remote);
  }
}
