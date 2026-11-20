import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/core/utils/match_setup_navigation.dart';
import 'package:crickflow/data/models/match_setup_draft_models.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/team_model.dart';
import 'package:crickflow/domain/services/tournament/tournament_match_link_policy.dart';
import 'package:crickflow/shared/providers/start_match_draft_provider.dart';
import 'package:flutter_test/flutter_test.dart';

MatchModel _m(String id, {String? a = 'a', String? b = 'b', String? tid}) =>
    MatchModel(
      id: id,
      title: 't',
      teamAId: a,
      teamBId: b,
      tournamentId: tid,
      matchMode: MatchMode.quick,
    );

void main() {
  const teams = ['a', 'b', 'c'];

  group('TournamentMatchLinkPolicy', () {
    test('eligible when both teams are in the tournament and unlinked', () {
      expect(TournamentMatchLinkPolicy.blockReason(_m('1'), teams), isNull);
    });

    test('blocks matches already in a tournament', () {
      expect(
        TournamentMatchLinkPolicy.blockReason(_m('1', tid: 't2'), teams),
        isNotNull,
      );
    });

    test('blocks teams outside the tournament or ad-hoc teams', () {
      expect(
        TournamentMatchLinkPolicy.blockReason(_m('1', b: 'z'), teams),
        isNotNull,
      );
      expect(
        TournamentMatchLinkPolicy.blockReason(_m('1', b: null), teams),
        isNotNull,
      );
    });

    test('linkable filters and de-duplicates', () {
      final list = TournamentMatchLinkPolicy.linkable(
        [_m('1'), _m('1'), _m('2', tid: 'x'), _m('3', a: 'c')],
        teams,
      );
      expect(list.map((m) => m.id), ['1', '3']);
    });
  });

  group('tournamentTeamsError (start match inside a tournament)', () {
    StartMatchDraft draft({String? tid, String a = 'a', String b = 'b'}) =>
        StartMatchDraft(
          matchId: 'm',
          tournamentId: tid,
          teamA: TeamModel(id: a, name: 'A'),
          teamB: TeamModel(id: b, name: 'B'),
        );

    test('non-tournament drafts are not restricted', () {
      expect(tournamentTeamsError(draft(b: 'z'), teams), isNull);
    });

    test('tournament drafts require tournament teams', () {
      expect(tournamentTeamsError(draft(tid: 't1'), teams), isNull);
      expect(tournamentTeamsError(draft(tid: 't1', b: 'z'), teams), isNotNull);
    });
  });

  group('buildMatchAfterToss', () {
    StartMatchDraft draft(String? tid) => StartMatchDraft(
          matchId: 'm',
          matchMode: MatchMode.quick,
          tournamentId: tid,
          teamA: const TeamModel(id: 'a', name: 'A'),
          teamB: const TeamModel(id: 'b', name: 'B'),
        );

    test('quick match started in a tournament is a tournament match', () {
      final match = buildMatchAfterToss(
        draft: draft('t1'),
        setup: const MatchSetupData(),
        existing: null,
      );
      expect(match.tournamentId, 't1');
      expect(match.matchType, MatchType.tournament);
    });

    test('standalone quick match stays single', () {
      final match = buildMatchAfterToss(
        draft: draft(null),
        setup: const MatchSetupData(),
        existing: null,
      );
      expect(match.tournamentId, isNull);
      expect(match.matchType, MatchType.single);
    });
  });
}
