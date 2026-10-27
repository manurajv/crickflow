import 'package:crickflow/core/theme/app_theme.dart';
import 'package:crickflow/data/models/match_player_snapshot.dart';
import 'package:crickflow/data/models/team_model.dart';
import 'package:crickflow/data/models/tournament_model.dart';
import 'package:crickflow/data/models/player_model.dart';
import 'package:crickflow/data/repositories/player_repository.dart';
import 'package:crickflow/domain/services/series/org_competition_access.dart';
import 'package:crickflow/domain/services/series/org_walk_ins.dart';
import 'package:crickflow/features/matches/presentation/widgets/add_match_squad_player_sheet.dart';
import 'package:crickflow/shared/providers/providers.dart';
import 'package:crickflow/shared/providers/series_providers.dart';
import 'package:crickflow/shared/providers/tournament_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

OrgCompetitionPolicy _policy({required bool walkIns}) =>
    OrgCompetitionPolicy(allowWalkIns: walkIns);

class _FakePlayers extends Fake implements PlayerRepository {
  @override
  Future<List<PlayerModel>> getPlayersByTeam(String teamId) async => const [];
}

void main() {
  group('isWalkInSnapshot', () {
    test('guests and non-registered entries are walk-ins', () {
      final guest = MatchPlayerSnapshot.matchOnly(
        name: 'G',
        playingRole: 'Batsman',
        battingStyle: 'Right Hand Bat',
        bowlingStyle: 'None',
      );
      expect(isWalkInSnapshot(guest), isTrue);
      expect(
        isWalkInSnapshot(const MatchPlayerSnapshot(
            id: 'p1', name: 'Roster', isRegisteredUser: false)),
        isTrue,
      );
      expect(
        isWalkInSnapshot(const MatchPlayerSnapshot(id: 'guest_x', name: 'X')),
        isTrue,
      );
      const reg = MatchPlayerSnapshot(id: 'p2', name: 'Reg');
      expect(isWalkInSnapshot(reg), isFalse);
      expect(walkInsIn([reg, guest]).map((p) => p.name), ['G']);
    });
  });

  group('walkInsAllowedProvider', () {
    ProviderContainer container({
      required bool walkIns,
      TournamentModel? tournament,
    }) =>
        ProviderContainer(overrides: [
          orgCompetitionPolicyProvider('s1')
              .overrideWith((_) => Stream.value(_policy(walkIns: walkIns))),
          tournamentProvider('t1').overrideWith((_) => Stream.value(tournament)),
        ]);

    test('non-org matches always allow walk-ins', () async {
      final c = container(walkIns: false);
      addTearDown(c.dispose);
      expect(c.read(walkInsAllowedProvider((seriesId: null, tournamentId: null))), isTrue);
      expect(c.read(walkInsAllowedProvider((seriesId: '', tournamentId: ''))), isTrue);
    });

    test('org matches follow the org setting', () async {
      final off = container(walkIns: false);
      addTearDown(off.dispose);
      await off.read(orgCompetitionPolicyProvider('s1').future);
      expect(off.read(walkInsAllowedProvider((seriesId: 's1', tournamentId: null))), isFalse);

      final on = container(walkIns: true);
      addTearDown(on.dispose);
      await on.read(orgCompetitionPolicyProvider('s1').future);
      expect(on.read(walkInsAllowedProvider((seriesId: 's1', tournamentId: null))), isTrue);
    });

    test('org tournament matches follow the tournament org', () async {
      final c = container(
        walkIns: false,
        tournament: const TournamentModel(
          id: 't1',
          name: 'Cup',
          seriesId: 's1',
          seriesOfficialStatus: 'approved',
        ),
      );
      addTearDown(c.dispose);
      await c.read(orgCompetitionPolicyProvider('s1').future);
      await c.read(tournamentProvider('t1').future);
      expect(c.read(walkInsAllowedProvider((seriesId: null, tournamentId: 't1'))), isFalse);
    });

    test('a plain tournament is unaffected', () async {
      final c = container(
        walkIns: false,
        tournament: const TournamentModel(id: 't1', name: 'Street Cup'),
      );
      addTearDown(c.dispose);
      await c.read(tournamentProvider('t1').future);
      expect(c.read(walkInsAllowedProvider((seriesId: null, tournamentId: 't1'))), isTrue);
    });
  });

  group('add player sheet', () {
    Future<void> open(WidgetTester tester, {required bool allowGuests}) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          playerRepositoryProvider.overrideWithValue(_FakePlayers()),
          teamByIdProvider('t1').overrideWith((_) => Stream.value(
              const TeamModel(id: 't1', name: 'Aces'))),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAddMatchSquadPlayerSheet(
                  context,
                  teamId: 't1',
                  allowGuests: allowGuests,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('guest option is offered when walk-ins are allowed',
        (tester) async {
      await open(tester, allowGuests: true);
      expect(find.text('Add match-only guest'), findsOneWidget);
    });

    testWidgets('guest option is hidden when the org bans walk-ins',
        (tester) async {
      await open(tester, allowGuests: false);
      expect(find.text('Add match-only guest'), findsNothing);
      expect(find.textContaining('Walk-in guests are not allowed'), findsOneWidget);
      expect(find.text('Invite a player'), findsOneWidget);
    });
  });
}
