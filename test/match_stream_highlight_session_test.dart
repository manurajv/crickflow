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

  test('resolveSessionForHighlight returns null when event is after stream ended', () {
    final match = _matchWithSessions([
      StreamPlaybackEntryModel(
        sessionId: 'sess-1',
        url: 'https://www.youtube.com/watch?v=abc',
        addedAt: DateTime(2026, 3, 9, 8),
        endedAt: DateTime(2026, 3, 9, 9),
        isLive: false,
      ),
    ]);

    final resolved = MatchStreamPlayback.resolveSessionForHighlight(
      match,
      eventTime: DateTime(2026, 3, 9, 10),
    );

    expect(resolved, isNull);
  });

  test('highlightIsStreamable is false for scoring-only highlights', () {
    final match = _matchWithSessions([
      StreamPlaybackEntryModel(
        sessionId: 'sess-1',
        url: 'https://www.youtube.com/watch?v=abc',
        addedAt: DateTime(2026, 3, 9, 8),
        endedAt: DateTime(2026, 3, 9, 9),
        isLive: false,
      ),
    ]);

    final streamable = MatchStreamPlayback.highlightIsStreamable(
      match,
      streamOffsetMs: 120_000,
      eventTime: DateTime(2026, 3, 9, 10, 30),
    );

    expect(streamable, isFalse);
  });

  test('highlightIsStreamable is true for in-session replay marker', () {
    final match = _matchWithSessions([
      StreamPlaybackEntryModel(
        sessionId: 'sess-live',
        url: 'https://www.youtube.com/watch?v=live',
        addedAt: DateTime(2026, 3, 9, 10),
        isLive: true,
      ),
    ]);

    final streamable = MatchStreamPlayback.highlightIsStreamable(
      match,
      streamOffsetMs: 60_000,
      streamSessionId: 'sess-live',
      fromReplayMarker: true,
    );

    expect(streamable, isTrue);
  });

  test('highlightIsStreamable is false for pre-live wicket when new live is active', () {
    final liveStart = DateTime(2026, 3, 9, 14);
    final match = _matchWithSessions([
      StreamPlaybackEntryModel(
        sessionId: 'sess-new',
        url: 'https://www.youtube.com/watch?v=new',
        addedAt: liveStart,
        isLive: true,
      ),
    ]);

    final streamable = MatchStreamPlayback.highlightIsStreamable(
      match,
      streamOffsetMs: 120_000,
      eventTime: liveStart.subtract(const Duration(minutes: 20)),
    );

    expect(streamable, isFalse);
  });

  test('highlightIsStreamable is false without event time or replay marker', () {
    final match = _matchWithSessions([
      StreamPlaybackEntryModel(
        sessionId: 'sess-live',
        url: 'https://www.youtube.com/watch?v=live',
        addedAt: DateTime(2026, 3, 9, 14),
        isLive: true,
      ),
    ]);

    final streamable = MatchStreamPlayback.highlightIsStreamable(
      match,
      streamOffsetMs: 60_000,
    );

    expect(streamable, isFalse);
  });

  test('highlightIsStreamable is false for ended session while match still live', () {
    final sessionStart = DateTime(2026, 3, 9, 8);
    final eventTime = sessionStart.add(const Duration(minutes: 30));
    final match = MatchModel(
      id: 'm1',
      title: 'Test',
      teamAName: 'A',
      teamBName: 'B',
      status: MatchStatus.live,
      stream: StreamMetadataModel(
        status: StreamStatus.ended,
        playbackEntries: [
          StreamPlaybackEntryModel(
            sessionId: 'sess-1',
            url: 'https://www.youtube.com/watch?v=abc',
            addedAt: sessionStart,
            endedAt: sessionStart.add(const Duration(hours: 1)),
            isLive: false,
          ),
        ],
      ),
    );

    final streamable = MatchStreamPlayback.highlightIsStreamable(
      match,
      streamOffsetMs: 60_000,
      streamSessionId: 'sess-1',
      eventTime: eventTime,
      fromReplayMarker: true,
    );

    expect(streamable, isFalse);
  });

  test('highlightIsStreamable is false when metadata live but all sessions ended', () {
    final sessionStart = DateTime(2026, 3, 9, 8);
    final eventTime = sessionStart.add(const Duration(minutes: 30));
    final match = MatchModel(
      id: 'm1',
      title: 'Test',
      teamAName: 'A',
      teamBName: 'B',
      status: MatchStatus.live,
      stream: StreamMetadataModel(
        status: StreamStatus.live,
        playbackEntries: [
          StreamPlaybackEntryModel(
            sessionId: 'sess-1',
            url: 'https://www.youtube.com/watch?v=abc',
            addedAt: sessionStart,
            endedAt: sessionStart.add(const Duration(hours: 1)),
            isLive: false,
          ),
        ],
      ),
    );

    final streamable = MatchStreamPlayback.highlightIsStreamable(
      match,
      streamOffsetMs: 60_000,
      streamSessionId: 'sess-1',
      eventTime: eventTime,
      fromReplayMarker: true,
    );

    expect(streamable, isFalse);
    expect(MatchStreamPlayback.highlightPlaybackEnabled(match), isFalse);
  });

  test('highlightIsStreamable is true for ended session when match is completed', () {
    final sessionStart = DateTime(2026, 3, 9, 8);
    final eventTime = sessionStart.add(const Duration(minutes: 30));
    final match = MatchModel(
      id: 'm1',
      title: 'Test',
      teamAName: 'A',
      teamBName: 'B',
      status: MatchStatus.completed,
      stream: StreamMetadataModel(
        status: StreamStatus.ended,
        playbackEntries: [
          StreamPlaybackEntryModel(
            sessionId: 'sess-1',
            url: 'https://www.youtube.com/watch?v=abc',
            addedAt: sessionStart,
            endedAt: sessionStart.add(const Duration(hours: 1)),
            isLive: false,
          ),
        ],
      ),
    );

    final streamable = MatchStreamPlayback.highlightIsStreamable(
      match,
      streamOffsetMs: 60_000,
      streamSessionId: 'sess-1',
      eventTime: eventTime,
      fromReplayMarker: true,
    );

    expect(streamable, isTrue);
  });
}
