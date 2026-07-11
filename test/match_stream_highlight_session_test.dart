import 'package:flutter_test/flutter_test.dart';

import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/stream_playback_entry_model.dart';
import 'package:crickflow/domain/streaming/match_stream_playback.dart';

MatchModel _matchWithSessions(List<StreamPlaybackEntryModel> entries) {
  return MatchModel(
    id: 'm1',
    title: 'Test',
    teamAName: 'A',
    teamBName: 'B',
    status: MatchStatus.live,
    stream: StreamMetadataModel(
      status: StreamStatus.live,
      playbackEntries: entries,
    ),
  );
}

void main() {
  test('resolveSessionForHighlight matches marker session id', () {
    final match = _matchWithSessions([
      StreamPlaybackEntryModel(
        sessionId: 'sess-old',
        url: 'https://www.youtube.com/watch?v=old',
        addedAt: DateTime(2026, 3, 9, 8),
        endedAt: DateTime(2026, 3, 9, 9),
        isLive: false,
      ),
      StreamPlaybackEntryModel(
        sessionId: 'sess-new',
        url: 'https://www.youtube.com/watch?v=new',
        addedAt: DateTime(2026, 3, 9, 10),
        isLive: true,
      ),
    ]);

    final resolved = MatchStreamPlayback.resolveSessionForHighlight(
      match,
      sessionId: 'sess-old',
    );

    expect(resolved?.sessionId, 'sess-old');
    expect(resolved?.url, contains('v=old'));
  });

  test('resolveSessionForHighlight picks session by event time', () {
    final sessionStart = DateTime(2026, 3, 9, 8);
    final eventTime = sessionStart.add(const Duration(minutes: 5));
    final match = _matchWithSessions([
      StreamPlaybackEntryModel(
        sessionId: 'sess-1',
        url: 'https://www.youtube.com/watch?v=abc',
        addedAt: sessionStart,
        endedAt: sessionStart.add(const Duration(hours: 1)),
        isLive: false,
      ),
      StreamPlaybackEntryModel(
        sessionId: 'sess-2',
        url: 'https://www.youtube.com/watch?v=xyz',
        addedAt: DateTime(2026, 3, 9, 10),
        isLive: true,
      ),
    ]);

    final resolved = MatchStreamPlayback.resolveSessionForHighlight(
      match,
      eventTime: eventTime,
    );

    expect(resolved?.sessionId, 'sess-1');
  });
}
