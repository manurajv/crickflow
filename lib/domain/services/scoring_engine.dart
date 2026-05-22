import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_rules_model.dart';
import '../../core/utils/cricket_math.dart';
import '../../data/models/overlay_state_model.dart';

/// Pure scoring logic — applies ball events and returns updated match state.
class ScoringEngine {
  ScoringInput recordBall({
    required MatchModel match,
    required BallEventInput input,
    required int sequence,
  }) {
    final rules = match.rules;
    var innings = match.currentInnings;
    if (innings == null) {
      throw StateError('No active innings');
    }

    final event = _buildEvent(match, innings, input, sequence, rules);
    innings = _applyEventToInnings(innings, event, rules);

    final updatedInnings = List<InningsModel>.from(match.innings);
    updatedInnings[match.currentInningsIndex] = innings;

    var updatedMatch = match.copyWith(
      innings: updatedInnings,
      status: MatchStatus.live,
      overlayVersion: match.overlayVersion + 1,
    );

    final overlay = _buildOverlay(updatedMatch, innings, rules);
    return ScoringInput(
      match: updatedMatch,
      event: event,
      overlay: overlay,
    );
  }

  MatchModel undoLastBall(MatchModel match, BallEventModel lastEvent) {
    // MVP: reload from persisted innings snapshot is preferred in repository.
    // This provides structural undo by reversing known event effects.
    var innings = match.currentInnings;
    if (innings == null) return match;

    innings = _reverseEvent(innings, lastEvent, match.rules);
    final updatedInnings = List<InningsModel>.from(match.innings);
    updatedInnings[match.currentInningsIndex] = innings;

    return match.copyWith(
      innings: updatedInnings,
      overlayVersion: match.overlayVersion + 1,
    );
  }

  BallEventModel _buildEvent(
    MatchModel match,
    InningsModel innings,
    BallEventInput input,
    int sequence,
    MatchRulesModel rules,
  ) {
    final overNum = innings.legalBalls ~/ rules.ballsPerOver;
    final ballInOver = (innings.legalBalls % rules.ballsPerOver) + 1;

    var runs = input.runs;
    var batsmanRuns = input.runs;
    var extraRuns = 0;
    var isLegal = true;
    var isFreeHit = innings.isFreeHitActive;

    switch (input.type) {
      case BallEventType.runs:
        break;
      case BallEventType.wide:
        isLegal = false;
        extraRuns = rules.wideRuns;
        runs = extraRuns + input.runs;
        batsmanRuns = 0;
      case BallEventType.noBall:
        isLegal = false;
        extraRuns = rules.noBallRuns;
        runs = extraRuns + input.runs;
        final nbMode = input.noBallRunsMode ?? NoBallRunsMode.bat;
        batsmanRuns = nbMode == NoBallRunsMode.bat ? input.runs : 0;
      case BallEventType.bye:
      case BallEventType.legBye:
        batsmanRuns = 0;
        runs = input.runs;
        extraRuns = input.runs;
      case BallEventType.wicket:
        if (isFreeHit && input.wicketType != WicketType.runOut) {
          isLegal = true;
        }
      case BallEventType.penalty:
        break;
    }

    final nbMode = input.type == BallEventType.noBall
        ? (input.noBallRunsMode ?? NoBallRunsMode.bat)
        : null;
    final nbByeRuns = nbMode == NoBallRunsMode.bye ? input.runs : 0;
    final nbLegByeRuns = nbMode == NoBallRunsMode.legBye ? input.runs : 0;

    return BallEventModel(
      id: '',
      matchId: match.id,
      inningsNumber: innings.inningsNumber,
      overNumber: overNum,
      ballInOver: isLegal ? ballInOver : ballInOver,
      eventType: input.type,
      runs: runs,
      batsmanRuns: batsmanRuns,
      extraRuns: extraRuns,
      isLegalDelivery: isLegal,
      isFreeHit: isFreeHit,
      strikerId: innings.strikerId,
      nonStrikerId: innings.nonStrikerId,
      bowlerId: input.bowlerId ?? innings.currentBowlerId,
      wicketType: input.wicketType,
      dismissedPlayerId: input.dismissedPlayerId,
      fielderId: input.fielderId,
      commentary: input.commentary,
      sequence: sequence,
      noBallRunsMode: nbMode,
      noBallByeRuns: nbByeRuns,
      noBallLegByeRuns: nbLegByeRuns,
    );
  }

  InningsModel _applyEventToInnings(
    InningsModel innings,
    BallEventModel event,
    MatchRulesModel rules,
  ) {
    var totalRuns = innings.totalRuns + event.runs;
    var totalWickets = innings.totalWickets;
    var legalBalls = innings.legalBalls;
    var extras = innings.extras;
    var partnershipRuns = innings.partnershipRuns + event.runs;
    var partnershipBalls = innings.partnershipBalls;
    var isFreeHit = innings.isFreeHitActive;

    if (event.isLegalDelivery) {
      legalBalls++;
      partnershipBalls++;
      if (event.eventType == BallEventType.bye ||
          event.eventType == BallEventType.legBye) {
        extras += event.runs;
      }
      // Free hit consumed on the next legal delivery.
      isFreeHit = false;
    } else {
      extras += _illegalDeliveryExtras(event);
    }

    if (event.eventType == BallEventType.noBall && rules.freeHitEnabled) {
      isFreeHit = true;
    }

    var strikerId = innings.strikerId;
    var nonStrikerId = innings.nonStrikerId;

    if (event.eventType == BallEventType.wicket) {
      if (!(event.isFreeHit && event.wicketType != WicketType.runOut)) {
        totalWickets++;
        partnershipRuns = 0;
        partnershipBalls = 0;
        final dismissedId =
            event.dismissedPlayerId ?? event.strikerId ?? strikerId;
        if (dismissedId != null) {
          if (dismissedId == strikerId) strikerId = null;
          if (dismissedId == nonStrikerId) nonStrikerId = null;
        }
      }
    }

    var batsmen = List<BatsmanInningsModel>.from(innings.batsmen);
    var bowlers = List<BowlerInningsModel>.from(innings.bowlers);

    if (event.strikerId != null) {
      if (event.batsmanRuns > 0) {
        batsmen = _updateBatsman(
          batsmen,
          event.strikerId!,
          event.batsmanRuns,
          countBallFaced: _countsAsBallFaced(event),
        );
      } else if (_strikerFacedDelivery(event)) {
        batsmen = _incrementBatsmanBall(batsmen, event.strikerId!);
      }
    }

    if (event.bowlerId != null) {
      final runsAgainstBowler = _runsAgainstBowler(event);
      bowlers = _updateBowler(
        bowlers,
        event.bowlerId!,
        runsAgainstBowler,
        event.isLegalDelivery,
        event.eventType == BallEventType.wicket &&
            event.wicketType != WicketType.runOut,
        isNoBall: event.eventType == BallEventType.noBall,
      );
    }

    if (event.eventType == BallEventType.wicket &&
        !(event.isFreeHit && event.wicketType != WicketType.runOut)) {
      final dismissedId =
          event.dismissedPlayerId ?? event.strikerId ?? innings.strikerId;
      if (dismissedId != null) {
        batsmen = _markBatsmanOut(
          batsmen,
          dismissedId,
          event.wicketType?.name ?? 'out',
        );
      }
    }

    // Strike rotation on odd runs (incl. WD/NB/bye/LB running runs).
    if (_shouldRotateEndsForEvent(event) &&
        strikerId != null &&
        nonStrikerId != null) {
      final temp = strikerId;
      strikerId = nonStrikerId;
      nonStrikerId = temp;
    }

    // End of over rotation
    if (event.isLegalDelivery &&
        legalBalls % rules.ballsPerOver == 0 &&
        legalBalls > 0 &&
        strikerId != null &&
        nonStrikerId != null) {
      final temp = strikerId;
      strikerId = nonStrikerId;
      nonStrikerId = temp;
      isFreeHit = false;
    }

    return InningsModel(
      inningsNumber: innings.inningsNumber,
      battingTeamId: innings.battingTeamId,
      bowlingTeamId: innings.bowlingTeamId,
      status: InningsStatus.inProgress,
      totalRuns: totalRuns,
      totalWickets: totalWickets,
      legalBalls: legalBalls,
      extras: extras,
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      currentBowlerId: event.bowlerId ?? innings.currentBowlerId,
      batsmen: batsmen,
      bowlers: bowlers,
      partnershipRuns: partnershipRuns,
      partnershipBalls: partnershipBalls,
      isFreeHitActive: isFreeHit,
    );
  }

  /// Runs scored between wickets that can swap striker/non-striker.
  static int _runningRunsForEndChange(BallEventModel event) {
    switch (event.eventType) {
      case BallEventType.runs:
        return event.batsmanRuns;
      case BallEventType.wide:
        return event.runs - event.extraRuns;
      case BallEventType.noBall:
        if (event.noBallRunsMode == NoBallRunsMode.bye ||
            event.noBallRunsMode == NoBallRunsMode.legBye) {
          return event.runs - event.extraRuns;
        }
        return event.batsmanRuns;
      case BallEventType.bye:
      case BallEventType.legBye:
        return event.runs;
      default:
        return 0;
    }
  }

  static bool _shouldRotateEndsForEvent(BallEventModel event) {
    final running = _runningRunsForEndChange(event);
    if (!running.isOdd) return false;
    switch (event.eventType) {
      case BallEventType.wide:
      case BallEventType.noBall:
        return true;
      case BallEventType.bye:
      case BallEventType.legBye:
      case BallEventType.runs:
        return event.isLegalDelivery;
      default:
        return false;
    }
  }

  InningsModel _reverseEvent(
    InningsModel innings,
    BallEventModel event,
    MatchRulesModel rules,
  ) {
    var totalRuns = innings.totalRuns - event.runs;
    var totalWickets = innings.totalWickets;
    var legalBalls = innings.legalBalls;
    var extras = innings.extras;

    if (event.isLegalDelivery) {
      legalBalls = (legalBalls - 1).clamp(0, 999);
      if (event.eventType == BallEventType.bye ||
          event.eventType == BallEventType.legBye) {
        extras = (extras - event.runs).clamp(0, 999);
      }
    } else {
      extras = (extras - event.extraRuns).clamp(0, 999);
      if (event.eventType == BallEventType.noBall) {
        extras = (extras - event.noBallByeRuns - event.noBallLegByeRuns)
            .clamp(0, 999);
      }
    }

    if (event.eventType == BallEventType.wicket &&
        !(event.isFreeHit && event.wicketType != WicketType.runOut)) {
      totalWickets = (totalWickets - 1).clamp(0, 99);
    }

    return innings.copyWith(
      totalRuns: totalRuns,
      totalWickets: totalWickets,
      legalBalls: legalBalls,
      extras: extras,
    );
  }

  List<BatsmanInningsModel> _markBatsmanOut(
    List<BatsmanInningsModel> list,
    String playerId,
    String dismissal,
  ) {
    final idx = list.indexWhere((b) => b.playerId == playerId);
    if (idx >= 0) {
      final b = list[idx];
      list[idx] = BatsmanInningsModel(
        playerId: b.playerId,
        playerName: b.playerName,
        runs: b.runs,
        balls: b.balls,
        fours: b.fours,
        sixes: b.sixes,
        isOut: true,
        dismissalInfo: dismissal,
      );
    } else {
      list.add(
        BatsmanInningsModel(
          playerId: playerId,
          isOut: true,
          dismissalInfo: dismissal,
        ),
      );
    }
    return list;
  }

  /// Extras on wides / no-balls: total minus batsman; bye/LB on NB are not batsman runs.
  static int _illegalDeliveryExtras(BallEventModel event) {
    switch (event.eventType) {
      case BallEventType.wide:
      case BallEventType.noBall:
        return event.runs - event.batsmanRuns;
      default:
        return event.extraRuns;
    }
  }

  static int _runsAgainstBowler(BallEventModel event) {
    if (event.eventType == BallEventType.bye ||
        event.eventType == BallEventType.legBye) {
      return 0;
    }
    // No-ball: all runs (penalty + bat/bye/LB) count against bowler.
    return event.runs;
  }

  static bool _countsAsBallFaced(BallEventModel event) {
    if (!event.isLegalDelivery) return false;
    return event.eventType != BallEventType.wide &&
        event.eventType != BallEventType.noBall;
  }

  static bool _strikerFacedDelivery(BallEventModel event) {
    if (!event.isLegalDelivery) return false;
    return event.eventType != BallEventType.wide &&
        event.eventType != BallEventType.noBall;
  }

  List<BatsmanInningsModel> _incrementBatsmanBall(
    List<BatsmanInningsModel> list,
    String playerId,
  ) {
    final idx = list.indexWhere((b) => b.playerId == playerId);
    if (idx >= 0) {
      final b = list[idx];
      list[idx] = BatsmanInningsModel(
        playerId: b.playerId,
        playerName: b.playerName,
        runs: b.runs,
        balls: b.balls + 1,
        fours: b.fours,
        sixes: b.sixes,
        isOut: b.isOut,
        dismissalInfo: b.dismissalInfo,
      );
    }
    return list;
  }

  List<BatsmanInningsModel> _updateBatsman(
    List<BatsmanInningsModel> list,
    String playerId,
    int runs, {
    required bool countBallFaced,
  }) {
    final idx = list.indexWhere((b) => b.playerId == playerId);
    if (idx >= 0) {
      final b = list[idx];
      list[idx] = BatsmanInningsModel(
        playerId: b.playerId,
        playerName: b.playerName,
        runs: b.runs + runs,
        balls: b.balls + (countBallFaced ? 1 : 0),
        fours: b.fours + (runs == 4 ? 1 : 0),
        sixes: b.sixes + (runs == 6 ? 1 : 0),
        isOut: b.isOut,
        dismissalInfo: b.dismissalInfo,
      );
    }
    return list;
  }

  List<BowlerInningsModel> _updateBowler(
    List<BowlerInningsModel> list,
    String playerId,
    int runs,
    bool legalBall,
    bool wicket, {
    bool isNoBall = false,
  }) {
    final idx = list.indexWhere((b) => b.playerId == playerId);
    if (idx >= 0) {
      final b = list[idx];
      list[idx] = BowlerInningsModel(
        playerId: b.playerId,
        playerName: b.playerName,
        oversBowledBalls: b.oversBowledBalls + (legalBall ? 1 : 0),
        runsConceded: b.runsConceded + runs,
        wickets: b.wickets + (wicket ? 1 : 0),
        wides: b.wides,
        noBalls: b.noBalls + (isNoBall ? 1 : 0),
      );
    }
    return list;
  }

  OverlayStateModel _buildOverlay(
    MatchModel match,
    InningsModel innings,
    MatchRulesModel rules,
  ) {
    BatsmanInningsModel? striker;
    BatsmanInningsModel? nonStriker;
    BowlerInningsModel? bowler;

    for (final b in innings.batsmen) {
      if (b.playerId == innings.strikerId) striker = b;
      if (b.playerId == innings.nonStrikerId) nonStriker = b;
    }
    for (final b in innings.bowlers) {
      if (b.playerId == innings.currentBowlerId) bowler = b;
    }

    final rr = innings.legalBalls > 0
        ? (innings.totalRuns / innings.legalBalls) * rules.ballsPerOver
        : 0.0;

    int? target;
    double? requiredRunRate;
    if (innings.inningsNumber >= 2 && match.innings.isNotEmpty) {
      InningsModel? firstInnings;
      for (final inn in match.innings) {
        if (inn.inningsNumber == 1) {
          firstInnings = inn;
          break;
        }
      }
      firstInnings ??= match.innings.first;
      target = firstInnings.totalRuns + 1;
      final runsNeeded = target - innings.totalRuns;
      final ballsRemaining = rules.totalBalls - innings.legalBalls;
      if (runsNeeded > 0 && ballsRemaining > 0) {
        requiredRunRate = CricketMath.requiredRunRate(
          runsNeeded: runsNeeded,
          ballsRemaining: ballsRemaining,
          ballsPerOver: rules.ballsPerOver,
        );
      }
    }

    return OverlayStateModel(
      matchId: match.id,
      teamAName: match.teamAName,
      teamBName: match.teamBName,
      battingTeamName: match.teamAId == innings.battingTeamId
          ? match.teamAName
          : match.teamBName,
      totalRuns: innings.totalRuns,
      totalWickets: innings.totalWickets,
      legalBalls: innings.legalBalls,
      ballsPerOver: rules.ballsPerOver,
      runRate: rr,
      target: target,
      requiredRunRate: requiredRunRate,
      strikerName: striker?.playerName ?? '',
      strikerRuns: striker?.runs ?? 0,
      strikerBalls: striker?.balls ?? 0,
      nonStrikerName: nonStriker?.playerName ?? '',
      nonStrikerRuns: nonStriker?.runs ?? 0,
      nonStrikerBalls: nonStriker?.balls ?? 0,
      bowlerName: bowler?.playerName ?? '',
      bowlerWickets: bowler?.wickets ?? 0,
      bowlerRuns: bowler?.runsConceded ?? 0,
      bowlerBalls: bowler?.oversBowledBalls ?? 0,
      matchStatus: match.status.name,
      locationLabel: match.location.displayLabel,
      version: match.overlayVersion,
    );
  }

  /// Resets innings stats and replays [events] in order (used for undo).
  MatchModel replayInnings({
    required MatchModel match,
    required InningsModel baseInnings,
    required List<BallEventModel> events,
  }) {
    final inningsEvents = events
        .where((e) => e.inningsNumber == baseInnings.inningsNumber)
        .toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    var working = match.copyWith(
      innings: _replaceInnings(match, baseInnings),
      overlayVersion: 0,
    );

    for (final e in inningsEvents) {
      final input = _inputFromEvent(e);
      final result = recordBall(
        match: working,
        input: input,
        sequence: e.sequence,
      );
      working = result.match;
    }
    return working;
  }

  InningsModel baseInningsFrom(
    InningsModel current, {
    List<BallEventModel> events = const [],
  }) {
    var strikerId = current.strikerId;
    var nonStrikerId = current.nonStrikerId;
    var bowlerId = current.currentBowlerId;

    if (events.isNotEmpty) {
      final sorted = [...events]..sort((a, b) => a.sequence.compareTo(b.sequence));
      final first = sorted.first;
      strikerId = first.strikerId ?? strikerId;
      nonStrikerId = first.nonStrikerId ?? nonStrikerId;
      // Do not use [current.currentBowlerId] — it may hold the next-over pick.
      bowlerId = first.bowlerId ?? bowlerId;
    }

    return InningsModel(
      inningsNumber: current.inningsNumber,
      battingTeamId: current.battingTeamId,
      bowlingTeamId: current.bowlingTeamId,
      status: InningsStatus.inProgress,
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      currentBowlerId: bowlerId,
      batsmen: current.batsmen
          .map(
            (b) => BatsmanInningsModel(
              playerId: b.playerId,
              playerName: b.playerName,
            ),
          )
          .toList(),
      bowlers: current.bowlers
          .map(
            (b) => BowlerInningsModel(
              playerId: b.playerId,
              playerName: b.playerName,
            ),
          )
          .toList(),
    );
  }

  OverlayStateModel buildOverlayForMatch(MatchModel match) {
    final innings = match.currentInnings;
    if (innings == null) {
      return OverlayStateModel(matchId: match.id);
    }
    return _buildOverlay(match, innings, match.rules);
  }

  BallEventInput _inputFromEvent(BallEventModel e) {
    final runs = switch (e.eventType) {
      BallEventType.runs => e.batsmanRuns,
      BallEventType.wide => e.runs - e.extraRuns,
      BallEventType.noBall =>
        e.batsmanRuns + e.noBallByeRuns + e.noBallLegByeRuns,
      BallEventType.bye || BallEventType.legBye => e.runs,
      _ => e.runs,
    };
    return BallEventInput(
      type: e.eventType,
      runs: runs,
      wicketType: e.wicketType,
      dismissedPlayerId: e.dismissedPlayerId,
      fielderId: e.fielderId,
      commentary: e.commentary,
      noBallRunsMode: e.noBallRunsMode,
      bowlerId: e.bowlerId,
    );
  }

  List<InningsModel> _replaceInnings(MatchModel match, InningsModel innings) {
    final list = List<InningsModel>.from(match.innings);
    if (match.currentInningsIndex < list.length) {
      list[match.currentInningsIndex] = innings;
    } else {
      list.add(innings);
    }
    return list;
  }
}

class BallEventInput {
  const BallEventInput({
    required this.type,
    this.runs = 0,
    this.wicketType,
    this.dismissedPlayerId,
    this.fielderId,
    this.commentary = '',
    this.noBallRunsMode,
    this.bowlerId,
  });

  final BallEventType type;
  final int runs;
  final WicketType? wicketType;
  final String? dismissedPlayerId;
  final String? fielderId;
  final String commentary;
  final NoBallRunsMode? noBallRunsMode;
  /// When replaying stored balls, preserves the original bowler on the event.
  final String? bowlerId;
}

class ScoringInput {
  const ScoringInput({
    required this.match,
    required this.event,
    required this.overlay,
  });

  final MatchModel match;
  final BallEventModel event;
  final OverlayStateModel overlay;
}

extension _InningsCopy on InningsModel {
  InningsModel copyWith({
    int? totalRuns,
    int? totalWickets,
    int? legalBalls,
    int? extras,
  }) {
    return InningsModel(
      inningsNumber: inningsNumber,
      battingTeamId: battingTeamId,
      bowlingTeamId: bowlingTeamId,
      status: status,
      totalRuns: totalRuns ?? this.totalRuns,
      totalWickets: totalWickets ?? this.totalWickets,
      legalBalls: legalBalls ?? this.legalBalls,
      extras: extras ?? this.extras,
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      currentBowlerId: currentBowlerId,
      batsmen: batsmen,
      bowlers: bowlers,
      partnershipRuns: partnershipRuns,
      partnershipBalls: partnershipBalls,
      isFreeHitActive: isFreeHitActive,
    );
  }
}
