import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/wagon_wheel_data.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_rules_model.dart';
import '../../core/utils/cricket_math.dart';
import '../../data/models/overlay_state_model.dart';
import '../../domain/scoring/innings_completion_policy.dart';
import '../../domain/services/dismissal_formatter.dart';
import '../../data/models/dismissal_fielder.dart';

/// Pure scoring logic — applies ball events and returns updated match state.
class ScoringEngine {
  ScoringInput recordBall({
    required MatchModel match,
    required BallEventInput input,
    required int sequence,
  }) {
    var innings = match.currentInnings;
    if (innings == null) {
      throw StateError('No active innings');
    }
    final effectiveRules = InningsCompletionPolicy.effectiveRules(match, innings);

    var event = _buildEvent(match, innings, input, sequence, effectiveRules);
    innings = _applyEventToInnings(innings, event, effectiveRules, match);

    event = _withPostBallAudit(
      event,
      strikerAfter: innings.strikerId,
      nonStrikerAfter: innings.nonStrikerId,
      createdBy: input.createdBy,
    );

    final updatedInnings = List<InningsModel>.from(match.innings);
    updatedInnings[match.currentInningsIndex] = innings;

    var updatedMatch = match.copyWith(
      innings: updatedInnings,
      status: MatchStatus.live,
      overlayVersion: match.overlayVersion + 1,
    );

    final overlay = _buildOverlay(updatedMatch, innings, effectiveRules);
    return ScoringInput(
      match: updatedMatch,
      event: event,
      overlay: overlay,
    );
  }

  static BallEventModel _withPostBallAudit(
    BallEventModel event, {
    String? strikerAfter,
    String? nonStrikerAfter,
    String? createdBy,
  }) {
    return BallEventModel(
      id: event.id,
      matchId: event.matchId,
      inningsNumber: event.inningsNumber,
      overNumber: event.overNumber,
      ballInOver: event.ballInOver,
      eventType: event.eventType,
      runs: event.runs,
      batsmanRuns: event.batsmanRuns,
      extraRuns: event.extraRuns,
      isLegalDelivery: event.isLegalDelivery,
      isFreeHit: event.isFreeHit,
      tournamentId: event.tournamentId,
      battingTeamId: event.battingTeamId,
      bowlingTeamId: event.bowlingTeamId,
      byeRuns: event.byeRuns,
      legByeRuns: event.legByeRuns,
      wideRuns: event.wideRuns,
      noBallRuns: event.noBallRuns,
      penaltyRuns: event.penaltyRuns,
      countsAsBallFaced: event.countsAsBallFaced,
      countsInOver: event.countsInOver,
      countsToBowler: event.countsToBowler,
      isWicket: event.isWicket,
      bowlerGetsWicket: event.bowlerGetsWicket,
      isBoundary: event.isBoundary,
      boundaryType: event.boundaryType,
      strikerId: event.strikerId,
      nonStrikerId: event.nonStrikerId,
      strikerAfterBall: strikerAfter,
      nonStrikerAfterBall: nonStrikerAfter,
      createdBy: createdBy ?? event.createdBy,
      bowlerId: event.bowlerId,
      bowlerName: event.bowlerName,
      wicketType: event.wicketType,
      dismissedPlayerId: event.dismissedPlayerId,
      fielderId: event.fielderId,
      fielderName: event.fielderName,
      dismissalText: event.dismissalText,
      fielders: event.fielders,
      commentary: event.commentary,
      timestamp: event.timestamp,
      sequence: event.sequence,
      isHighlight: event.isHighlight,
      highlightTag: event.highlightTag,
      noBallRunsMode: event.noBallRunsMode,
      noBallByeRuns: event.noBallByeRuns,
      noBallLegByeRuns: event.noBallLegByeRuns,
      wagonWheel: event.wagonWheel,
      lineupStrikerName: event.lineupStrikerName,
      lineupNonStrikerName: event.lineupNonStrikerName,
      dismissedPlayerName: event.dismissedPlayerName,
      primaryFielderId: event.primaryFielderId,
      primaryFielderName: event.primaryFielderName,
      secondaryFielderId: event.secondaryFielderId,
      secondaryFielderName: event.secondaryFielderName,
      teamScoreAtWicket: event.teamScoreAtWicket,
      overAtWicket: event.overAtWicket,
      ballAtWicket: event.ballAtWicket,
      isMankad: event.isMankad,
      wicketNumber: event.wicketNumber,
      dismissalType: event.dismissalType,
      fielderIds: event.fielderIds,
      fielderNames: event.fielderNames,
      wicketKeeperId: event.wicketKeeperId,
      wicketKeeperName: event.wicketKeeperName,
      dismissalSubType: event.dismissalSubType,
      currentWicketKeeperId: event.currentWicketKeeperId,
      currentWicketKeeperName: event.currentWicketKeeperName,
      undoGroupId: event.undoGroupId,
      nextStrikerId: event.nextStrikerId,
      nextStrikerName: event.nextStrikerName,
      runOutDeliveryKind: event.runOutDeliveryKind,
      retiredHurt: event.retiredHurt,
      isEligibleToReturn: event.isEligibleToReturn,
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
    final overNum = innings.currentOverStartLegalBalls ~/ rules.ballsPerOver;
    final ballsInCurrentOver =
        innings.legalBalls - innings.currentOverStartLegalBalls;
    final ballInOver = ballsInCurrentOver + 1;

    var runs = input.runs;
    var batsmanRuns = input.runs;
    var extraRuns = 0;
    var isLegal = true;
    var isFreeHit = innings.isFreeHitActive;

    switch (input.type) {
      case BallEventType.runs:
        break;
      case BallEventType.wide:
        isLegal = rules.wideCountsAsLegalDelivery;
        extraRuns = rules.wideRuns;
        runs = extraRuns + input.runs;
        batsmanRuns = 0;
      case BallEventType.noBall:
        isLegal = rules.noBallCountsAsLegalDelivery;
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
        if (input.wicketType == WicketType.runOut &&
            input.runOutDeliveryKind != null &&
            input.runOutDeliveryKind != RunOutDeliveryKind.normal) {
          final completed = input.completedRuns;
          switch (input.runOutDeliveryKind!) {
            case RunOutDeliveryKind.wide:
              isLegal = rules.wideCountsAsLegalDelivery;
              extraRuns = rules.wideRuns;
              runs = rules.wideRuns + completed;
              batsmanRuns = 0;
            case RunOutDeliveryKind.noBall:
              isLegal = rules.noBallCountsAsLegalDelivery;
              extraRuns = rules.noBallRuns;
              final nbMode = input.noBallRunsMode ?? NoBallRunsMode.bat;
              runs = rules.noBallRuns + completed;
              batsmanRuns = nbMode == NoBallRunsMode.bat ? completed : 0;
            case RunOutDeliveryKind.bye:
              runs = completed;
              batsmanRuns = 0;
              extraRuns = completed;
            case RunOutDeliveryKind.legBye:
              runs = completed;
              batsmanRuns = 0;
              extraRuns = completed;
            case RunOutDeliveryKind.normal:
              break;
          }
        } else {
          batsmanRuns = input.runs;
          runs = input.runs;
        }
        if (isFreeHit &&
            input.wicketType != WicketType.runOut &&
            input.wicketType != WicketType.mankad) {
          isLegal = true;
        }
      case BallEventType.penalty:
        break;
      case BallEventType.lineupChange:
        isLegal = false;
        runs = 0;
        batsmanRuns = 0;
      case BallEventType.wicketKeeperChange:
        isLegal = false;
        runs = 0;
        batsmanRuns = 0;
      case BallEventType.endOver:
        isLegal = false;
        runs = 0;
        batsmanRuns = 0;
    }

    final nbMode = input.type == BallEventType.noBall ||
            (input.type == BallEventType.wicket &&
                input.wicketType == WicketType.runOut &&
                input.runOutDeliveryKind == RunOutDeliveryKind.noBall)
        ? (input.noBallRunsMode ?? NoBallRunsMode.bat)
        : input.type == BallEventType.noBall
            ? (input.noBallRunsMode ?? NoBallRunsMode.bat)
            : null;
    final completedForNb = input.type == BallEventType.wicket &&
            input.wicketType == WicketType.runOut
        ? input.completedRuns
        : input.runs;
    final nbByeRuns = nbMode == NoBallRunsMode.bye ? completedForNb : 0;
    final nbLegByeRuns = nbMode == NoBallRunsMode.legBye ? completedForNb : 0;

    final isLineupChange = input.type == BallEventType.lineupChange;
    final isKeeperChange = input.type == BallEventType.wicketKeeperChange;
    final eventStrikerId = isLineupChange
        ? input.creaseStrikerId
        : innings.strikerId;
    final eventNonStrikerId = isLineupChange
        ? input.creaseNonStrikerId
        : innings.nonStrikerId;
    final bowlerId = input.bowlerId ?? innings.currentBowlerId;
    final bowlerName =
        input.bowlerName ?? _bowlerName(innings, bowlerId ?? '');
    final fielderName = input.fielderName ?? '';
    final primaryFielderId =
        input.fielderId ?? (input.fielders.isNotEmpty ? input.fielders.first.playerId : null);
    final primaryFielderName = fielderName.isNotEmpty
        ? fielderName
        : (input.fielders.isNotEmpty ? input.fielders.first.playerName : '');
    final secondaryFielder = input.fielders.length >= 2 ? input.fielders[1] : null;
    final isMankad = DismissalFormatter.isMankadType(input.wicketType) ||
        input.isMankad;
    final storedWicketType = isMankad ? WicketType.runOut : input.wicketType;
    final dismissedPlayerName = input.type == BallEventType.wicket
        ? (input.dismissedPlayerName ??
            _batsmanName(innings, input.dismissedPlayerId ?? ''))
        : null;
    final dismissalText = input.type == BallEventType.wicket
        ? DismissalFormatter.format(
            type: input.wicketType,
            bowlerName: bowlerName,
            fielderName: primaryFielderName,
            secondaryFielderName: secondaryFielder?.playerName,
            isMankad: isMankad,
            fielders: input.fielders,
            dismissalSubType: input.dismissalSubType,
          )
        : null;
    final fielderIds = BallEventModel.fielderIdsFromFielders(input.fielders);
    final fielderNamesList =
        BallEventModel.fielderNamesFromFielders(input.fielders);

    final breakdown = input.type == BallEventType.wicket &&
            input.wicketType == WicketType.runOut &&
            input.runOutDeliveryKind != null &&
            input.runOutDeliveryKind != RunOutDeliveryKind.normal
        ? _runOutDeliveryBreakdown(
            kind: input.runOutDeliveryKind!,
            completedRuns: input.completedRuns,
            noBallRunsMode: input.noBallRunsMode,
            rules: rules,
          )
        : _runBreakdown(
            type: input.type,
            runs: runs,
            batsmanRuns: batsmanRuns,
            extraRuns: extraRuns,
            nbByeRuns: nbByeRuns,
            nbLegByeRuns: nbLegByeRuns,
            rules: rules,
          );

    final isRetiredHurt = input.wicketType == WicketType.retiredHurt;
    final isWicket = input.type == BallEventType.wicket &&
        !isRetiredHurt &&
        DismissalFormatter.countsAsWicket(
          storedWicketType,
          isMankad: isMankad,
        ) &&
        !(isFreeHit && storedWicketType != WicketType.runOut);
    final bowlerGetsWicket = isWicket &&
        DismissalFormatter.creditsBowlerWicket(
          storedWicketType,
          isMankad: isMankad,
        );
    final wicketNumber = isWicket ? innings.totalWickets + 1 : null;

    final isBoundary = input.type == BallEventType.runs &&
        (batsmanRuns == 4 || batsmanRuns == 6);
    final boundaryType = isBoundary
        ? (batsmanRuns == 6 ? 'six' : 'four')
        : null;

    final countsAsBallFaced = isLegal &&
        input.type != BallEventType.wide &&
        input.type != BallEventType.noBall;
    final countsToBowler = input.type != BallEventType.bye &&
        input.type != BallEventType.legBye;

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
      tournamentId: match.tournamentId,
      battingTeamId: innings.battingTeamId,
      bowlingTeamId: innings.bowlingTeamId,
      byeRuns: breakdown.byeRuns,
      legByeRuns: breakdown.legByeRuns,
      wideRuns: breakdown.wideRuns,
      noBallRuns: breakdown.noBallRuns,
      penaltyRuns: breakdown.penaltyRuns,
      countsAsBallFaced: countsAsBallFaced,
      countsInOver: isLineupChange ||
              isKeeperChange ||
              input.type == BallEventType.endOver
          ? false
          : true,
      countsToBowler: countsToBowler,
      isWicket: isWicket,
      bowlerGetsWicket: bowlerGetsWicket,
      isBoundary: isBoundary,
      boundaryType: boundaryType,
      strikerId: eventStrikerId,
      nonStrikerId: eventNonStrikerId,
      bowlerId: bowlerId,
      bowlerName: bowlerName.isEmpty ? null : bowlerName,
      wicketType: storedWicketType,
      dismissedPlayerId: input.dismissedPlayerId,
      fielderId: primaryFielderId,
      fielderName: primaryFielderName.isEmpty ? null : primaryFielderName,
      dismissalText: dismissalText,
      fielders: input.fielders,
      dismissedPlayerName: dismissedPlayerName?.isEmpty == true
          ? null
          : dismissedPlayerName,
      primaryFielderId: primaryFielderId,
      primaryFielderName:
          primaryFielderName.isEmpty ? null : primaryFielderName,
      secondaryFielderId: secondaryFielder?.playerId,
      secondaryFielderName: secondaryFielder?.playerName.isNotEmpty == true
          ? secondaryFielder!.playerName
          : null,
      teamScoreAtWicket:
          input.type == BallEventType.wicket ? innings.totalRuns + runs : null,
      overAtWicket: input.type == BallEventType.wicket ? overNum : null,
      ballAtWicket: input.type == BallEventType.wicket ? ballInOver : null,
      isMankad: isMankad,
      wicketNumber: wicketNumber,
      dismissalType: input.type == BallEventType.wicket
          ? BallEventModel.dismissalTypeForEvent(
              wicketType: storedWicketType,
              isMankad: isMankad,
              dismissalSubType: input.dismissalSubType,
            )
          : null,
      dismissalSubType: input.type == BallEventType.wicket
          ? input.dismissalSubType
          : null,
      fielderIds: fielderIds,
      fielderNames: fielderNamesList,
      wicketKeeperId: input.wicketKeeperId,
      wicketKeeperName: input.wicketKeeperName,
      currentWicketKeeperId: input.currentWicketKeeperId ??
          innings.currentWicketKeeperId,
      currentWicketKeeperName: input.currentWicketKeeperName ??
          innings.currentWicketKeeperName,
      undoGroupId: input.undoGroupId,
      nextStrikerId: input.nextStrikerId,
      nextStrikerName: input.nextStrikerName,
      runOutDeliveryKind: input.type == BallEventType.wicket
          ? input.runOutDeliveryKind
          : null,
      retiredHurt: isRetiredHurt,
      isEligibleToReturn: isRetiredHurt,
      commentary: input.commentary,
      sequence: sequence,
      noBallRunsMode: nbMode,
      noBallByeRuns: nbByeRuns,
      noBallLegByeRuns: nbLegByeRuns,
      wagonWheel: input.wagonWheel,
      lineupStrikerName: input.creaseStrikerName,
      lineupNonStrikerName: input.creaseNonStrikerName,
    );
  }

  static _RunBreakdown _runBreakdown({
    required BallEventType type,
    required int runs,
    required int batsmanRuns,
    required int extraRuns,
    required int nbByeRuns,
    required int nbLegByeRuns,
    required MatchRulesModel rules,
  }) {
    var byeRuns = 0;
    var legByeRuns = 0;
    var wideRuns = 0;
    var noBallRuns = 0;
    var penaltyRuns = 0;

    switch (type) {
      case BallEventType.wide:
        wideRuns = runs;
      case BallEventType.bye:
        byeRuns = runs;
      case BallEventType.legBye:
        legByeRuns = runs;
      case BallEventType.noBall:
        noBallRuns = rules.noBallRuns;
        byeRuns = nbByeRuns;
        legByeRuns = nbLegByeRuns;
      case BallEventType.penalty:
        penaltyRuns = runs;
      default:
        break;
    }

    return _RunBreakdown(
      byeRuns: byeRuns,
      legByeRuns: legByeRuns,
      wideRuns: wideRuns,
      noBallRuns: noBallRuns,
      penaltyRuns: penaltyRuns,
    );
  }

  static _RunBreakdown _runOutDeliveryBreakdown({
    required RunOutDeliveryKind kind,
    required int completedRuns,
    required NoBallRunsMode? noBallRunsMode,
    required MatchRulesModel rules,
  }) {
    return switch (kind) {
      RunOutDeliveryKind.wide => _RunBreakdown(
          byeRuns: 0,
          legByeRuns: 0,
          wideRuns: rules.wideRuns,
          noBallRuns: 0,
          penaltyRuns: 0,
        ),
      RunOutDeliveryKind.noBall => _RunBreakdown(
          byeRuns:
              noBallRunsMode == NoBallRunsMode.bye ? completedRuns : 0,
          legByeRuns:
              noBallRunsMode == NoBallRunsMode.legBye ? completedRuns : 0,
          wideRuns: 0,
          noBallRuns: rules.noBallRuns,
          penaltyRuns: 0,
        ),
      RunOutDeliveryKind.bye => _RunBreakdown(
          byeRuns: completedRuns,
          legByeRuns: 0,
          wideRuns: 0,
          noBallRuns: 0,
          penaltyRuns: 0,
        ),
      RunOutDeliveryKind.legBye => _RunBreakdown(
          byeRuns: 0,
          legByeRuns: completedRuns,
          wideRuns: 0,
          noBallRuns: 0,
          penaltyRuns: 0,
        ),
      RunOutDeliveryKind.normal => const _RunBreakdown(
          byeRuns: 0,
          legByeRuns: 0,
          wideRuns: 0,
          noBallRuns: 0,
          penaltyRuns: 0,
        ),
    };
  }

  InningsModel _applyEventToInnings(
    InningsModel innings,
    BallEventModel event,
    MatchRulesModel rules,
    MatchModel match,
  ) {
    if (event.eventType == BallEventType.lineupChange) {
      return _applyLineupChange(innings, event);
    }
    if (event.eventType == BallEventType.endOver) {
      return _applyEndOver(innings, event);
    }
    if (event.eventType == BallEventType.wicketKeeperChange) {
      return _applyWicketKeeperChange(innings, event);
    }

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
      // Free hit consumed on the next legal delivery.
      isFreeHit = false;
    }

    extras += _extrasFromEvent(event);

    if (event.eventType == BallEventType.noBall && rules.freeHitEnabled) {
      isFreeHit = true;
    }

    var strikerId = innings.strikerId;
    var nonStrikerId = innings.nonStrikerId;

    var batsmen = List<BatsmanInningsModel>.from(innings.batsmen);
    var bowlers = List<BowlerInningsModel>.from(innings.bowlers);

    // Runs + end rotation before wicket when runs completed on same ball.
    if (event.eventType == BallEventType.wicket) {
      final runningRuns = event.wicketType == WicketType.runOut
          ? _runningRunsOnRunOut(event)
          : event.batsmanRuns;
      if (event.batsmanRuns > 0 && event.strikerId != null) {
        batsmen = _updateBatsman(
          batsmen,
          event.strikerId!,
          event.batsmanRuns,
          countBallFaced: _countsAsBallFaced(event),
        );
      }
      if (runningRuns.isOdd && strikerId != null && nonStrikerId != null) {
        final temp = strikerId;
        strikerId = nonStrikerId;
        nonStrikerId = temp;
      }
    }

    if (event.eventType == BallEventType.wicket && event.retiredHurt) {
      final retiredId =
          event.dismissedPlayerId ?? event.strikerId ?? strikerId;
      if (retiredId != null) {
        batsmen = _markBatsmanRetiredHurt(batsmen, retiredId);
        if (retiredId == strikerId) strikerId = null;
        if (retiredId == nonStrikerId) nonStrikerId = null;
      }
    } else if (event.eventType == BallEventType.wicket && event.isWicket) {
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

    if (event.strikerId != null) {
      final wicketRunsCredited = event.eventType == BallEventType.wicket &&
          event.batsmanRuns > 0;
      if (event.batsmanRuns > 0 &&
          event.eventType != BallEventType.wicket) {
        batsmen = _updateBatsman(
          batsmen,
          event.strikerId!,
          event.batsmanRuns,
          countBallFaced: _countsAsBallFaced(event),
        );
      } else if (_strikerFacedDelivery(event) && !wicketRunsCredited) {
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
        _bowlerGetsWicketFromEvent(event),
        isNoBall: event.eventType == BallEventType.noBall ||
            event.runOutDeliveryKind == RunOutDeliveryKind.noBall,
        isWide: event.eventType == BallEventType.wide ||
            event.runOutDeliveryKind == RunOutDeliveryKind.wide,
      );
    }

    if (event.eventType == BallEventType.wicket &&
        event.isWicket &&
        !event.retiredHurt) {
      final dismissedId =
          event.dismissedPlayerId ?? event.strikerId ?? innings.strikerId;
      if (dismissedId != null) {
        batsmen = _markBatsmanOut(
          batsmen,
          dismissedId,
          DismissalFormatter.scorecardText(event),
        );
      }
    }

    // Strike rotation on odd runs (wicket+runs handled above).
    if (event.eventType != BallEventType.wicket &&
        _shouldRotateEndsForEvent(event) &&
        strikerId != null &&
        nonStrikerId != null) {
      final temp = strikerId;
      strikerId = nonStrikerId;
      nonStrikerId = temp;
    }

    // End-of-over strike rotation is applied via [BallEventType.endOver] only.

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
      currentWicketKeeperId: innings.currentWicketKeeperId,
      currentWicketKeeperName: innings.currentWicketKeeperName,
      batsmen: batsmen,
      bowlers: bowlers,
      partnershipRuns: partnershipRuns,
      partnershipBalls: partnershipBalls,
      isFreeHitActive: isFreeHit,
      targetRuns: innings.targetRuns,
      isSuperOver: innings.isSuperOver,
      currentOverStartLegalBalls: innings.currentOverStartLegalBalls,
    );
  }

  InningsModel _applyEndOver(InningsModel innings, BallEventModel event) {
    var strikerId = innings.strikerId;
    var nonStrikerId = innings.nonStrikerId;
    if (strikerId != null && nonStrikerId != null) {
      final temp = strikerId;
      strikerId = nonStrikerId;
      nonStrikerId = temp;
    }
    return InningsModel(
      inningsNumber: innings.inningsNumber,
      battingTeamId: innings.battingTeamId,
      bowlingTeamId: innings.bowlingTeamId,
      status: innings.status,
      totalRuns: innings.totalRuns,
      totalWickets: innings.totalWickets,
      legalBalls: innings.legalBalls,
      extras: innings.extras,
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      currentBowlerId: event.bowlerId ?? innings.currentBowlerId,
      currentWicketKeeperId: innings.currentWicketKeeperId,
      currentWicketKeeperName: innings.currentWicketKeeperName,
      batsmen: innings.batsmen,
      bowlers: innings.bowlers,
      partnershipRuns: innings.partnershipRuns,
      partnershipBalls: innings.partnershipBalls,
      isFreeHitActive: false,
      targetRuns: innings.targetRuns,
      isSuperOver: innings.isSuperOver,
      currentOverStartLegalBalls: innings.legalBalls,
    );
  }

  InningsModel _applyLineupChange(InningsModel innings, BallEventModel event) {
    var batsmen = List<BatsmanInningsModel>.from(innings.batsmen);
    var bowlers = List<BowlerInningsModel>.from(innings.bowlers);

    batsmen = _upsertBatsmanSlot(
      batsmen,
      event.strikerId,
      event.lineupStrikerName,
    );
    batsmen = _upsertBatsmanSlot(
      batsmen,
      event.nonStrikerId,
      event.lineupNonStrikerName,
    );

    if (event.bowlerId != null && event.bowlerId!.isNotEmpty) {
      final idx = bowlers.indexWhere((b) => b.playerId == event.bowlerId);
      if (idx >= 0) {
        final b = bowlers[idx];
        bowlers[idx] = BowlerInningsModel(
          playerId: b.playerId,
          playerName: event.bowlerName?.isNotEmpty == true
              ? event.bowlerName!
              : b.playerName,
          oversBowledBalls: b.oversBowledBalls,
          runsConceded: b.runsConceded,
          wickets: b.wickets,
          wides: b.wides,
          noBalls: b.noBalls,
        );
      } else {
        bowlers.add(
          BowlerInningsModel(
            playerId: event.bowlerId!,
            playerName: event.bowlerName ?? '',
          ),
        );
      }
    }

    return InningsModel(
      inningsNumber: innings.inningsNumber,
      battingTeamId: innings.battingTeamId,
      bowlingTeamId: innings.bowlingTeamId,
      status: innings.status,
      totalRuns: innings.totalRuns,
      totalWickets: innings.totalWickets,
      legalBalls: innings.legalBalls,
      extras: innings.extras,
      strikerId: event.strikerId,
      nonStrikerId: event.nonStrikerId,
      currentBowlerId: event.bowlerId ?? innings.currentBowlerId,
      currentWicketKeeperId: innings.currentWicketKeeperId,
      currentWicketKeeperName: innings.currentWicketKeeperName,
      batsmen: batsmen,
      bowlers: bowlers,
      partnershipRuns: innings.partnershipRuns,
      partnershipBalls: innings.partnershipBalls,
      isFreeHitActive: innings.isFreeHitActive,
      targetRuns: innings.targetRuns,
      isSuperOver: innings.isSuperOver,
      currentOverStartLegalBalls: innings.currentOverStartLegalBalls,
    );
  }

  InningsModel _applyWicketKeeperChange(
    InningsModel innings,
    BallEventModel event,
  ) {
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
      currentWicketKeeperId: event.wicketKeeperId,
      currentWicketKeeperName: event.wicketKeeperName,
      batsmen: innings.batsmen,
      bowlers: innings.bowlers,
      partnershipRuns: innings.partnershipRuns,
      partnershipBalls: innings.partnershipBalls,
      isFreeHitActive: innings.isFreeHitActive,
      targetRuns: innings.targetRuns,
      isSuperOver: innings.isSuperOver,
      currentOverStartLegalBalls: innings.currentOverStartLegalBalls,
    );
  }

  List<BatsmanInningsModel> _upsertBatsmanSlot(
    List<BatsmanInningsModel> list,
    String? playerId,
    String? playerName,
  ) {
    if (playerId == null || playerId.isEmpty) return list;
    final idx = list.indexWhere((b) => b.playerId == playerId);
    if (idx >= 0) {
      final b = list[idx];
      list[idx] = b.copyWith(
        playerName: playerName?.isNotEmpty == true ? playerName! : b.playerName,
        retiredHurt: false,
        isEligibleToReturn: false,
        dismissalInfo: b.retiredHurt ? '' : b.dismissalInfo,
      );
      return list;
    }
    return [
      ...list,
      BatsmanInningsModel(
        playerId: playerId,
        playerName: playerName ?? '',
      ),
    ];
  }

  static String _batsmanName(InningsModel innings, String id) {
    if (id.isEmpty) return '';
    final idx = innings.batsmen.indexWhere((b) => b.playerId == id);
    if (idx < 0) return '';
    return innings.batsmen[idx].playerName;
  }

  static String _bowlerName(InningsModel innings, String id) {
    if (id.isEmpty) return '';
    for (final b in innings.bowlers) {
      if (b.playerId == id) return b.playerName;
    }
    return '';
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

    if (event.eventType == BallEventType.wicket && event.isWicket) {
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
      list[idx] = list[idx].copyWith(
        isOut: true,
        dismissalInfo: dismissal,
        retiredHurt: false,
        isEligibleToReturn: false,
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

  List<BatsmanInningsModel> _markBatsmanRetiredHurt(
    List<BatsmanInningsModel> list,
    String playerId,
  ) {
    final idx = list.indexWhere((b) => b.playerId == playerId);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(
        isOut: false,
        retiredHurt: true,
        isEligibleToReturn: true,
        dismissalInfo: 'retired hurt',
      );
    } else {
      list.add(
        BatsmanInningsModel(
          playerId: playerId,
          retiredHurt: true,
          isEligibleToReturn: true,
          dismissalInfo: 'retired hurt',
        ),
      );
    }
    return list;
  }

  /// Extras on wides / no-balls: total minus batsman; bye/LB on NB are not batsman runs.
  static int _extrasFromEvent(BallEventModel event) {
    if (event.eventType == BallEventType.wicket &&
        event.wicketType == WicketType.runOut &&
        event.runOutDeliveryKind != null &&
        event.runOutDeliveryKind != RunOutDeliveryKind.normal) {
      return event.runs - event.batsmanRuns;
    }
    switch (event.eventType) {
      case BallEventType.wide:
      case BallEventType.noBall:
        return event.runs - event.batsmanRuns;
      case BallEventType.bye:
      case BallEventType.legBye:
        return event.runs;
      case BallEventType.penalty:
        return event.runs;
      default:
        return 0;
    }
  }

  static int _runningRunsOnRunOut(BallEventModel event) {
    return switch (event.runOutDeliveryKind) {
      RunOutDeliveryKind.wide =>
        (event.runs - event.wideRuns - event.batsmanRuns).clamp(0, 999),
      RunOutDeliveryKind.noBall =>
        event.batsmanRuns + event.noBallByeRuns + event.noBallLegByeRuns,
      RunOutDeliveryKind.bye => event.byeRuns,
      RunOutDeliveryKind.legBye => event.legByeRuns,
      _ => event.batsmanRuns > 0 ? event.batsmanRuns : event.runs,
    };
  }

  static int _runsAgainstBowler(BallEventModel event) {
    if (event.eventType == BallEventType.bye ||
        event.eventType == BallEventType.legBye) {
      return 0;
    }
    if (event.eventType == BallEventType.wicket &&
        event.wicketType == WicketType.runOut) {
      return switch (event.runOutDeliveryKind) {
        RunOutDeliveryKind.bye || RunOutDeliveryKind.legBye => 0,
        _ => event.runs,
      };
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
      list[idx] = b.copyWith(balls: b.balls + 1);
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
      list[idx] = b.copyWith(
        runs: b.runs + runs,
        balls: b.balls + (countBallFaced ? 1 : 0),
        fours: b.fours + (runs == 4 ? 1 : 0),
        sixes: b.sixes + (runs == 6 ? 1 : 0),
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
    bool isWide = false,
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
        wides: b.wides + (isWide ? 1 : 0),
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
    if (innings.inningsNumber >= 2 || innings.isSuperOver) {
      target = innings.targetRuns ??
          (innings.inningsNumber >= 2 && !innings.isSuperOver
              ? _firstInningsRuns(match) + 1
              : null);
      if (target != null) {
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

  static int _firstInningsRuns(MatchModel match) {
    for (final inn in match.innings) {
      if (inn.inningsNumber == 1 && !inn.isSuperOver) return inn.totalRuns;
    }
    return match.innings.isNotEmpty ? match.innings.first.totalRuns : 0;
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
    String? openingStrikerId,
    String? openingNonStrikerId,
    String? openingBowlerId,
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
    } else if (openingStrikerId != null ||
        openingNonStrikerId != null ||
        openingBowlerId != null) {
      strikerId = openingStrikerId ?? strikerId;
      nonStrikerId = openingNonStrikerId ?? nonStrikerId;
      bowlerId = openingBowlerId ?? bowlerId;
    }

    return InningsModel(
      inningsNumber: current.inningsNumber,
      battingTeamId: current.battingTeamId,
      bowlingTeamId: current.bowlingTeamId,
      status: InningsStatus.inProgress,
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      currentBowlerId: bowlerId,
      targetRuns: current.targetRuns,
      isSuperOver: current.isSuperOver,
      batsmen: _batsmenForReplayBase(
        current: current,
        events: events,
        strikerId: strikerId,
        nonStrikerId: nonStrikerId,
      ),
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

  static List<BatsmanInningsModel> _batsmenForReplayBase({
    required InningsModel current,
    required List<BallEventModel> events,
    String? strikerId,
    String? nonStrikerId,
  }) {
    final sorted = [...events]..sort((a, b) => a.sequence.compareTo(b.sequence));
    final order = <String>[];
    final seen = <String>{};

    void addId(String? id) {
      if (id == null || id.isEmpty || seen.contains(id)) return;
      seen.add(id);
      order.add(id);
    }

    addId(strikerId);
    addId(nonStrikerId);
    for (final e in sorted) {
      addId(e.strikerId);
      addId(e.nonStrikerId);
      addId(e.dismissedPlayerId);
      if (e.eventType == BallEventType.lineupChange) {
        addId(e.strikerId);
        addId(e.nonStrikerId);
      }
    }

    final existing = {for (final b in current.batsmen) b.playerId: b};
    return order
        .map(
          (id) => BatsmanInningsModel(
            playerId: id,
            playerName: existing[id]?.playerName ??
                _playerNameFromEvents(id, sorted) ??
                '',
          ),
        )
        .toList();
  }

  static String? _playerNameFromEvents(
    String playerId,
    List<BallEventModel> events,
  ) {
    for (final e in events) {
      if (e.strikerId == playerId &&
          e.lineupStrikerName?.trim().isNotEmpty == true) {
        return e.lineupStrikerName;
      }
      if (e.nonStrikerId == playerId &&
          e.lineupNonStrikerName?.trim().isNotEmpty == true) {
        return e.lineupNonStrikerName;
      }
      if (e.nextStrikerId == playerId &&
          e.nextStrikerName?.trim().isNotEmpty == true) {
        return e.nextStrikerName;
      }
      if (e.dismissedPlayerId == playerId &&
          e.dismissedPlayerName?.trim().isNotEmpty == true) {
        return e.dismissedPlayerName;
      }
    }
    return null;
  }

  OverlayStateModel buildOverlayForMatch(MatchModel match) {
    final innings = match.currentInnings;
    if (innings == null) {
      return OverlayStateModel(matchId: match.id);
    }
    return _buildOverlay(match, innings, match.rules);
  }

  static bool _bowlerGetsWicketFromEvent(BallEventModel event) {
    if (!event.isWicket || event.eventType != BallEventType.wicket) {
      return false;
    }
    if (event.bowlerGetsWicket) return true;
    return DismissalFormatter.creditsBowlerWicket(
      event.wicketType,
      isMankad: event.isMankad,
    );
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
      wicketType: e.isMankad ? WicketType.mankad : e.wicketType,
      dismissedPlayerId: e.dismissedPlayerId,
      dismissedPlayerName: e.dismissedPlayerName,
      fielderId: e.primaryFielderId ?? e.fielderId,
      fielderName: e.primaryFielderName ?? e.fielderName,
      bowlerName: e.bowlerName,
      fielders: e.fielders,
      isMankad: e.isMankad,
      wicketKeeperId: e.wicketKeeperId,
      wicketKeeperName: e.wicketKeeperName,
      dismissalSubType: e.dismissalSubType,
      currentWicketKeeperId: e.currentWicketKeeperId,
      currentWicketKeeperName: e.currentWicketKeeperName,
      undoGroupId: e.undoGroupId,
      nextStrikerId: e.nextStrikerId,
      nextStrikerName: e.nextStrikerName,
      runOutDeliveryKind: e.runOutDeliveryKind,
      completedRuns: e.wicketType == WicketType.runOut &&
              e.runOutDeliveryKind != null &&
              e.runOutDeliveryKind != RunOutDeliveryKind.normal
          ? _completedRunsFromRunOutEvent(e)
          : e.runs,
      commentary: e.commentary,
      noBallRunsMode: e.noBallRunsMode,
      bowlerId: e.bowlerId,
      wagonWheel: e.wagonWheel,
      createdBy: e.createdBy,
      creaseStrikerId: e.eventType == BallEventType.lineupChange
          ? e.strikerId
          : null,
      creaseNonStrikerId: e.eventType == BallEventType.lineupChange
          ? e.nonStrikerId
          : null,
      creaseStrikerName: e.lineupStrikerName,
      creaseNonStrikerName: e.lineupNonStrikerName,
    );
  }

  static int _completedRunsFromRunOutEvent(BallEventModel e) {
    return switch (e.runOutDeliveryKind) {
      RunOutDeliveryKind.wide => (e.runs - e.wideRuns).clamp(0, 999),
      RunOutDeliveryKind.noBall =>
        e.batsmanRuns + e.noBallByeRuns + e.noBallLegByeRuns,
      RunOutDeliveryKind.bye => e.byeRuns,
      RunOutDeliveryKind.legBye => e.legByeRuns,
      _ => e.runs,
    };
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
    this.dismissedPlayerName,
    this.fielderId,
    this.fielderName,
    this.bowlerName,
    this.fielders = const [],
    this.isMankad = false,
    this.wicketKeeperId,
    this.wicketKeeperName,
    this.commentary = '',
    this.noBallRunsMode,
    this.bowlerId,
    this.wagonWheel,
    this.createdBy,
    this.creaseStrikerId,
    this.creaseNonStrikerId,
    this.creaseStrikerName,
    this.creaseNonStrikerName,
    this.dismissalSubType,
    this.currentWicketKeeperId,
    this.currentWicketKeeperName,
    this.undoGroupId,
    this.nextStrikerId,
    this.nextStrikerName,
    this.runOutDeliveryKind,
    this.completedRuns = 0,
  });

  final BallEventType type;
  final int runs;
  final WicketType? wicketType;
  final String? dismissedPlayerId;
  final String? dismissedPlayerName;
  final String? fielderId;
  final String? fielderName;
  final String? bowlerName;
  final List<DismissalFielder> fielders;
  final bool isMankad;
  final String? wicketKeeperId;
  final String? wicketKeeperName;
  final String commentary;
  final NoBallRunsMode? noBallRunsMode;
  /// When replaying stored balls, preserves the original bowler on the event.
  final String? bowlerId;
  final WagonWheelData? wagonWheel;
  final String? createdBy;
  /// Resulting crease after [BallEventType.lineupChange].
  final String? creaseStrikerId;
  final String? creaseNonStrikerId;
  final String? creaseStrikerName;
  final String? creaseNonStrikerName;
  final String? dismissalSubType;
  final String? currentWicketKeeperId;
  final String? currentWicketKeeperName;
  final String? undoGroupId;
  final String? nextStrikerId;
  final String? nextStrikerName;
  final RunOutDeliveryKind? runOutDeliveryKind;
  /// Runs completed before run-out (excluding wide/NB penalty).
  final int completedRuns;
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

class _RunBreakdown {
  const _RunBreakdown({
    required this.byeRuns,
    required this.legByeRuns,
    required this.wideRuns,
    required this.noBallRuns,
    required this.penaltyRuns,
  });

  final int byeRuns;
  final int legByeRuns;
  final int wideRuns;
  final int noBallRuns;
  final int penaltyRuns;
}

extension _InningsCopy on InningsModel {
  InningsModel copyWith({
    int? totalRuns,
    int? totalWickets,
    int? legalBalls,
    int? extras,
    int? currentOverStartLegalBalls,
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
      targetRuns: targetRuns,
      isSuperOver: isSuperOver,
      currentWicketKeeperId: currentWicketKeeperId,
      currentWicketKeeperName: currentWicketKeeperName,
      currentOverStartLegalBalls:
          currentOverStartLegalBalls ?? this.currentOverStartLegalBalls,
    );
  }
}
