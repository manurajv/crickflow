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
  ///
  /// Also true for 2nd+ innings that were created but still need openers /
  /// opening bowler (same full-screen flow as the start of the match).
  static bool needsStartInnings(MatchModel match) {
    if (match.status == MatchStatus.tossCompleted && !hasScoringStarted(match)) {
      return true;
    }
    final status = effectiveStatus(match);
    if (status != MatchStatus.live && status != MatchStatus.inningsBreak) {
      return false;
    }
    return currentInningsNeedsOpeningLineup(match);
  }

  /// Current innings exists but openers / bowler are not set yet (no balls).
  static bool currentInningsNeedsOpeningLineup(MatchModel match) {
    final inn = match.currentInnings;
    if (inn == null) return false;
    if (inn.status == InningsStatus.completed) return false;
    final missingCrease = inn.strikerId == null ||
        inn.strikerId!.isEmpty ||
        inn.nonStrikerId == null ||
        inn.nonStrikerId!.isEmpty ||
        inn.currentBowlerId == null ||
        inn.currentBowlerId!.isEmpty;
    if (!missingCrease) return false;
    // Mid-innings vacant crease still has balls — not the opening picker.
    if (inn.legalBalls > 0 ||
        inn.totalRuns > 0 ||
        inn.totalWickets > 0 ||
        inn.extras > 0) {
      return false;
    }
    return inn.status == InningsStatus.notStarted ||
        inn.status == InningsStatus.inProgress;
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
