import 'package:flutter/foundation.dart';

import '../../data/models/ball_event_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import 'ball_event_aggregator.dart';

/// Debug-only verification that Firestore innings projection matches event replay.
class ScoringIntegrityCheck {
  ScoringIntegrityCheck._();

  /// Returns human-readable mismatch descriptions (empty = OK).
  static List<String> verify({
    required MatchModel match,
    required List<BallEventModel> allEvents,
  }) {
    final issues = <String>[];
    final aggregator = BallEventAggregator();

    for (final cached in match.innings) {
      final events = BallEventAggregator.eventsForInnings(
        allEvents,
        cached.inningsNumber,
      );
      if (events.isEmpty) continue;

      final derived = aggregator.projectInnings(
        match: match,
        lineupInnings: cached,
        allEvents: allEvents,
      );
      final replayed = derived.innings;

      _compareInt(
        issues,
        'inn${cached.inningsNumber}.totalRuns',
        cached.totalRuns,
        replayed.totalRuns,
      );
      _compareInt(
        issues,
        'inn${cached.inningsNumber}.totalWickets',
        cached.totalWickets,
        replayed.totalWickets,
      );
      _compareInt(
        issues,
        'inn${cached.inningsNumber}.legalBalls',
        cached.legalBalls,
        replayed.legalBalls,
      );
      _compareInt(
        issues,
        'inn${cached.inningsNumber}.extras',
        cached.extras,
        replayed.extras,
      );
      _compareString(
        issues,
        'inn${cached.inningsNumber}.strikerId',
        cached.strikerId,
        replayed.strikerId,
      );
      _compareString(
        issues,
        'inn${cached.inningsNumber}.nonStrikerId',
        cached.nonStrikerId,
        replayed.nonStrikerId,
      );
      _compareBatsmen(issues, cached.inningsNumber, cached, replayed);
      _compareBowlers(issues, cached.inningsNumber, cached, replayed);
    }
    return issues;
  }

  /// Logs mismatches in debug builds; no-op in release.
  static void assertProjectionMatchesEvents({
    required MatchModel match,
    required List<BallEventModel> allEvents,
    String context = 'scoring',
  }) {
    if (!kDebugMode) return;
    final issues = verify(match: match, allEvents: allEvents);
    if (issues.isEmpty) return;
    debugPrint(
      'ScoringIntegrityCheck [$context]: ${issues.length} mismatch(es)',
    );
    for (final issue in issues) {
      debugPrint('  • $issue');
    }
    assert(
      issues.isEmpty,
      'Innings projection diverged from ball_events replay ($context)',
    );
  }

  static void _compareInt(
    List<String> issues,
    String label,
    int cached,
    int replayed,
  ) {
    if (cached != replayed) {
      issues.add('$label: cache=$cached replay=$replayed');
    }
  }

  static void _compareString(
    List<String> issues,
    String label,
    String? cached,
    String? replayed,
  ) {
    if (cached != replayed) {
      issues.add('$label: cache=$cached replay=$replayed');
    }
  }

  static void _compareBatsmen(
    List<String> issues,
    int innNo,
    InningsModel cached,
    InningsModel replayed,
  ) {
    final replayedById = {for (final b in replayed.batsmen) b.playerId: b};
    for (final b in cached.batsmen) {
      final r = replayedById[b.playerId];
      if (r == null) continue;
      if (b.runs != r.runs ||
          b.balls != r.balls ||
          b.fours != r.fours ||
          b.sixes != r.sixes ||
          b.isOut != r.isOut) {
        issues.add(
          'inn$innNo.batsman.${b.playerId}: '
          'cache=${b.runs}/${b.balls} out=${b.isOut} '
          'replay=${r.runs}/${r.balls} out=${r.isOut}',
        );
      }
    }
  }

  static void _compareBowlers(
    List<String> issues,
    int innNo,
    InningsModel cached,
    InningsModel replayed,
  ) {
    final replayedById = {for (final b in replayed.bowlers) b.playerId: b};
    for (final b in cached.bowlers) {
      final r = replayedById[b.playerId];
      if (r == null) continue;
      if (b.oversBowledBalls != r.oversBowledBalls ||
          b.runsConceded != r.runsConceded ||
          b.wickets != r.wickets) {
        issues.add(
          'inn$innNo.bowler.${b.playerId}: '
          'cache=${b.oversBowledBalls}b/${b.runsConceded}r/${b.wickets}w '
          'replay=${r.oversBowledBalls}b/${r.runsConceded}r/${r.wickets}w',
        );
      }
    }
  }
}
