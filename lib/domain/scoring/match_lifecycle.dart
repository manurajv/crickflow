import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';

/// Match status flow helpers (NOT_STARTED → TOSS → LIVE → BREAK → COMPLETED).
class MatchLifecycle {
  MatchLifecycle._();

  static bool isNotStarted(MatchModel match) =>
      match.status == MatchStatus.draft ||
      match.status == MatchStatus.scheduled;

  /// Pre-match hub — only Info + Squads until scorer starts the match.
  static bool isUpcoming(MatchModel match) =>
      match.status == MatchStatus.draft ||
      match.status == MatchStatus.scheduled ||
      match.status == MatchStatus.tossCompleted;

  static bool isTossCompleted(MatchModel match) =>
      match.status == MatchStatus.tossCompleted;

  static bool isLiveInnings(MatchModel match) =>
      match.status == MatchStatus.live;

  static bool isInningsBreak(MatchModel match) =>
      match.status == MatchStatus.inningsBreak;

  static bool isCompleted(MatchModel match) =>
      match.status == MatchStatus.completed;

  static bool canScore(MatchModel match) =>
      match.status == MatchStatus.live;

  static bool canStartInnings(MatchModel match) =>
      match.status == MatchStatus.tossCompleted ||
      match.status == MatchStatus.inningsBreak ||
      match.status == MatchStatus.scheduled;

  static String statusLabel(MatchStatus status) => switch (status) {
        MatchStatus.draft => 'Draft',
        MatchStatus.scheduled => 'Upcoming',
        MatchStatus.tossCompleted => 'Upcoming',
        MatchStatus.live => 'Live',
        MatchStatus.inningsBreak => 'Innings break',
        MatchStatus.completed => 'Completed',
        MatchStatus.abandoned => 'Abandoned',
      };

  static String upcomingBadgeLabel(MatchModel match) {
    if (!isUpcoming(match)) return statusLabel(match.status);
    if (match.status == MatchStatus.tossCompleted) return 'Toss done';
    if (match.scheduledAt != null &&
        match.scheduledAt!.isBefore(DateTime.now())) {
      return 'Yet to start';
    }
    return 'Upcoming';
  }
}
