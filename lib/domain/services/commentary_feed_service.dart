import '../../core/constants/enums.dart';
import '../../core/utils/cricket_math.dart';
import '../../core/utils/overs_formatter.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../domain/scoring/ball_event_aggregator.dart';
import '../../features/scoring/presentation/utils/scoring_display_utils.dart';
import 'commentary_feed_models.dart';
import 'commentary_service.dart';
import 'dismissal_formatter.dart';

/// Builds the match commentary timeline from ball events and match metadata.
class CommentaryFeedService {
  CommentaryFeedService._();

  static CommentaryFeed build({
    required MatchModel match,
    required List<BallEventModel> allEvents,
  }) {
    if (match.innings.isEmpty) {
      return CommentaryFeed.empty;
    }

    final inningsOptions = <CommentaryInningsOption>[];
    final itemsByInnings = <int, List<CommentaryFeedItem>>{};

    for (final inn in match.innings) {
      final teamName = _battingTeamName(match, inn);
      inningsOptions.add(
        CommentaryInningsOption(
          inningsNumber: inn.inningsNumber,
          teamName: teamName,
          battingTeamId: inn.battingTeamId,
        ),
      );

      final events = BallEventAggregator.eventsForInnings(
        allEvents,
        inn.inningsNumber,
      );
      itemsByInnings[inn.inningsNumber] = _buildInningsFeed(
        match: match,
        innings: inn,
        events: events,
      );
    }

    return CommentaryFeed(
      itemsByInnings: itemsByInnings,
      inningsOptions: inningsOptions,
    );
  }

  static List<CommentaryFeedItem> _buildInningsFeed({
    required MatchModel match,
    required InningsModel innings,
    required List<BallEventModel> events,
  }) {
    final rules = match.rules;
    final bpo = rules.ballsPerOver;
    final names = _nameMap(innings);
    final items = <CommentaryFeedItem>[];

    if (events.isEmpty) return _sortItems(items);

    var totalRuns = 0;
    var totalWickets = 0;
    var legalBalls = 0;

    final batterRuns = <String, int>{};
    final batterBalls = <String, int>{};
    final batterFours = <String, int>{};
    final batterSixes = <String, int>{};
    final bowlerStats = <String, _BowlerRunning>{};

    final overAcc = _OverAccumulator();
    int? activePowerplaySlot;
    int ppRuns = 0;
    int ppWickets = 0;
    int ppLegalBalls = 0;
    final powerplaySlots = rules.powerplaySlots;
    final powerplayLabels = rules.powerplayLabels;

    for (final e in events) {
      if (_isSkippableMetaEvent(e)) {
        if (e.eventType == BallEventType.endOver) {
          _flushOverSummary(
            acc: overAcc,
            items: items,
            inningsNumber: innings.inningsNumber,
            bpo: bpo,
            bowlerStats: bowlerStats,
            names: names,
            batterRuns: batterRuns,
            batterBalls: batterBalls,
            totalRuns: totalRuns,
            totalWickets: totalWickets,
            sortKey: e.sequence,
          );
          _maybeEndPowerplay(
            overNumber: e.overNumber,
            activeSlot: activePowerplaySlot,
            slots: powerplaySlots,
            labels: powerplayLabels,
            inningsNumber: innings.inningsNumber,
            sortKey: e.sequence,
            items: items,
            runsScored: ppRuns,
            wicketsLost: ppWickets,
            legalBalls: ppLegalBalls,
            ballsPerOver: bpo,
          );
          overAcc.reset();
          activePowerplaySlot = null;
          ppRuns = 0;
          ppWickets = 0;
          ppLegalBalls = 0;
        }
        continue;
      }

      if (!overAcc.hasStarted || overAcc.overNumber != e.overNumber) {
        if (overAcc.hasStarted) {
          _flushOverSummary(
            acc: overAcc,
            items: items,
            inningsNumber: innings.inningsNumber,
            bpo: bpo,
            bowlerStats: bowlerStats,
            names: names,
            batterRuns: batterRuns,
            batterBalls: batterBalls,
            totalRuns: totalRuns,
            totalWickets: totalWickets,
            sortKey: e.sequence - 1,
          );
          _maybeEndPowerplay(
            overNumber: overAcc.overNumber,
            activeSlot: activePowerplaySlot,
            slots: powerplaySlots,
            labels: powerplayLabels,
            inningsNumber: innings.inningsNumber,
            sortKey: e.sequence - 1,
            items: items,
            runsScored: ppRuns,
            wicketsLost: ppWickets,
            legalBalls: ppLegalBalls,
            ballsPerOver: bpo,
          );
          overAcc.reset();
          activePowerplaySlot = null;
          ppRuns = 0;
          ppWickets = 0;
          ppLegalBalls = 0;
        }
        overAcc.overNumber = e.overNumber;
        overAcc.hasStarted = true;

        final slot = _powerplaySlotForOver(e.overNumber, powerplaySlots);
        if (slot != null && slot != activePowerplaySlot) {
          activePowerplaySlot = slot;
          ppRuns = 0;
          ppWickets = 0;
          ppLegalBalls = 0;
          final label = powerplayLabels.length > slot
              ? powerplayLabels[slot]
              : 'Powerplay ${slot + 1}';
          items.add(
            MatchEventCommentaryItem(
              sortKey: e.sequence,
              inningsNumber: innings.inningsNumber,
              filters: {CommentaryFilter.powerplays, CommentaryFilter.full},
              eventKind: CommentaryMatchEventKind.powerplayStarted,
              title: '$label Started',
              detail: 'Fielding restrictions are now active.',
            ),
          );
        }
      }

      if (activePowerplaySlot != null) {
        ppRuns += e.runs;
        ppLegalBalls += e.isLegalDelivery ? 1 : 0;
        if (e.eventType == BallEventType.wicket && e.isWicket) ppWickets++;
      }

      final strikerName = _strikerName(e, names);
      final bowlerName = _bowlerName(e, names);

      totalRuns += e.runs;
      if (e.isLegalDelivery) legalBalls++;

      if (e.countsInOver) {
        overAcc.addBall(e, names);
        if (e.bowlerId != null && e.bowlerId!.isNotEmpty) {
          overAcc.bowlerId = e.bowlerId;
          overAcc.bowlerName = bowlerName;
        }
      }

      _trackBowlerStats(e, bowlerStats, names);

      final strikerId = e.strikerId;
      if (strikerId != null &&
          strikerId.isNotEmpty &&
          e.eventType == BallEventType.runs) {
        batterRuns[strikerId] = (batterRuns[strikerId] ?? 0) + e.batsmanRuns;
        if (e.countsAsBallFaced) {
          batterBalls[strikerId] = (batterBalls[strikerId] ?? 0) + 1;
        }
        if (e.runs == 4 || e.batsmanRuns == 4) {
          batterFours[strikerId] = (batterFours[strikerId] ?? 0) + 1;
        }
        if (e.runs >= 6 || e.batsmanRuns >= 6) {
          batterSixes[strikerId] = (batterSixes[strikerId] ?? 0) + 1;
        }
      }

        if (e.eventType == BallEventType.wicket && e.isWicket) {
          final dismissed = e.dismissedPlayerId ?? e.strikerId;
          if (dismissed != null && dismissed.isNotEmpty) {
            batterRuns[dismissed] =
                (batterRuns[dismissed] ?? 0) + e.batsmanRuns;
            if (e.countsAsBallFaced) {
              batterBalls[dismissed] = (batterBalls[dismissed] ?? 0) + 1;
            }
          }
        }

        if (_isDisplayBallEvent(e)) {
        final filters = _filtersForBall(e);
        final headline = CommentaryService.headlineForEvent(
          e,
          strikerName: strikerName,
          bowlerName: bowlerName,
        );
        final description = CommentaryService.descriptiveForEvent(
          e,
          strikerName: strikerName,
          bowlerName: bowlerName,
        );

        String? dismissalShort;
        String? dismissedName;
        String? wicketDetailLine;
        int? br;
        int? bb;
        String? fielderLine;

        if (e.eventType == BallEventType.wicket && e.isWicket) {
          totalWickets++;
          dismissedName = e.dismissedPlayerName?.isNotEmpty == true
              ? e.dismissedPlayerName!
              : _displayName(
                  playerId: e.dismissedPlayerId ?? strikerId,
                  names: names,
                );
          dismissalShort = DismissalFormatter.fromWicketEvent(
            e,
            playerNames: names,
          );
          fielderLine = _fielderLine(e, names);
          final dismissedId = e.dismissedPlayerId ?? strikerId ?? '';
          br = batterRuns[dismissedId];
          bb = batterBalls[dismissedId];
          if (dismissedName.isNotEmpty && dismissalShort.isNotEmpty) {
            wicketDetailLine = _wicketDetailLine(
              dismissedName: dismissedName,
              dismissalShort: dismissalShort,
              runs: br ?? 0,
              balls: bb ?? 0,
              fours: batterFours[dismissedId] ?? 0,
              sixes: batterSixes[dismissedId] ?? 0,
            );
          }
        }

        items.add(
          BallCommentaryItem(
            sortKey: e.sequence,
            inningsNumber: innings.inningsNumber,
            filters: filters,
            event: e,
            strikerName: strikerName,
            bowlerName: bowlerName,
            headline: headline,
            description: description,
            teamRuns: totalRuns,
            teamWickets: totalWickets,
            legalBalls: legalBalls,
            fielderLine: fielderLine,
            dismissedName: dismissedName,
            dismissalShort: dismissalShort,
            wicketDetailLine: wicketDetailLine,
            batterRuns: br,
            batterBalls: bb,
          ),
        );

        if (e.eventType == BallEventType.wicket &&
            e.isWicket &&
            e.nextStrikerId != null &&
            e.nextStrikerId!.isNotEmpty) {
          final nextName = _displayName(
            eventName: e.nextStrikerName,
            playerId: e.nextStrikerId,
            names: names,
          );
          items.add(
            NextBatterCommentaryItem(
              sortKey: e.sequence,
              inningsNumber: innings.inningsNumber,
              filters: {CommentaryFilter.wickets, CommentaryFilter.full},
              playerId: e.nextStrikerId!,
              playerName: nextName,
            ),
          );
        }
      }

      final legalInOver = overAcc.legalBalls;
      if (legalInOver >= bpo && e.isLegalDelivery) {
        _flushOverSummary(
          acc: overAcc,
          items: items,
          inningsNumber: innings.inningsNumber,
          bpo: bpo,
          bowlerStats: bowlerStats,
          names: names,
          batterRuns: batterRuns,
          batterBalls: batterBalls,
          totalRuns: totalRuns,
          totalWickets: totalWickets,
          sortKey: e.sequence,
        );
        _maybeEndPowerplay(
          overNumber: e.overNumber,
          activeSlot: activePowerplaySlot,
          slots: powerplaySlots,
          labels: powerplayLabels,
          inningsNumber: innings.inningsNumber,
          sortKey: e.sequence,
          items: items,
          runsScored: ppRuns,
          wicketsLost: ppWickets,
          legalBalls: ppLegalBalls,
          ballsPerOver: bpo,
        );
        overAcc.reset();
        activePowerplaySlot = null;
        ppRuns = 0;
        ppWickets = 0;
        ppLegalBalls = 0;
      }
    }

    if (overAcc.hasStarted && overAcc.symbols.isNotEmpty) {
      _flushOverSummary(
        acc: overAcc,
        items: items,
        inningsNumber: innings.inningsNumber,
        bpo: bpo,
        bowlerStats: bowlerStats,
        names: names,
        batterRuns: batterRuns,
        batterBalls: batterBalls,
        totalRuns: totalRuns,
        totalWickets: totalWickets,
        sortKey: events.last.sequence,
      );
    }

    return _sortItems(items);
  }

  static void _flushOverSummary({
    required _OverAccumulator acc,
    required List<CommentaryFeedItem> items,
    required int inningsNumber,
    required int bpo,
    required Map<String, _BowlerRunning> bowlerStats,
    required Map<String, String> names,
    required Map<String, int> batterRuns,
    required Map<String, int> batterBalls,
    required int totalRuns,
    required int totalWickets,
    required int sortKey,
  }) {
    if (!acc.hasStarted || acc.symbols.isEmpty) return;

    final bowlerId = acc.bowlerId ?? '';
    final stats = bowlerStats[bowlerId];
    final bowlerName = acc.bowlerName.isNotEmpty
        ? acc.bowlerName
        : _displayName(playerId: bowlerId, names: names);

    final bowlerLine = CommentaryBowlerLine(
      name: bowlerName,
      oversText: stats != null
          ? OversFormatter.formatOvers(stats.legalBalls, bpo)
          : '0.0',
      maidens: stats?.maidens ?? 0,
      runs: stats?.runs ?? 0,
      wickets: stats?.wickets ?? 0,
    );

    final batters = acc.batterNamesInOver
        .map(
          (name) => CommentaryBatterLine(
            name: name,
            runs: batterRuns[acc.nameToId[name] ?? ''] ?? 0,
            balls: batterBalls[acc.nameToId[name] ?? ''] ?? 0,
          ),
        )
        .where((b) => b.name.isNotEmpty)
        .toList();

    final bowlerToLine = acc.bowlerToLine(bowlerName);

    items.add(
      OverSummaryCommentaryItem(
        sortKey: sortKey,
        inningsNumber: inningsNumber,
        filters: {
          CommentaryFilter.overs,
          CommentaryFilter.full,
          CommentaryFilter.wickets,
          CommentaryFilter.boundaries,
        },
        overNumber: acc.overNumber,
        ballSymbols: List<String>.from(acc.symbols),
        ballEvents: List<BallEventModel>.from(acc.events),
        runsInOver: acc.runs,
        wicketsInOver: acc.wickets,
        teamRuns: totalRuns,
        teamWickets: totalWickets,
        batters: batters,
        bowler: bowlerLine,
        bowlerToLine: bowlerToLine,
      ),
    );
  }

  static void _maybeEndPowerplay({
    required int overNumber,
    required int? activeSlot,
    required List<List<int>> slots,
    required List<String> labels,
    required int inningsNumber,
    required int sortKey,
    required List<CommentaryFeedItem> items,
    required int runsScored,
    required int wicketsLost,
    required int legalBalls,
    required int ballsPerOver,
  }) {
    if (activeSlot == null) return;
    final slotOvers = slots[activeSlot];
    if (slotOvers.isEmpty) return;
    final lastOver = slotOvers.reduce((a, b) => a > b ? a : b);
    if (overNumber != lastOver) return;

    final label = labels.length > activeSlot
        ? labels[activeSlot]
        : 'Powerplay ${activeSlot + 1}';
    final crr = legalBalls > 0
        ? CricketMath.runRate(runsScored, legalBalls, ballsPerOver)
        : 0.0;
  final wicketLabel = wicketsLost == 1 ? 'Wicket' : 'Wickets';
    items.add(
      MatchEventCommentaryItem(
        sortKey: sortKey,
        inningsNumber: inningsNumber,
        filters: {CommentaryFilter.powerplays, CommentaryFilter.full},
        eventKind: CommentaryMatchEventKind.powerplayEnded,
        title: '$label Ended',
        detail: 'Powerplay completed.',
        subtitle: '$runsScored Runs · $wicketsLost $wicketLabel',
        runsScored: runsScored,
        wicketsLost: wicketsLost,
        crr: crr,
      ),
    );
  }

  static int? _powerplaySlotForOver(int overNumber, List<List<int>> slots) {
    for (var i = 0; i < slots.length; i++) {
      if (slots[i].contains(overNumber)) return i;
    }
    return null;
  }

  static void _trackBowlerStats(
    BallEventModel e,
    Map<String, _BowlerRunning> stats,
    Map<String, String> names,
  ) {
    final id = e.bowlerId;
    if (id == null || id.isEmpty || !e.countsToBowler) return;
    final s = stats.putIfAbsent(id, () => _BowlerRunning());
    if (e.bowlerName?.isNotEmpty == true) {
      s.name = e.bowlerName!;
    } else if (names[id]?.isNotEmpty == true) {
      s.name = names[id]!;
    }
    s.runs += _runsAgainstBowler(e);
    if (e.isLegalDelivery) s.legalBalls++;
    if (e.bowlerGetsWicket) s.wickets++;
  }

  static int _runsAgainstBowler(BallEventModel e) {
    if (e.eventType == BallEventType.wide ||
        e.eventType == BallEventType.noBall) {
      return e.extraRuns;
    }
    if (e.eventType == BallEventType.bye ||
        e.eventType == BallEventType.legBye) {
      return 0;
    }
    return e.runs;
  }

  static Set<CommentaryFilter> _filtersForBall(BallEventModel e) {
    final filters = <CommentaryFilter>{CommentaryFilter.full};
    if (e.eventType == BallEventType.wicket && e.isWicket) {
      filters.add(CommentaryFilter.wickets);
    }
    if (e.isBoundary || e.runs == 4 || e.runs >= 6) {
      filters.add(CommentaryFilter.boundaries);
    }
    return filters;
  }

  static bool _isDisplayBallEvent(BallEventModel e) {
    return switch (e.eventType) {
      BallEventType.runs ||
      BallEventType.wide ||
      BallEventType.noBall ||
      BallEventType.bye ||
      BallEventType.legBye ||
      BallEventType.wicket ||
      BallEventType.penalty =>
        true,
      _ => false,
    };
  }

  static bool _isSkippableMetaEvent(BallEventModel e) {
    return switch (e.eventType) {
      BallEventType.lineupChange ||
      BallEventType.batterSwap ||
      BallEventType.wicketKeeperChange ||
      BallEventType.endOver =>
        true,
      _ => false,
    };
  }

  static String? _fielderLine(BallEventModel e, Map<String, String> names) {
    final fielder = e.primaryFielderName?.isNotEmpty == true
        ? e.primaryFielderName!
        : (e.fielderName?.isNotEmpty == true
            ? e.fielderName!
            : names[e.primaryFielderId ?? e.fielderId ?? ''] ?? '');
    if (fielder.isEmpty) return null;
    if (e.wicketType == WicketType.caught ||
        e.wicketType == WicketType.caughtBehind ||
        DismissalFormatter.isCaughtBehindEvent(e)) {
      return 'Caught by $fielder';
    }
    if (e.wicketType == WicketType.runOut || e.isMankad) {
      return 'Run out by $fielder';
    }
    if (e.wicketType == WicketType.stumped) {
      return 'Stumped by $fielder';
    }
    return null;
  }

  static String _strikerName(BallEventModel e, Map<String, String> names) {
    return _displayName(
      eventName: e.dismissedPlayerName ?? e.lineupStrikerName,
      playerId: e.strikerId,
      names: names,
    );
  }

  static String _bowlerName(BallEventModel e, Map<String, String> names) {
    return _displayName(
      eventName: e.bowlerName,
      playerId: e.bowlerId,
      names: names,
    );
  }

  static String _displayName({
    String? eventName,
    String? playerId,
    required Map<String, String> names,
  }) {
    if (eventName != null && eventName.trim().isNotEmpty) {
      return eventName.trim();
    }
    if (playerId != null && names[playerId]?.isNotEmpty == true) {
      return names[playerId]!;
    }
    return '';
  }

  static String _wicketDetailLine({
    required String dismissedName,
    required String dismissalShort,
    required int runs,
    required int balls,
    required int fours,
    required int sixes,
  }) {
    final sr = CricketMath.strikeRate(runs, balls).toStringAsFixed(2);
    return '$dismissedName $dismissalShort (${runs}r ${balls}b ${fours}x4s ${sixes}x6s SR: $sr)';
  }

  static String sanitizeDisplayText(String? text) {
    if (text == null || text.isEmpty) return '';
    if (text.contains('BallEventModel')) return '';
    if (text.contains('Instance of')) return '';
    return text;
  }

  static Map<String, String> _nameMap(InningsModel innings) {
    final names = <String, String>{};
    for (final b in innings.batsmen) {
      if (b.playerId.isNotEmpty) names[b.playerId] = b.playerName;
    }
    for (final b in innings.bowlers) {
      if (b.playerId.isNotEmpty) names[b.playerId] = b.playerName;
    }
    return names;
  }

  static String _battingTeamName(MatchModel match, InningsModel inn) {
    if (inn.battingTeamId == match.teamAId) return match.teamAName;
    if (inn.battingTeamId == match.teamBId) return match.teamBName;
    return inn.inningsNumber == 1 ? match.teamAName : match.teamBName;
  }

  static List<CommentaryFeedItem> _sortItems(List<CommentaryFeedItem> items) {
    items.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return items;
  }

  /// Chase / match context for the thin banner below filters.
  static String? primaryContextLine(MatchModel match, InningsModel innings) {
    final chase = ScoringDisplayUtils.chaseDisplay(match, innings, match.rules);
    if (chase != null && chase.isChasing && chase.ballsRemaining > 0) {
      return 'needs ${chase.runsNeeded} runs in ${chase.ballsRemaining} balls to win this match';
    }
    final lines = contextLines(match, innings);
    return lines.isEmpty ? null : lines.first;
  }

  /// Chase context lines for detailed display.
  static List<String> contextLines(MatchModel match, InningsModel innings) {
    final chase = ScoringDisplayUtils.chaseDisplay(match, innings, match.rules);
    if (chase == null || !chase.isChasing) {
      final rr = CricketMath.runRate(
        innings.totalRuns,
        innings.legalBalls,
        match.rules.ballsPerOver,
      );
      if (innings.legalBalls > 0) {
        return ['Current run rate ${rr.toStringAsFixed(2)}'];
      }
      return const [];
    }

    final lines = <String>[];
    if (chase.runsNeeded > 0 && chase.ballsRemaining > 0) {
      lines.add(
        'Needs $chase.runsNeeded runs from ${chase.ballsRemaining} balls',
      );
      lines.add(
        'Requires ${chase.requiredRunRate.toStringAsFixed(1)} runs per over',
      );
    } else if (chase.runsNeeded <= 0) {
      lines.add('Target achieved');
    }
    lines.add(
      'Current run rate ${chase.currentRunRate.toStringAsFixed(2)}',
    );
  if (chase.runsNeeded > 0) {
      lines.add(
        'Required run rate ${chase.requiredRunRate.toStringAsFixed(2)}',
      );
    }
    return lines;
  }
}

class _OverAccumulator {
  int overNumber = 0;
  bool hasStarted = false;
  final List<String> symbols = [];
  final List<BallEventModel> events = [];
  int runs = 0;
  int wickets = 0;
  int legalBalls = 0;
  String? bowlerId;
  String bowlerName = '';
  final List<String> strikerIds = [];
  final List<String> batterNamesInOver = [];
  final Map<String, String> nameToId = {};

  void addBall(BallEventModel e, Map<String, String> names) {
    symbols.add(CommentaryBallSymbol.forEvent(e));
    events.add(e);
    runs += e.runs;
    if (e.isLegalDelivery) legalBalls++;
    if (e.eventType == BallEventType.wicket && e.isWicket) wickets++;

    strikerIds.clear();
    void trackBatter(String? id, String? eventName) {
      if (id == null || id.isEmpty) return;
      final name = CommentaryFeedService._displayName(
        eventName: eventName,
        playerId: id,
        names: names,
      );
      if (name.isEmpty) return;
      nameToId[name] = id;
      if (!batterNamesInOver.contains(name)) {
        batterNamesInOver.add(name);
      }
    }
    trackBatter(e.strikerAfterBall ?? e.strikerId, e.lineupStrikerName);
    trackBatter(e.nonStrikerAfterBall ?? e.nonStrikerId, e.lineupNonStrikerName);
    if (batterNamesInOver.isEmpty) {
      trackBatter(e.strikerId, e.lineupStrikerName);
      trackBatter(e.nonStrikerId, e.lineupNonStrikerName);
    }
  }

  String bowlerToLine(String bowler) {
    if (bowler.isEmpty || batterNamesInOver.isEmpty) return '';
    return '$bowler to ${batterNamesInOver.join(', ')}';
  }

  void reset() {
    hasStarted = false;
    overNumber = 0;
    symbols.clear();
    events.clear();
    runs = 0;
    wickets = 0;
    legalBalls = 0;
    bowlerId = null;
    bowlerName = '';
    strikerIds.clear();
    batterNamesInOver.clear();
    nameToId.clear();
  }
}

class _BowlerRunning {
  String name = '';
  int legalBalls = 0;
  int runs = 0;
  int wickets = 0;
  int maidens = 0;
}

/// Ball circle label and colors for commentary cards.
class CommentaryBallSymbol {
  CommentaryBallSymbol._();

  static String forEvent(BallEventModel e) {
    if (e.eventType == BallEventType.wicket && e.isWicket) return 'W';
    if (e.eventType == BallEventType.wide) return 'Wd';
    if (e.eventType == BallEventType.noBall) return 'Nb';
    if (e.eventType == BallEventType.bye) return 'B';
    if (e.eventType == BallEventType.legBye) return 'Lb';
    if (e.eventType == BallEventType.penalty) return 'P';
    if (e.runs == 0) return '·';
    return '${e.runs}';
  }
}
