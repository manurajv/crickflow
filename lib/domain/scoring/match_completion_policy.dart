import '../../core/constants/enums.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import 'innings_completion_policy.dart';

enum MatchResultMethod { runs, wickets, tie, noResult, superOverPending }

/// Computed match outcome from completed innings.
class MatchResult {
  const MatchResult({
    this.winnerTeamId,
    required this.summary,
    required this.method,
    this.marginRuns,
    this.marginWickets,
    this.isTie = false,
    this.offerSuperOver = false,
  });

  final String? winnerTeamId;
  final String summary;
  final MatchResultMethod method;
  final int? marginRuns;
  final int? marginWickets;
  final bool isTie;
  final bool offerSuperOver;
}

class MatchCompletionPolicy {
  MatchCompletionPolicy._();

  static InningsModel? _regularInnings(MatchModel match, int number) {
    for (final inn in match.innings) {
      if (inn.inningsNumber == number && !inn.isSuperOver) return inn;
    }
    return null;
  }

  static String teamName(MatchModel match, String? teamId) {
    if (teamId == match.teamAId) return match.teamAName;
    if (teamId == match.teamBId) return match.teamBName;
    return 'Team';
  }

  /// Result from two completed regular innings (or super-over pair).
  static MatchResult? resultFromInnings({
    required MatchModel match,
    required InningsModel first,
    required InningsModel second,
  }) {
    final firstRuns = first.totalRuns;
    final secondRuns = second.totalRuns;
    final chaseTeamId = second.battingTeamId;
    final defendTeamId = second.bowlingTeamId;
    final maxW = InningsCompletionPolicy.maxDismissals(match, second);

    if (secondRuns >= firstRuns + 1) {
      final wicketsLost = second.totalWickets;
      final wicketsRemaining = maxW - wicketsLost;
      final winner = teamName(match, chaseTeamId);
      return MatchResult(
        winnerTeamId: chaseTeamId,
        summary: '$winner won by $wicketsRemaining wicket${wicketsRemaining == 1 ? '' : 's'}',
        method: MatchResultMethod.wickets,
        marginWickets: wicketsRemaining,
      );
    }

    if (secondRuns < firstRuns) {
      final margin = firstRuns - secondRuns;
      final winner = teamName(match, defendTeamId);
      return MatchResult(
        winnerTeamId: defendTeamId,
        summary: '$winner won by $margin run${margin == 1 ? '' : 's'}',
        method: MatchResultMethod.runs,
        marginRuns: margin,
      );
    }

    // Scores level after chase innings complete.
    if (match.rules.superOverEnabled &&
        !first.isSuperOver &&
        !second.isSuperOver &&
        match.innings.where((i) => i.isSuperOver).isEmpty) {
      return const MatchResult(
        summary: 'Match tied — super over available',
        method: MatchResultMethod.superOverPending,
        isTie: true,
        offerSuperOver: true,
      );
    }

    return const MatchResult(
      summary: 'Match tied',
      method: MatchResultMethod.tie,
      isTie: true,
    );
  }

  /// Best-effort result from whatever innings exist on the match doc.
  static MatchResult compute(MatchModel match) {
    final regular = match.innings.where((i) => !i.isSuperOver).toList();
    final superOvers = match.innings.where((i) => i.isSuperOver).toList();

    if (superOvers.length >= 2) {
      final so1 = superOvers.first;
      final so2 = superOvers.length > 1 ? superOvers[1] : null;
      if (so2 != null &&
          so1.status == InningsStatus.completed &&
          so2.status == InningsStatus.completed) {
        return resultFromInnings(match: match, first: so1, second: so2) ??
            const MatchResult(
              summary: 'Super over tied',
              method: MatchResultMethod.tie,
              isTie: true,
            );
      }
    }

    if (regular.length >= 2) {
      final first = _regularInnings(match, 1) ?? regular.first;
      final second = _regularInnings(match, 2) ?? regular[1];
      if (first.status == InningsStatus.completed &&
          second.status == InningsStatus.completed) {
        final r = resultFromInnings(match: match, first: first, second: second);
        if (r != null) return r;
      }
    }

    if (regular.length == 1 && regular.first.status == InningsStatus.completed) {
      final winner = teamName(match, regular.first.battingTeamId);
      return MatchResult(
        winnerTeamId: regular.first.battingTeamId,
        summary: '$winner wins (single innings)',
        method: MatchResultMethod.runs,
      );
    }

    return const MatchResult(
      summary: 'Match completed',
      method: MatchResultMethod.noResult,
    );
  }

  static bool shouldOfferSuperOver(MatchModel match) {
    final r = compute(match);
    return r.offerSuperOver;
  }

  /// Tie detected while 2nd innings is ending (before status = completed).
  static bool isTiedChaseComplete(MatchModel match, InningsModel inn) {
    if (!match.rules.superOverEnabled || inn.isSuperOver || inn.inningsNumber != 2) {
      return false;
    }
    if (match.innings.where((i) => i.isSuperOver).isNotEmpty) return false;
    final first = _regularInnings(match, 1);
    if (first == null || first.status != InningsStatus.completed) return false;
    if (!InningsCompletionPolicy.isInningsComplete(match, inn)) return false;
    return inn.totalRuns == first.totalRuns;
  }

  static bool isMatchComplete(MatchModel match) {
    if (match.rules.maxInnings <= 1) {
      final inn = match.currentInnings;
      return inn != null &&
          InningsCompletionPolicy.isInningsComplete(match, inn);
    }

    final regular = match.innings.where((i) => !i.isSuperOver).toList();
    if (regular.length < 2) return false;

    final second = regular.length >= 2 ? regular[1] : null;
    if (second == null) return false;

    if (second.status != InningsStatus.completed &&
        !InningsCompletionPolicy.isInningsComplete(match, second)) {
      return false;
    }

    final result = compute(match);
    if (result.offerSuperOver) return false;
    return true;
  }
}
