import 'package:flutter_test/flutter_test.dart';

import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/scoring/local_match_overlay.dart';

void main() {
  MatchModel match({
    required MatchStatus status,
    int overlayVersion = 0,
  }) {
    return MatchModel(
      id: 'm1',
      title: 'A vs B',
      status: status,
      teamAName: 'A',
      teamBName: 'B',
      rules: const MatchRulesModel(),
      overlayVersion: overlayVersion,
    );
  }

  test('local completed beats remote live even with a higher overlay version', () {
    final local = match(
      status: MatchStatus.completed,
      overlayVersion: 2,
    );
    final remote = match(
      status: MatchStatus.live,
      overlayVersion: 9,
    );

    expect(LocalMatchOverlay.isTerminalAhead(local, remote), isTrue);
    expect(
      LocalMatchOverlay.preferLocal(
        local: local,
        remote: remote,
        pendingSync: false,
      ),
      isTrue,
    );
  });

  test('pending local snapshot is authoritative while still live', () {
    final local = match(status: MatchStatus.live, overlayVersion: 4);
    final remote = match(status: MatchStatus.live, overlayVersion: 8);

    expect(
      LocalMatchOverlay.preferLocal(
        local: local,
        remote: remote,
        pendingSync: true,
      ),
      isTrue,
    );
  });

  test('remote completed is not replaced by a stale live snapshot', () {
    final local = match(status: MatchStatus.live);
    final remote = match(status: MatchStatus.completed);

    expect(LocalMatchOverlay.isTerminalAhead(local, remote), isFalse);
    expect(
      LocalMatchOverlay.preferLocal(
        local: local,
        remote: remote,
        pendingSync: false,
      ),
      isFalse,
    );
  });
}
