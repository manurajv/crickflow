import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/core/utils/tournament_match_stage_utils.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:flutter_test/flutter_test.dart';

MatchModel _match({
  int? bracketRound,
  String? groupId,
  String? roundName,
}) {
  return MatchModel(
    id: 'm1',
    title: 'A vs B',
    matchType: MatchType.tournament,
    status: MatchStatus.scheduled,
    teamAId: 'a',
    teamBId: 'b',
    tournamentId: 't1',
    bracketRound: bracketRound,
    groupId: groupId,
    roundName: roundName,
  );
}

void main() {
  group('tournamentMatchTypeLabel', () {
    test('uses tournament format knockout when bracketRound unset', () {
      expect(
        tournamentMatchTypeLabel(
          _match(),
          tournamentFormat: TournamentFormat.knockout,
        ),
        'Knockout',
      );
    });

    test('uses knockout round type', () {
      expect(
        tournamentMatchTypeLabel(
          _match(roundName: 'Semi Final'),
          roundType: RoundType.semiFinal,
          tournamentFormat: TournamentFormat.leagueKnockout,
        ),
        'Knockout',
      );
    });

    test('keeps league for league tournaments', () {
      expect(
        tournamentMatchTypeLabel(
          _match(),
          tournamentFormat: TournamentFormat.league,
        ),
        'League',
      );
    });

    test('bracketRound still means knockout', () {
      expect(
        tournamentMatchTypeLabel(_match(bracketRound: 0)),
        'Knockout',
      );
    });
  });

  group('tournamentMatchStageLabel', () {
    test('prefers round name over generic Round N', () {
      expect(
        tournamentMatchStageLabel(
          _match(bracketRound: 0, roundName: 'Semi Final'),
          tournamentFormat: TournamentFormat.knockout,
        ),
        'Knockout · Semi Final',
      );
    });
  });

  group('shouldTagTournamentMatchAsKnockout', () {
    test('tags pure knockout tournaments', () {
      expect(
        shouldTagTournamentMatchAsKnockout(
          tournamentFormat: TournamentFormat.knockout,
        ),
        isTrue,
      );
    });

    test('does not tag league tournaments without knockout round', () {
      expect(
        shouldTagTournamentMatchAsKnockout(
          tournamentFormat: TournamentFormat.league,
        ),
        isFalse,
      );
    });

    test('tags explicit knockout round on league+ko', () {
      expect(
        shouldTagTournamentMatchAsKnockout(
          tournamentFormat: TournamentFormat.leagueKnockout,
          roundType: RoundType.final_,
        ),
        isTrue,
      );
    });
  });
}
