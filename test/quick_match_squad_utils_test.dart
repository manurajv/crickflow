import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/core/utils/quick_match_squad_utils.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/lineup_player.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_player_snapshot.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/data/models/match_setup_draft_models.dart';
import 'package:flutter_test/flutter_test.dart';

MatchModel _quickMatch({
  List<InningsModel> innings = const [],
  MatchSetupData? setup,
}) {
  return MatchModel(
    id: 'm1',
    title: 'A vs B',
    matchType: MatchType.single,
    matchMode: MatchMode.quick,
    status: MatchStatus.live,
    teamAId: 'team_a',
    teamBId: 'team_b',
    teamAName: 'Alpha',
    teamBName: 'Beta',
    rules: const MatchRulesModel(ballsPerOver: 6),
    setup: setup,
    innings: innings,
  );
}

void main() {
  group('matchTeamIsTeamA', () {
    test('recognises typed team ids', () {
      final match = _quickMatch();
      expect(matchTeamIsTeamA(match, 'team_a'), isTrue);
      expect(matchTeamIsTeamA(match, 'team_b'), isFalse);
    });

    test('recognises registered team uuids', () {
      final match = _quickMatch().copyWith(
        teamAId: 'uuid-a',
        teamBId: 'uuid-b',
      );
      expect(matchTeamIsTeamA(match, 'uuid-a'), isTrue);
      expect(matchTeamIsTeamA(match, 'uuid-b'), isFalse);
    });
  });

  group('buildQuickMatchTeamSquad', () {
    test('includes only players from the requested team across innings', () {
      const first = InningsModel(
        inningsNumber: 1,
        battingTeamId: 'team_a',
        bowlingTeamId: 'team_b',
        batsmen: [
          BatsmanInningsModel(playerId: 'a1', playerName: 'Alpha One'),
        ],
        bowlers: [
          BowlerInningsModel(playerId: 'b1', playerName: 'Beta One'),
        ],
      );
      const second = InningsModel(
        inningsNumber: 2,
        battingTeamId: 'team_b',
        bowlingTeamId: 'team_a',
        batsmen: [
          BatsmanInningsModel(playerId: 'b2', playerName: 'Beta Two'),
        ],
        bowlers: [
          BowlerInningsModel(playerId: 'a2', playerName: 'Alpha Two'),
        ],
      );
      final match = _quickMatch(innings: [first, second]);

      final teamA = buildQuickMatchTeamSquad(
        match: match,
        teamId: 'team_a',
        loadedRoster: const [],
      );
      final teamB = buildQuickMatchTeamSquad(
        match: match,
        teamId: 'team_b',
        loadedRoster: const [],
      );

      expect(teamA.map((p) => p.id), containsAll(['a1', 'a2']));
      expect(teamA.map((p) => p.id), isNot(contains('b1')));
      expect(teamA.map((p) => p.id), isNot(contains('b2')));

      expect(teamB.map((p) => p.id), containsAll(['b1', 'b2']));
      expect(teamB.map((p) => p.id), isNot(contains('a1')));
      expect(teamB.map((p) => p.id), isNot(contains('a2')));
    });

    test('merges registered roster with match-only setup and innings usage', () {
      final setup = MatchSetupData(
        teamAPlayingPlayers: [
          const MatchPlayerSnapshot(id: 'reg1', name: 'Registered One'),
          MatchPlayerSnapshot.matchOnly(
            name: 'Walk-in A',
            playingRole: '',
            battingStyle: '',
            bowlingStyle: '',
          ),
        ],
      );
      final match = _quickMatch(setup: setup);
      final roster = [
        const LineupPlayer(id: 'reg1', name: 'Registered One'),
        const LineupPlayer(id: 'reg2', name: 'Registered Two'),
      ];

      final squad = buildQuickMatchTeamSquad(
        match: match,
        teamId: 'team_a',
        loadedRoster: roster,
      );

      expect(squad.map((p) => p.id), containsAll(['reg1', 'reg2']));
      expect(
        squad.any((p) => p.name == 'Walk-in A'),
        isTrue,
      );
    });
  });

  group('quickMatchWalkInsForTeam', () {
    test('returns match-only setup players not already listed', () {
      final walkIn = MatchPlayerSnapshot.matchOnly(
        name: 'Guest',
        playingRole: '',
        battingStyle: '',
        bowlingStyle: '',
      );
      final setup = MatchSetupData(
        teamBPlayingPlayers: [walkIn],
      );
      final match = _quickMatch(setup: setup);
      final listed = [
        const LineupPlayer(id: 'listed', name: 'Listed'),
      ];

      final walkIns = quickMatchWalkInsForTeam(
        match: match,
        teamId: 'team_b',
        teamPlayers: listed,
      );

      expect(walkIns, hasLength(1));
      expect(walkIns.first.id, walkIn.id);
      expect(walkIns.first.name, 'Guest');
    });
  });

  group('buildBowlerPickerSubtitles', () {
    test('formats overs runs and wickets', () {
      const inn = InningsModel(
        inningsNumber: 1,
        battingTeamId: 'team_a',
        bowlingTeamId: 'team_b',
        bowlers: [
          BowlerInningsModel(
            playerId: 'b1',
            playerName: 'Bowler',
            oversBowledBalls: 13,
            runsConceded: 24,
            wickets: 2,
          ),
        ],
      );

      final subtitles = buildBowlerPickerSubtitles(inn, 6);
      expect(subtitles['b1'], '2.1 overs · 24 runs · 2 wkts');
    });
  });
}
