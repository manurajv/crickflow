import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';
import 'match_lifecycle.dart';

/// Open matches (draft, scheduled, toss done, live, innings break) that were
/// never finished stop showing in Live / Upcoming lists once they are older
/// than [kStaleMatchAge].
///
/// Display rule only: the match document, its tournament fixture slot,
/// standings and stats are never changed. Completed and abandoned matches are
/// never stale. See docs/STALE_MATCHES.md.
const Duration kStaleMatchAge = Duration(days: 30);

/// When the match was last meant to be played: the later of its scheduled
/// start and its actual start, falling back to when it was created.
DateTime? matchStaleAnchor(MatchModel match) {
  final scheduled = match.scheduledAt;
  final started = match.startedAt;
  if (scheduled != null && started != null) {
    return scheduled.isAfter(started) ? scheduled : started;
  }
  return scheduled ?? started ?? match.createdAt;
}

/// True for an unfinished match whose anchor is more than 30 days ago.
bool isStaleUnfinishedMatch(MatchModel match, {DateTime? now}) {
  final status = MatchLifecycle.effectiveStatus(match);
  if (status == MatchStatus.completed || status == MatchStatus.abandoned) {
    return false;
  }
  final anchor = matchStaleAnchor(match);
  if (anchor == null) return false;
  final at = now ?? DateTime.now();
  return at.difference(anchor) > kStaleMatchAge;
}

/// Belongs in a Live list (live, break, or toss done) and is not stale.
bool isListedLive(MatchModel match, {DateTime? now}) =>
    MatchLifecycle.isEffectivelyLive(match) &&
    !isStaleUnfinishedMatch(match, now: now);

/// Belongs in an Upcoming list (draft / scheduled) and is not stale.
bool isListedUpcoming(MatchModel match, {DateTime? now}) =>
    MatchLifecycle.isUpcoming(match) &&
    !isStaleUnfinishedMatch(match, now: now);
