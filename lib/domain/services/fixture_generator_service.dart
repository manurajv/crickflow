import 'dart:math' as math;

import '../../core/constants/enums.dart';
import '../../data/models/bracket_models.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_rules_model.dart';
import '../../data/models/tournament_model.dart';

/// Generates round-robin league fixtures for a tournament.
class FixtureGeneratorService {
  List<({String teamAId, String teamBId, String teamAName, String teamBName})>
      roundRobinPairings(List<({String id, String name})> teams) {
    final pairings = <({String teamAId, String teamBId, String teamAName, String teamBName})>[];
    for (var i = 0; i < teams.length; i++) {
      for (var j = i + 1; j < teams.length; j++) {
        pairings.add((
          teamAId: teams[i].id,
          teamBId: teams[j].id,
          teamAName: teams[i].name,
          teamBName: teams[j].name,
        ));
      }
    }
    return pairings;
  }

  List<MatchModel> buildLeagueMatches({
    required TournamentModel tournament,
    required List<({String id, String name})> teams,
    required String createdBy,
    MatchRulesModel rules = const MatchRulesModel(),
    String? roundId,
    String? groupId,
    String? roundName,
    DateTime? scheduleStart,
  }) {
    final pairings = roundRobinPairings(teams);
    final start = scheduleStart ?? DateTime.now();

    return pairings.asMap().entries.map((entry) {
      final i = entry.key;
      final p = entry.value;
      return MatchModel(
        id: '',
        title: '${tournament.name} — ${p.teamAName} vs ${p.teamBName}',
        matchType: MatchType.tournament,
        status: MatchStatus.scheduled,
        teamAId: p.teamAId,
        teamBId: p.teamBId,
        teamAName: p.teamAName,
        teamBName: p.teamBName,
        tournamentId: tournament.id,
        roundId: roundId,
        groupId: groupId,
        roundName: roundName,
        rules: rules,
        location: tournament.location,
        scheduledAt: start.add(Duration(days: i)),
        createdBy: createdBy,
      );
    }).toList();
  }

  /// Round-robin fixtures per group (Group A, B, …).
  List<MatchModel> buildGroupStageMatches({
    required TournamentModel tournament,
    required Map<String, ({String id, String name, List<({String id, String name})> teams})> groups,
    required String createdBy,
    MatchRulesModel rules = const MatchRulesModel(),
    String? roundId,
    String? roundName,
    DateTime? scheduleStart,
  }) {
    final all = <MatchModel>[];
    var dayOffset = 0;
    final start = scheduleStart ?? DateTime.now();

    for (final group in groups.values) {
      final pairings = roundRobinPairings(group.teams);
      for (final p in pairings) {
        all.add(
          MatchModel(
            id: '',
            title: '${tournament.name} (${group.name}) — ${p.teamAName} vs ${p.teamBName}',
            matchType: MatchType.tournament,
            status: MatchStatus.scheduled,
            teamAId: p.teamAId,
            teamBId: p.teamBId,
            teamAName: p.teamAName,
            teamBName: p.teamBName,
            tournamentId: tournament.id,
            roundId: roundId,
            groupId: group.id,
            roundName: roundName ?? group.name,
            rules: rules,
            location: tournament.location,
            scheduledAt: start.add(Duration(days: dayOffset)),
            createdBy: createdBy,
          ),
        );
        dayOffset++;
      }
    }
    return all;
  }

  int nextPowerOfTwo(int n) {
    if (n <= 1) return 2;
    var p = 1;
    while (p < n) {
      p *= 2;
    }
    return p;
  }

  int knockoutRoundCount(int teamCount) {
    final size = nextPowerOfTwo(teamCount);
    return (math.log(size) / math.ln2).round();
  }

  /// Pads with byes (null team B) to the next power of two, then pairs 1v2, 3v4, ...
  List<({String? teamAId, String? teamBId, String teamAName, String teamBName})>
      knockoutFirstRoundPairings(List<({String id, String name})> teams) {
    final size = nextPowerOfTwo(teams.length);
    final slots = <({String id, String name})?>[];
    slots.addAll(teams);
    while (slots.length < size) {
      slots.add(null);
    }

    final pairings = <({
      String? teamAId,
      String? teamBId,
      String teamAName,
      String teamBName
    })>[];

    for (var i = 0; i < slots.length; i += 2) {
      final a = slots[i];
      final b = slots[i + 1];
      if (a == null && b == null) continue;
      if (a != null && b == null) {
        pairings.add((
          teamAId: a.id,
          teamBId: null,
          teamAName: a.name,
          teamBName: 'BYE',
        ));
      } else if (a == null && b != null) {
        pairings.add((
          teamAId: b.id,
          teamBId: null,
          teamAName: b.name,
          teamBName: 'BYE',
        ));
      } else {
        pairings.add((
          teamAId: a!.id,
          teamBId: b!.id,
          teamAName: a.name,
          teamBName: b.name,
        ));
      }
    }
    return pairings;
  }

  List<MatchModel> buildKnockoutRoundOneMatches({
    required TournamentModel tournament,
    required List<({String id, String name})> teams,
    required String createdBy,
    MatchRulesModel rules = const MatchRulesModel(),
  }) {
    final pairings = knockoutFirstRoundPairings(teams);
    final now = DateTime.now();

    return pairings.asMap().entries.map((entry) {
      final slot = entry.key;
      final p = entry.value;
      final isBye = p.teamBName == 'BYE';

      return MatchModel(
        id: '',
        title: isBye
            ? '${tournament.name} — ${p.teamAName} (bye)'
            : '${tournament.name} — ${p.teamAName} vs ${p.teamBName}',
        matchType: MatchType.tournament,
        status: isBye ? MatchStatus.completed : MatchStatus.scheduled,
        teamAId: p.teamAId,
        teamBId: isBye ? null : p.teamBId,
        teamAName: p.teamAName,
        teamBName: isBye ? 'BYE' : p.teamBName,
        tournamentId: tournament.id,
        bracketRound: 0,
        bracketSlot: slot,
        winnerTeamId: isBye ? p.teamAId : null,
        resultSummary: isBye ? '${p.teamAName} advances (bye)' : '',
        rules: rules,
        location: tournament.location,
        scheduledAt: now.add(Duration(days: slot)),
        createdBy: createdBy,
      );
    }).toList();
  }

  /// Empty TBD slots for rounds after round 1.
  List<List<BracketSlotModel>> buildBracketSkeleton({
    required int teamCount,
    required List<BracketSlotModel> roundOneSlots,
  }) {
    final roundCount = knockoutRoundCount(teamCount);
    final rounds = <List<BracketSlotModel>>[roundOneSlots];

    var slotsInRound = nextPowerOfTwo(teamCount) ~/ 2;
    for (var r = 1; r < roundCount; r++) {
      slotsInRound = slotsInRound ~/ 2;
      rounds.add(List.generate(
        slotsInRound,
        (_) => const BracketSlotModel(
          teamAName: 'TBD',
          teamBName: 'TBD',
        ),
      ));
    }
    return rounds;
  }
}
