import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';
import '../../data/models/overlay_state_model.dart';
import '../services/scoring_engine.dart';

/// Rebuilds the live overlay (`matches/{id}/overlay/current`) for match-level
/// updates such as ending an innings, starting the chase or super over, or
/// completing the match.
///
/// Ball commits already refresh the overlay; innings transitions did not, so
/// live viewers kept the 1st-innings scorebug until the first chase ball.
abstract final class InningsTransitionOverlay {
  static const _scoringStatuses = {
    MatchStatus.live,
    MatchStatus.inningsBreak,
    MatchStatus.completed,
  };

  /// Overlay for [match], or null when the match is not in a scoring state.
  static OverlayStateModel? build(ScoringEngine engine, MatchModel match) {
    if (!_scoringStatuses.contains(match.status)) return null;
    if (match.innings.isEmpty || match.currentInnings == null) return null;
    try {
      return engine.buildOverlayForMatch(match);
    } catch (_) {
      return null;
    }
  }
}
