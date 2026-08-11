import '../../core/constants/enums.dart';
import '../../core/utils/cricket_math.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_rules_model.dart';
import '../services/dismissal_formatter.dart';
import '../services/scorecard_display_service.dart';
import '../services/scoring_engine.dart';
import '../../features/scoring/presentation/utils/scoring_display_utils.dart';

/// Pure derivation of innings statistics from the ball event log.
///
/// [InningsModel] on the match document is a projection cache; this service
/// recomputes display stats from events whenever the log is available.
class BallEventAggregator {
  BallEventAggregator({ScoringEngine? engine})
      : _engine = engine ?? ScoringEngine();

  final ScoringEngine _engine;

  /// Events for one innings, sorted by [BallEventModel.sequence].
  static List<BallEventModel> eventsForInnings(
    List<BallEventModel> all,
    int inningsNumber,
  ) {
    return all
        .where((e) => e.inningsNumber == inningsNumber)
        .toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
  }

  /// Merges local and remote ball logs by event id (union). Local entries win on
  /// duplicate ids so unsynced scoring is preserved while remote-only events
  /// from other devices are not dropped.
  static List<BallEventModel> mergeEventLogs(
    List<BallEventModel> local,
    List<BallEventModel> remote,
  ) {
    if (remote.isEmpty) return List<BallEventModel>.from(local);
    if (local.isEmpty) return List<BallEventModel>.from(remote);

    final byId = <String, BallEventModel>{};
    for (final e in remote) {
      byId[e.id] = e;
    }
    for (final e in local) {
      byId[e.id] = e;
    }
    return byId.values.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
  }

  /// Replays all innings in [match] from [events] (projection cache repair).
  static MatchModel reprojectMatchFromEvents(
    MatchModel match,
    List<BallEventModel> events, {
    ScoringEngine? engine,
  }) {
    if (events.isEmpty) return match;

    final scorer = engine ?? ScoringEngine();
    final aggregator = BallEventAggregator(engine: scorer);
    final innings = match.innings.map((lineupInnings) {
      final innEvents = eventsForInnings(events, lineupInnings.inningsNumber);
      if (innEvents.isEmpty) return lineupInnings;
      return aggregator
          .projectInnings(
            match: match,
            lineupInnings: lineupInnings,
            allEvents: events,
          )
          .innings;
    }).toList();

    return match.copyWith(innings: innings);
  }

  /// Full derived projection for scorecard, insights, and analytics.
  InningsDerivedProjection projectInnings({
    required MatchModel match,
    required InningsModel lineupInnings,
    required List<BallEventModel> allEvents,
    DateTime? now,
  }) {
    final rules = match.rules;
    final events = eventsForInnings(allEvents, lineupInnings.inningsNumber);
    final replayed = _replay(match, lineupInnings, events);
    final extras = ScorecardDisplayService.extrasBreakdown(
      innings: replayed,
      events: events,
      rules: rules,
    );
    final names = _playerNames(replayed);
    final fallOfWickets = fallOfWicketsFromEvents(events, names);
    final partnerships = partnershipsFromEvents(events, names);
    final fielders = fieldersFromEvents(events);

    return InningsDerivedProjection(
      innings: _attachDerivedLists(
        replayed,
        fallOfWickets: fallOfWickets,
        partnerships: partnerships,
        fielders: fielders,
      ),
      events: events,
      extrasBreakdown: extras,
      fallOfWickets: fallOfWickets,
      partnerships: partnerships,
      fielders: fielders,
      batterMinutes: batterMinutesFromEvents(
        events,
        creaseIds: {
          if (replayed.strikerId != null) replayed.strikerId!,
          if (replayed.nonStrikerId != null) replayed.nonStrikerId!,
        },
        now: now ?? DateTime.now(),
      ),
      bowlerMaidens: maidenOversFromEvents(events, rules),
    );
  }

  static Map<String, String> _playerNames(InningsModel innings) {
    final names = <String, String>{};
    for (final b in innings.batsmen) {
      if (b.playerId.isNotEmpty) {
        names[b.playerId] = b.playerName;
      }
    }
    for (final b in innings.bowlers) {
      if (b.playerId.isNotEmpty) {
        names[b.playerId] = b.playerName;
      }
    }
    return names;
  }

  static InningsModel _attachDerivedLists(
    InningsModel innings, {
    required List<FallOfWicketRecord> fallOfWickets,
    required List<PartnershipRecord> partnerships,
    required List<FielderInningsModel> fielders,
  }) {
    return InningsModel(
      inningsNumber: innings.inningsNumber,
      battingTeamId: innings.battingTeamId,
      bowlingTeamId: innings.bowlingTeamId,
      status: innings.status,
      totalRuns: innings.totalRuns,
      totalWickets: innings.totalWickets,
      legalBalls: innings.legalBalls,
      extras: innings.extras,
      strikerId: innings.strikerId,
      nonStrikerId: innings.nonStrikerId,
      currentBowlerId: innings.currentBowlerId,
      batsmen: innings.batsmen,
      bowlers: innings.bowlers,
      partnershipRuns: innings.partnershipRuns,
      partnershipBalls: innings.partnershipBalls,
      isFreeHitActive: innings.isFreeHitActive,
      targetRuns: innings.targetRuns,
      isSuperOver: innings.isSuperOver,
      currentOverStartLegalBalls: innings.currentOverStartLegalBalls,
      currentOverNumber: innings.currentOverNumber,
      currentOverSegment: innings.currentOverSegment,
      currentSegmentStartLegalBalls: innings.currentSegmentStartLegalBalls,
      partnerships: partnerships,
      fallOfWickets: fallOfWickets,
      fielders: fielders,
    );
  }

  /// Fall-of-wicket lines from wicket events and running score.
  /// Retired Hurt is excluded; Retired Out is included.
  static List<FallOfWicketRecord> fallOfWicketsFromEvents(
    List<BallEventModel> events,
    Map<String, String> playerNames,
  ) {
    var totalRuns = 0;
    var legalBalls = 0;
    var wickets = 0;
    final result = <FallOfWicketRecord>[];

    for (final e in events) {
      totalRuns += e.runs;
      if (e.isLegalDelivery) legalBalls++;

      if (!DismissalFormatter.eventCountsAsWicket(e)) continue;

      wickets++;
      final dismissed = e.dismissedPlayerId ?? e.strikerId;
      if (dismissed == null || dismissed.isEmpty) continue;

      result.add(
        FallOfWicketRecord(
          wicketNumber: wickets,
          batsmanId: dismissed,
          batsmanName: playerNames[dismissed] ?? '',
          teamScore: totalRuns,
          legalBalls: legalBalls,
          dismissal: DismissalFormatter.fromWicketEvent(
            e,
            playerNames: playerNames,
          ),
        ),
      );
    }
    return result;
  }

  /// Closed partnerships between real wickets.
  ///
  /// Retired Hurt does **not** close a partnership: runs/balls keep accumulating
  /// until a true wicket (including Retired Out). Pair names come from the
  /// crease snapshot on the closing wicket (current partners at that moment).
  static List<PartnershipRecord> partnershipsFromEvents(
    List<BallEventModel> events,
    Map<String, String> playerNames,
  ) {
    String? aId;
    String? bId;
    var runs = 0;
    var balls = 0;
    final result = <PartnershipRecord>[];

    void setCrease(String? striker, String? nonStriker) {
      if (striker != null &&
          striker.isNotEmpty &&
          nonStriker != null &&
          nonStriker.isNotEmpty &&
          striker != nonStriker) {
        aId = striker;
        bId = nonStriker;
        return;
      }
      // After RH one crease slot may be empty until lineup/replacement.
      if (striker != null && striker.isNotEmpty) {
        if (aId == null || aId == striker || bId == striker) {
          aId ??= striker;
        } else if (bId == null) {
          bId = striker;
        } else {
          // New batter replacing a vacant/retired slot — keep the survivor.
          if (aId != null && bId == null) {
            bId = striker;
          } else if (bId != null && aId == null) {
            aId = striker;
          }
        }
      }
      if (nonStriker != null && nonStriker.isNotEmpty) {
        if (bId == null && nonStriker != aId) {
          bId = nonStriker;
        } else if (aId == null && nonStriker != bId) {
          aId = nonStriker;
        }
      }
    }

    for (final e in events) {
      if (e.eventType == BallEventType.lineupChange ||
          e.eventType == BallEventType.batterSwap) {
        setCrease(e.strikerId, e.nonStrikerId);
        continue;
      }

      runs += e.runs;
      if (e.isLegalDelivery) balls++;
      setCrease(e.strikerId, e.nonStrikerId);

      if (DismissalFormatter.isRetiredHurtEvent(e)) {
        final retired = e.dismissedPlayerId ?? e.strikerId;
        if (retired != null && retired.isNotEmpty) {
          if (retired == aId) aId = null;
          if (retired == bId) bId = null;
        }
        continue;
      }

      if (!DismissalFormatter.eventCountsAsWicket(e)) continue;

      final left = e.strikerId ?? aId;
      final right = e.nonStrikerId ?? bId;
      if ((runs > 0 || balls > 0) &&
          left != null &&
          left.isNotEmpty &&
          right != null &&
          right.isNotEmpty &&
          left != right) {
        final sorted = [left, right]..sort();
        result.add(
          PartnershipRecord(
            batterAId: sorted[0],
            batterBId: sorted[1],
            batterAName: playerNames[sorted[0]] ?? '',
            batterBName: playerNames[sorted[1]] ?? '',
            runs: runs,
            balls: balls,
          ),
        );
      }
      runs = 0;
      balls = 0;

      final dismissed = e.dismissedPlayerId ?? e.strikerId;
      if (dismissed != null && dismissed.isNotEmpty) {
        final survivor = left == dismissed
            ? right
            : (right == dismissed ? left : null);
        aId = survivor;
        bId = null;
      } else {
        aId = null;
        bId = null;
      }
    }

    return result;
  }

  /// Fielding credits from wicket events.
  static List<FielderInningsModel> fieldersFromEvents(
    List<BallEventModel> events,
  ) {
    final map = <String, FielderInningsModel>{};

    for (final e in events) {
      if (!DismissalFormatter.eventCountsAsWicket(e)) continue;
      if (DismissalFormatter.isRetiredOutEvent(e)) continue;
      final type = e.wicketType;
      var fielderId = e.primaryFielderId ?? e.fielderId;
      if (type == null || fielderId == null || fielderId.isEmpty) {
        if (type == WicketType.stumped &&
            e.wicketKeeperId != null &&
            e.wicketKeeperId!.isNotEmpty) {
          fielderId = e.wicketKeeperId;
        } else {
          continue;
        }
      }

      var catches = 0;
      var runOuts = 0;
      var stumpings = 0;
      if (DismissalFormatter.isCaughtBehindEvent(e) ||
          type == WicketType.caughtBehind) {
        catches = 1;
        fielderId = e.wicketKeeperId ?? fielderId;
      } else {
        switch (type) {
          case WicketType.caught:
          case WicketType.caughtAndBowled:
            catches = 1;
          case WicketType.runOut:
            runOuts = 1;
          case WicketType.stumped:
            stumpings = 1;
            fielderId = e.wicketKeeperId ?? fielderId;
          default:
            continue;
        }
      }

      if (fielderId == null || fielderId.isEmpty) continue;
      final creditId = fielderId;

      final existing = map[creditId];
      map[creditId] = FielderInningsModel(
        playerId: creditId,
        playerName: existing?.playerName.isNotEmpty == true
            ? existing!.playerName
            : (e.wicketKeeperName ??
                e.primaryFielderName ??
                e.fielderName ??
                ''),
        catches: (existing?.catches ?? 0) + catches,
        runOuts: (existing?.runOuts ?? 0) + runOuts,
        stumpings: (existing?.stumpings ?? 0) + stumpings,
      );
    }
    return map.values.toList();
  }

  InningsModel _replay(
    MatchModel match,
    InningsModel lineupInnings,
    List<BallEventModel> events,
  ) {
    if (events.isEmpty) return lineupInnings;

    final idx = match.innings.indexWhere(
      (i) => i.inningsNumber == lineupInnings.inningsNumber,
    );
    final replayMatch = match.copyWith(
      currentInningsIndex: idx >= 0 ? idx : match.currentInningsIndex,
    );
    final base = _engine.baseInningsFrom(lineupInnings, events: events);
    final replayed = _engine.replayInnings(
      match: replayMatch,
      baseInnings: base,
      events: events,
    );
    return replayed.innings.firstWhere(
      (i) => i.inningsNumber == lineupInnings.inningsNumber,
      orElse: () => lineupInnings,
    );
  }

  /// Minutes at crease per batter: dismissal time − first appearance, or now if not out.
  static Map<String, int> batterMinutesFromEvents(
    List<BallEventModel> events, {
    Set<String> creaseIds = const {},
    required DateTime now,
  }) {
    final entry = <String, DateTime>{};
    final dismissed = <String, DateTime>{};

    for (final e in events) {
      final ts = e.timestamp ?? now;
      for (final id in [e.strikerId, e.nonStrikerId]) {
        if (id != null && id.isNotEmpty && !entry.containsKey(id)) {
          entry[id] = ts;
        }
      }
      // RH is not a dismissal — batter may return. RO and real wickets are.
      if (DismissalFormatter.eventCountsAsWicket(e) &&
          e.dismissedPlayerId != null) {
        dismissed[e.dismissedPlayerId!] = ts;
      }
    }

    final minutes = <String, int>{};
    final allIds = {...entry.keys, ...dismissed.keys, ...creaseIds};
    for (final id in allIds) {
      final start = entry[id];
      if (start == null) continue;
      final end = dismissed[id] ?? (creaseIds.contains(id) ? now : null);
      if (end == null) continue;
      final mins = end.difference(start).inMinutes;
      minutes[id] = mins < 0 ? 0 : mins;
    }
    return minutes;
  }

  /// Maiden overs per bowler (0 runs conceded in a completed over).
  static Map<String, int> maidenOversFromEvents(
    List<BallEventModel> events,
    MatchRulesModel rules,
  ) {
    final runsInOver = <String, int>{};
    final legalInOver = <String, bool>{};

    for (final e in events) {
      final bowlerId = e.bowlerId;
      if (bowlerId == null || bowlerId.isEmpty) continue;
      final key = '$bowlerId|${e.inningsNumber}|${e.overNumber}';
      runsInOver[key] = (runsInOver[key] ?? 0) + _runsAgainstBowler(e);
      if (e.isLegalDelivery) legalInOver[key] = true;
    }

    final maidens = <String, int>{};
    for (final entry in runsInOver.entries) {
      final bowlerId = entry.key.split('|').first;
      final key = entry.key;
      if ((legalInOver[key] ?? false) && entry.value == 0) {
        maidens[bowlerId] = (maidens[bowlerId] ?? 0) + 1;
      }
    }
    return maidens;
  }

  static int _runsAgainstBowler(BallEventModel event) {
    if (event.eventType == BallEventType.bye ||
        event.eventType == BallEventType.legBye) {
      return 0;
    }
    return event.runs;
  }

  /// Cumulative team score after each event (worm graph, run rate).
  static List<({int sequence, int totalRuns, int legalBalls})> cumulativeScore(
    List<BallEventModel> events,
  ) {
    var runs = 0;
    var legal = 0;
    final points = <({int sequence, int totalRuns, int legalBalls})>[];
    for (final e in events) {
      runs += e.runs;
      if (e.isLegalDelivery) legal++;
      points.add((sequence: e.sequence, totalRuns: runs, legalBalls: legal));
    }
    return points;
  }

  /// Over-by-over ball symbols for comms / over history.
  static Map<int, List<String>> overSymbols(
    List<BallEventModel> events,
    MatchRulesModel rules,
  ) {
    final byOver = <int, List<BallEventModel>>{};
    for (final e in events) {
      if (e.eventType == BallEventType.lineupChange ||
          e.eventType == BallEventType.wicketKeeperChange ||
          !e.countsInOver) {
        continue;
      }
      byOver.putIfAbsent(e.overNumber, () => []).add(e);
    }

    final result = <int, List<String>>{};
    for (final entry in byOver.entries) {
      final sorted = [...entry.value]..sort((a, b) => a.sequence.compareTo(b.sequence));
      result[entry.key] = sorted.map((e) => _symbolForEvent(e)).toList();
    }
    return result;
  }

  static String _symbolForEvent(BallEventModel e) {
    final label = ScoringDisplayUtils.ballBubbleLabel(e);
    if (label.isNotEmpty) return label;
    return switch (e.eventType) {
      BallEventType.penalty => 'P',
      BallEventType.runs => e.batsmanRuns == 0 ? '·' : '${e.batsmanRuns}',
      BallEventType.lineupChange => '',
      BallEventType.wicketKeeperChange => '',
      _ => '',
    };
  }

  /// Run rate at end of innings from events.
  static double currentRunRate(
    List<BallEventModel> events,
    MatchRulesModel rules,
  ) {
    var runs = 0;
    var legal = 0;
    for (final e in events) {
      runs += e.runs;
      if (e.isLegalDelivery) legal++;
    }
    return CricketMath.runRate(runs, legal, rules.ballsPerOver);
  }
}

/// Event-derived view of one innings (preferred over raw [InningsModel] cache).
class InningsDerivedProjection {
  const InningsDerivedProjection({
    required this.innings,
    required this.events,
    required this.extrasBreakdown,
    required this.fallOfWickets,
    required this.partnerships,
    required this.fielders,
    required this.batterMinutes,
    required this.bowlerMaidens,
  });

  final InningsModel innings;
  final List<BallEventModel> events;
  final InningsExtrasBreakdown extrasBreakdown;
  final List<FallOfWicketRecord> fallOfWickets;
  final List<PartnershipRecord> partnerships;
  final List<FielderInningsModel> fielders;
  final Map<String, int> batterMinutes;
  final Map<String, int> bowlerMaidens;
}
