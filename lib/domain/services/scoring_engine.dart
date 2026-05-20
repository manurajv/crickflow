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
        batsmanRuns = input.runs;
      case BallEventType.bye:
      case BallEventType.legBye:
        batsmanRuns = 0;
        runs = input.runs;
      case BallEventType.wicket:
        if (isFreeHit && input.wicketType != WicketType.runOut) {
          isLegal = true;
        }
      case BallEventType.penalty:
        break;
    }

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
      bowlerId: innings.currentBowlerId,
      wicketType: input.wicketType,
      dismissedPlayerId: input.dismissedPlayerId,
      fielderId: input.fielderId,
      commentary: input.commentary,
      sequence: sequence,
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
    var isFreeHit = false;

    if (event.isLegalDelivery) {
      legalBalls++;
      partnershipBalls++;
    } else {
      extras += event.extraRuns;
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

    if (event.strikerId != null && event.batsmanRuns > 0) {
      batsmen = _updateBatsman(batsmen, event.strikerId!, event.batsmanRuns);
    }

    if (event.bowlerId != null) {
      bowlers = _updateBowler(
        bowlers,
        event.bowlerId!,
        event.runs,
        event.isLegalDelivery,
        event.eventType == BallEventType.wicket &&
            event.wicketType != WicketType.runOut,
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

    // Strike rotation on odd runs
    if (event.batsmanRuns.isOdd &&
        event.isLegalDelivery &&
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
      currentBowlerId: innings.currentBowlerId,
      batsmen: batsmen,
      bowlers: bowlers,
      partnershipRuns: partnershipRuns,
      partnershipBalls: partnershipBalls,
      isFreeHitActive: isFreeHit,
    );
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
    } else {
      extras = (extras - event.extraRuns).clamp(0, 999);
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

  List<BatsmanInningsModel> _updateBatsman(
    List<BatsmanInningsModel> list,
    String playerId,
    int runs,
  ) {
    final idx = list.indexWhere((b) => b.playerId == playerId);
    if (idx >= 0) {
      final b = list[idx];
      list[idx] = BatsmanInningsModel(
        playerId: b.playerId,
        playerName: b.playerName,
        runs: b.runs + runs,
        balls: b.balls + 1,
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
    bool wicket,
  ) {
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
        noBalls: b.noBalls,
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
      final first = match.innings.first;
      target = first.totalRuns + 1;
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
    var working = match.copyWith(
      innings: _replaceInnings(match, baseInnings),
      overlayVersion: 0,
    );

    for (final e in events) {
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

  InningsModel baseInningsFrom(InningsModel current) {
    return InningsModel(
      inningsNumber: current.inningsNumber,
      battingTeamId: current.battingTeamId,
      bowlingTeamId: current.bowlingTeamId,
      status: InningsStatus.inProgress,
      strikerId: current.strikerId,
      nonStrikerId: current.nonStrikerId,
      currentBowlerId: current.currentBowlerId,
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
    return BallEventInput(
      type: e.eventType,
      runs: e.eventType == BallEventType.runs ? e.batsmanRuns : e.runs,
      wicketType: e.wicketType,
      dismissedPlayerId: e.dismissedPlayerId,
      fielderId: e.fielderId,
      commentary: e.commentary,
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
  });

  final BallEventType type;
  final int runs;
  final WicketType? wicketType;
  final String? dismissedPlayerId;
  final String? fielderId;
  final String commentary;
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
