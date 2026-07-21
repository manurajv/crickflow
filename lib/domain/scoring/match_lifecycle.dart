import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';
import 'match_completion_policy.dart';

/// Match status flow helpers (NOT_STARTED → TOSS → LIVE → BREAK → COMPLETED).
class MatchLifecycle {
  MatchLifecycle._();

  static bool isNotStarted(MatchModel match) =>
      match.status == MatchStatus.draft ||
      match.status == MatchStatus.scheduled;

  /// Pre-match hub — only Info + Squads until toss is done.
  static bool isUpcoming(MatchModel match) =>
      match.status == MatchStatus.draft ||
      match.status == MatchStatus.scheduled;

  static bool isTossCompleted(MatchModel match) =>
      match.status == MatchStatus.tossCompleted;

  static bool isLiveInnings(MatchModel match) =>
      match.status == MatchStatus.live;

  static bool isInningsBreak(MatchModel match) =>
      match.status == MatchStatus.inningsBreak;

  static bool isCompleted(MatchModel match) =>
      effectiveStatus(match) == MatchStatus.completed;

  /// True once any innings has progress (balls, score, or in-progress/completed).
  ///
  /// Used when [MatchStatus] lags behind reality (e.g. toss re-save left
  /// `tossCompleted` while balls were already scored).
  static bool hasScoringStarted(MatchModel match) {
    return match.innings.any(
      (i) =>
          i.legalBalls > 0 ||
          i.totalRuns > 0 ||
          i.totalWickets > 0 ||
          i.extras > 0 ||
          i.status == InningsStatus.inProgress ||
          i.status == InningsStatus.completed,
    );
  }

  /// Ready for the live scoring UI (real live/break, or scoring already underway).
  static bool canOpenScoringScreen(MatchModel match) {
    final status = effectiveStatus(match);
    return status == MatchStatus.live ||
        status == MatchStatus.inningsBreak ||
        hasScoringStarted(match);
  }

  /// Needs the start-innings lineup picker (toss done, no scoring yet).
  static bool needsStartInnings(MatchModel match) {
    return match.status == MatchStatus.tossCompleted && !hasScoringStarted(match);
  }

  /// Matches left at innings break after the final innings should read as completed.
  static MatchStatus effectiveStatus(MatchModel match) {
    if (match.status == MatchStatus.completed ||
        match.status == MatchStatus.abandoned) {
      return match.status;
    }
    if (match.status == MatchStatus.inningsBreak &&
        MatchCompletionPolicy.isMatchComplete(match)) {
      return MatchStatus.completed;
    }
    return match.status;
  }

  /// Live tab / live badge — includes post-toss matches awaiting first ball.
  static bool isEffectivelyLive(MatchModel match) {
    final status = effectiveStatus(match);
    return status == MatchStatus.live ||
        status == MatchStatus.inningsBreak ||
        status == MatchStatus.tossCompleted;
  }

  /// Live feed / audience — real live/break, or scored progress under a lagging status.
  static bool isActivelyLive(MatchModel match) {
    final status = effectiveStatus(match);
    return status == MatchStatus.live ||
        status == MatchStatus.inningsBreak ||
        (status == MatchStatus.tossCompleted && hasScoringStarted(match));
  }

  static bool needsFinalization(MatchModel match) =>
      match.status == MatchStatus.inningsBreak &&
      MatchCompletionPolicy.isMatchComplete(match);

  static bool canScore(MatchModel match) =>
      match.status == MatchStatus.live ||
      (match.status == MatchStatus.tossCompleted && hasScoringStarted(match));

  static bool canStartInnings(MatchModel match) =>
      match.status == MatchStatus.tossCompleted ||
      match.status == MatchStatus.inningsBreak ||
      match.status == MatchStatus.scheduled;

  static String statusLabel(MatchStatus status) => switch (status) {
        MatchStatus.draft => 'Draft',
        MatchStatus.scheduled => 'Upcoming',
        MatchStatus.tossCompleted => 'Live',
        MatchStatus.live => 'Live',
        MatchStatus.inningsBreak => 'Innings break',
        MatchStatus.completed => 'Completed',
        MatchStatus.abandoned => 'Abandoned',
      };

  static String upcomingBadgeLabel(MatchModel match) {
    if (!isUpcoming(match)) return statusLabel(match.status);
    if (match.scheduledAt != null &&
        match.scheduledAt!.isBefore(DateTime.now())) {
      return 'Yet to start';
    }
    return 'Upcoming';
  }
}
