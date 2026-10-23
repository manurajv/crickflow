import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/core/utils/match_update_merge.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/domain/scoring/innings_transition_overlay.dart';
import 'package:crickflow/domain/services/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _first = InningsModel(
  inningsNumber: 1,
  battingTeamId: 'a',
  bowlingTeamId: 'b',
  status: InningsStatus.completed,
  totalRuns: 142,
  totalWickets: 6,
  legalBalls: 120,
);

MatchModel _breakMatch() => MatchModel(
      id: 'm1',
      title: 'A vs B',
      teamAId: 'a',
      teamBId: 'b',
      teamAName: 'Alpha',
      teamBName: 'Bravo',
      status: MatchStatus.inningsBreak,
      overlayVersion: 40,
      innings: const [_first],
    );

MatchModel _chaseStarted() => _breakMatch().copyWith(
      status: MatchStatus.live,
      overlayVersion: 41,
      currentInningsIndex: 1,
      innings: const [
        _first,
        InningsModel(
          inningsNumber: 2,
          battingTeamId: 'b',
          bowlingTeamId: 'a',
          status: InningsStatus.notStarted,
          targetRuns: 143,
        ),
      ],
    );

void main() {
  final engine = ScoringEngine();

  group('InningsTransitionOverlay', () {
    test('innings break overlay reports the break', () {
      final overlay = InningsTransitionOverlay.build(engine, _breakMatch())!;
      expect(overlay.matchStatus, MatchStatus.inningsBreak.name);
      expect(overlay.version, 40);
    });

    test('starting the chase switches the overlay to the 2nd innings', () {
      final overlay = InningsTransitionOverlay.build(engine, _chaseStarted())!;
      expect(overlay.battingTeamName, 'Bravo');
      expect(overlay.totalRuns, 0);
      expect(overlay.legalBalls, 0);
      expect(overlay.target, 143);
      expect(overlay.matchStatus, MatchStatus.live.name);
      // Newer version so viewers' local/remote pickers prefer it.
      expect(overlay.version, greaterThan(40));
    });

    test('no overlay before scoring starts', () {
      final scheduled = _breakMatch().copyWith(status: MatchStatus.scheduled);
      expect(InningsTransitionOverlay.build(engine, scheduled), isNull);
    });
  });

  group('offline merge advances innings', () {
    test('appending the chase innings is not treated as a regression', () {
      final merged = MatchUpdateMerge.merge(_breakMatch(), _chaseStarted());
      expect(merged.innings, hasLength(2));
      expect(merged.currentInningsIndex, 1);
      expect(merged.status, MatchStatus.live);
      expect(merged.currentInnings?.inningsNumber, 2);
    });
  });
}
