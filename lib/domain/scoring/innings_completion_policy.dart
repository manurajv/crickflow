import 'dart:math';

import '../../core/constants/enums.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_rules_model.dart';

/// Why an innings ended (or would end).
enum InningsEndReason {
  oversComplete,
  allOut,
  targetReached,
  manuallyEnded,
  declared,
}

/// Pure rules for when an innings is complete.
class InningsCompletionPolicy {
  InningsCompletionPolicy._();

  static InningsModel? firstInnings(MatchModel match) {
    for (final inn in match.innings) {
      if (inn.inningsNumber == 1 && !inn.isSuperOver) return inn;
    }
    return null;
  }

  /// Chase target for [inn]; prefers stored [InningsModel.targetRuns].
  static int chaseTarget(MatchModel match, InningsModel inn) {
    if (inn.targetRuns != null && inn.targetRuns! > 0) return inn.targetRuns!;
    if (inn.isSuperOver) return 0;
    final first = firstInnings(match);
    if (first == null) return 0;
    return first.totalRuns + 1;
  }

  static int targetRuns(MatchModel match, {InningsModel? chaseInn}) {
    if (chaseInn != null) return chaseTarget(match, chaseInn);
    final first = firstInnings(match);
    if (first == null) return 0;
    return first.totalRuns + 1;
  }

  static int remainingRuns(MatchModel match, InningsModel inn) {
    final target = chaseTarget(match, inn);
    if (target <= 0) return 0;
    return max(0, target - inn.totalRuns);
  }

  static int remainingBalls(MatchModel match, InningsModel inn) {
    final rules = effectiveRules(match, inn);
    // Quick Match: allot balls by overs so a long earlier over does not
    // shorten the last over (and a short over does not lengthen it).
    if (match.isQuickMatch && inn.currentOverNumber > 0) {
      final completedOvers = max(0, inn.currentOverNumber - 1);
      final ballsInOver =
          max(0, inn.legalBalls - inn.currentOverStartLegalBalls);
      final oversLeftAfterThis =
          max(0, rules.totalOvers - completedOvers - 1);
      final ballsLeftThisOver =
          max(0, rules.ballsPerOver - ballsInOver);
      return oversLeftAfterThis * rules.ballsPerOver + ballsLeftThisOver;
    }
    return max(0, rules.totalBalls - inn.legalBalls);
  }

  /// Rules applied to this innings (super over overrides).
  static MatchRulesModel effectiveRules(MatchModel match, InningsModel inn) {
    if (inn.isSuperOver) return MatchRulesModel.superOver();
    return match.rules;
  }

  static int maxDismissals(MatchModel match, InningsModel inn) {
    final rules = effectiveRules(match, inn);
    final fromRules = rules.playersPerTeam > 0
        ? rules.playersPerTeam - 1
        : rules.maxWickets;

    // Quick Match adds players during scoring — configured team size applies.
    if (match.isQuickMatch) {
      return min(rules.maxWickets, fromRules);
    }

    final setup = match.setup;
    var squadSize = rules.playersPerTeam;
    if (setup != null) {
      final isTeamA = inn.battingTeamId == match.teamAId;
      final ids = setup.squadIdsForTeam(isTeamA);
      if (ids.isNotEmpty) squadSize = ids.length;
    }
    final fromSquad = squadSize > 0 ? squadSize - 1 : rules.maxWickets;
    return min(rules.maxWickets, fromSquad);
  }

  static bool isAllOut(MatchModel match, InningsModel inn) {
    if (inn.totalWickets >= maxDismissals(match, inn)) return true;
    return noBattersAvailable(match, inn);
  }

  /// True when the crease cannot be filled from the playing squad (normal matches).
  static bool noBattersAvailable(MatchModel match, InningsModel inn) {
    return _noBattersAvailable(match, inn);
  }

  static bool _noBattersAvailable(MatchModel match, InningsModel inn) {
    // Quick Match always allows picking new batters until the wicket cap is hit.
    if (match.isQuickMatch) return false;

    final setup = match.setup;
    if (setup == null) return false;

    final isTeamA = inn.battingTeamId == match.teamAId;
    final squadIds = setup.squadIdsForTeam(isTeamA);
    if (squadIds.isEmpty) return false;

    final notOut = squadIds.where((id) => !_isPlayerOut(inn, id)).toSet();
    if (notOut.isEmpty) return true;

    if (inn.strikerId != null && inn.nonStrikerId != null) return false;

    final onCrease = {
      if (inn.strikerId != null) inn.strikerId!,
      if (inn.nonStrikerId != null) inn.nonStrikerId!,
    };
    return notOut.difference(onCrease).isEmpty;
  }

  static bool _isPlayerOut(InningsModel inn, String playerId) {
    for (final b in inn.batsmen) {
      if (b.playerId == playerId) return b.isOut;
    }
    return false;
  }

  static bool isOversComplete(MatchModel match, InningsModel inn) {
    final rules = effectiveRules(match, inn);
    if (rules.totalOvers <= 0) return false;

    // Quick Match: each over counts as one toward totalOvers (via endOver /
    // currentOverNumber), so the last over still gets a full ballsPerOver
    // even if an earlier over was 4 or 7 balls.
    if (match.isQuickMatch && inn.currentOverNumber > 0) {
      final completedOvers = max(0, inn.currentOverNumber - 1);
      if (completedOvers >= rules.totalOvers) return true;
      final ballsInOver =
          max(0, inn.legalBalls - inn.currentOverStartLegalBalls);
      if (completedOvers == rules.totalOvers - 1 &&
          ballsInOver >= rules.ballsPerOver) {
        return true;
      }
      return false;
    }

    return inn.legalBalls >= rules.totalBalls;
  }

  static bool isTargetReached(MatchModel match, InningsModel inn) {
    final target = chaseTarget(match, inn);
    if (target <= 0) return false;
    return inn.totalRuns >= target;
  }

  static bool isInningsComplete(MatchModel match, InningsModel inn) {
    if (inn.status == InningsStatus.completed) return true;
    if (isTargetReached(match, inn)) return true;
    if (isAllOut(match, inn)) return true;
    if (isOversComplete(match, inn)) return true;
    return false;
  }

  static InningsEndReason? _storedEndReason(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return switch (raw.trim().toLowerCase()) {
      'all_out' || 'allout' => InningsEndReason.allOut,
      'declared' || 'declare' => InningsEndReason.declared,
      'penalty' => InningsEndReason.manuallyEnded,
      'manually_ended' || 'manuallyended' => InningsEndReason.manuallyEnded,
      _ => InningsEndReason.manuallyEnded,
    };
  }

  static InningsEndReason? endReason(MatchModel match, InningsModel inn) {
    if (inn.status == InningsStatus.completed) {
      final stored = _storedEndReason(inn.endReason);
      if (stored != null) return stored;
    }
    if (isTargetReached(match, inn)) return InningsEndReason.targetReached;
    if (isAllOut(match, inn)) return InningsEndReason.allOut;
    if (isOversComplete(match, inn)) return InningsEndReason.oversComplete;
    return null;
  }

  /// Label shown only when the scorer manually ended the innings.
  static String endReasonLabel(MatchModel match, InningsModel inn) {
    if (inn.status != InningsStatus.completed) return '';
    final raw = inn.endReason?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) return '';

    return switch (raw) {
      'penalty' => () {
        if (inn.penaltyReason.isNotEmpty) {
          return 'Penalty (${inn.penaltyReason})';
        }
        if (inn.penaltyRuns != 0) {
          final sign = inn.penaltyRuns > 0 ? '+' : '';
          return 'Penalty $sign${inn.penaltyRuns} runs';
        }
        return 'Penalty applied';
      }(),
      'declared' || 'declare' => 'Declared',
      'all_out' || 'allout' => 'All out',
      'manually_ended' || 'manuallyended' => 'Innings ended',
      _ => 'Innings ended',
    };
  }

  /// Full completion reason for scorer dialogs (includes natural endings).
  static String completionReasonLabel(MatchModel match, InningsModel inn) {
    if (inn.status == InningsStatus.completed) {
      final manual = endReasonLabel(match, inn);
      if (manual.isNotEmpty) return manual;
    }
    return switch (endReason(match, inn)) {
      InningsEndReason.targetReached => 'Target reached',
      InningsEndReason.allOut => 'All out',
      InningsEndReason.oversComplete => 'Overs complete',
      InningsEndReason.manuallyEnded => 'Innings ended',
      InningsEndReason.declared => 'Declared',
      null => '',
    };
  }

  /// Score line with optional completion reason, e.g. `120/8 (15.0 Ov) · All out`.
  static String scoreLineWithReason(
    MatchModel match,
    InningsModel inn, {
    required String overs,
  }) {
    final base = '${inn.totalRuns}/${inn.totalWickets} ($overs Ov)';
    if (inn.status != InningsStatus.completed) return base;
    final reason = endReasonLabel(match, inn);
    if (reason.isEmpty) return base;
    return '$base · $reason';
  }
}
