import '../../../core/constants/enums.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/tournament_model.dart';
import '../../scoring/match_lifecycle.dart';

/// Automatically resolves tournament status based on match progress.
///
/// Rules:
/// - **Upcoming**: No match has started (all scheduled/draft/not started).
/// - **Live (Ongoing)**: At least one match is live or completed, but not all
///   are finished.
/// - **Completed**: Every scheduled match has been completed (or abandoned)
///   AND a champion has been finalized.
///
/// Does NOT transition into [TournamentStatus.draft] or
/// [TournamentStatus.cancelled] — those are manual states.
class TournamentLifecycleService {
  const TournamentLifecycleService();

  /// Returns the computed status for the tournament given its matches.
  /// Returns `null` if no automatic transition should occur (e.g. draft or
  /// cancelled tournaments should not be auto-changed).
  TournamentStatus? computeStatus(
    TournamentModel tournament,
    List<MatchModel> matches,
  ) {
    // Never auto-transition these manual states.
    if (tournament.status == TournamentStatus.draft ||
        tournament.status == TournamentStatus.cancelled) {
      return null;
    }

    // Already completed and locked — no re-evaluation.
    if (tournament.status == TournamentStatus.completed &&
        tournament.isLocked) {
      return null;
    }

    if (matches.isEmpty) {
      // No matches — remain upcoming (or current status).
      return tournament.status == TournamentStatus.upcoming
          ? null
          : TournamentStatus.upcoming;
    }

    final hasLiveMatch = matches.any(_isLiveOrInProgress);
    final hasCompletedMatch = matches.any(_isFinished);
    final allFinished = matches.every(_isFinishedOrAbandoned);
    final hasChampion = tournament.championTeamId != null &&
        tournament.championTeamId!.isNotEmpty;

    // All matches are done AND champion declared → completed.
    if (allFinished && hasChampion) {
      if (tournament.status != TournamentStatus.completed) {
        return TournamentStatus.completed;
      }
      return null;
    }

    // At least one match started or finished → live/ongoing.
    if (hasLiveMatch || hasCompletedMatch) {
      if (tournament.status != TournamentStatus.live) {
        return TournamentStatus.live;
      }
      return null;
    }

    // No match has started → upcoming.
    if (tournament.status != TournamentStatus.upcoming) {
      return TournamentStatus.upcoming;
    }
    return null;
  }

  /// Whether the tournament should be considered lockable (all matches done).
  bool isReadyForCompletion(
    TournamentModel tournament,
    List<MatchModel> matches,
  ) {
    if (matches.isEmpty) return false;
    return matches.every(_isFinishedOrAbandoned);
  }

  bool _isLiveOrInProgress(MatchModel match) {
    return MatchLifecycle.isEffectivelyLive(match);
  }

  bool _isFinished(MatchModel match) {
    final status = MatchLifecycle.effectiveStatus(match);
    return status == MatchStatus.completed;
  }

  bool _isFinishedOrAbandoned(MatchModel match) {
    final status = MatchLifecycle.effectiveStatus(match);
    return status == MatchStatus.completed ||
        status == MatchStatus.abandoned;
  }
}
