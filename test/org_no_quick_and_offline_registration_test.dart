import 'package:cloud_functions/cloud_functions.dart';
import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/core/theme/app_theme.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/tournament_model.dart';
import 'package:crickflow/data/services/offline_sync_service.dart';
import 'package:crickflow/domain/services/tournament/tournament_match_link_policy.dart';
import 'package:crickflow/features/matches/presentation/match_type_choice_screen.dart';
import 'package:crickflow/shared/providers/tournament_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

MatchModel _m(MatchMode mode) => MatchModel(
      id: 'm',
      title: 't',
      teamAId: 'a',
      teamBId: 'b',
      matchMode: mode,
    );

const _orgT = TournamentModel(
  id: 'T',
  name: 'Org cup',
  teamIds: ['a', 'b'],
  seriesId: 's1',
  seriesOfficialStatus: 'approved',
);

Widget _choice(TournamentModel? t) => ProviderScope(
      overrides: [
        tournamentProvider('T').overrideWith((_) => Stream.value(t)),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const MatchTypeChoiceScreen(tournamentId: 'T'),
      ),
    );

void main() {
  test('org tournaments only accept normal matches', () {
    expect(isOrgTournament(_orgT), isTrue);
    expect(
      isOrgTournament(const TournamentModel(
        id: 'x', name: 'x', seriesId: 's1', seriesOfficialStatus: 'rejected',
      )),
      isFalse,
    );
    expect(
      TournamentMatchLinkPolicy.blockReason(
        _m(MatchMode.quick), const ['a', 'b'], orgTournament: true),
      contains('Quick'),
    );
    expect(
      TournamentMatchLinkPolicy.blockReason(
        _m(MatchMode.normal), const ['a', 'b'], orgTournament: true),
      isNull,
    );
    expect(
      TournamentMatchLinkPolicy.blockReason(_m(MatchMode.quick), const ['a', 'b']),
      isNull,
    );
  });

  testWidgets('start-match screen hides Quick inside an org tournament',
      (tester) async {
    await tester.pumpWidget(_choice(_orgT));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start_quick_match')), findsNothing);
    expect(find.text('Normal Match'), findsOneWidget);
  });

  testWidgets('start-match screen keeps Quick for normal tournaments',
      (tester) async {
    await tester.pumpWidget(_choice(
      const TournamentModel(id: 'T', name: 'Open cup'),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start_quick_match')), findsOneWidget);
  });

  group('org registration retry policy', () {
    FirebaseFunctionsException err(String code) =>
        FirebaseFunctionsException(code: code, message: code);

    test('transient errors and not-yet-synced matches are retried', () {
      expect(seriesRegistrationFailureOutcome(err('unavailable'), 0),
          SeriesRegistrationOutcome.retry);
      expect(seriesRegistrationFailureOutcome(err('not-found'), 3),
          SeriesRegistrationOutcome.retry);
      expect(seriesRegistrationFailureOutcome(Exception('offline'), 0),
          SeriesRegistrationOutcome.retry);
    });

    test('refusals are dropped, and retries are capped', () {
      for (final code in [
        'permission-denied',
        'failed-precondition',
        'invalid-argument',
        'already-exists',
      ]) {
        expect(seriesRegistrationFailureOutcome(err(code), 0),
            SeriesRegistrationOutcome.drop);
      }
      expect(seriesRegistrationFailureOutcome(err('unavailable'), 20),
          SeriesRegistrationOutcome.drop);
    });
  });

  test('org intent round-trips on the match document', () {
    final m = _m(MatchMode.normal).copyWith(orgRequestSeriesId: 's1');
    expect(m.toMap()['orgRequestSeriesId'], 's1');
    expect(MatchModel.fromMap('m', m.toMap()).orgRequestSeriesId, 's1');
  });
}
