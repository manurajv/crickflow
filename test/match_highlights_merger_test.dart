import 'package:flutter_test/flutter_test.dart';

import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/stream_playback_entry_model.dart';
import 'package:crickflow/features/streaming/data/models/replay_marker_model.dart';
import 'package:crickflow/features/streaming/domain/match_highlights_merger.dart';
import 'package:crickflow/features/streaming/domain/streaming_enums.dart';

BallEventModel _highlightBall({
  required String id,
  required int sequence,
  DateTime? timestamp,
  int runs = 6,
}) {
  return BallEventModel(
    id: id,
    matchId: 'm1',
    inningsNumber: 1,
    overNumber: 1,
    ballInOver: sequence,
    eventType: BallEventType.runs,
    runs: runs,
    sequence: sequence,
    timestamp: timestamp,
    isHighlight: true,
    highlightTag: 'six',
  );
}

void main() {
  const merger = MatchHighlightsMerger();

  test('newest ball highlight is first even without timestamp during live', () {
    final old = _highlightBall(
      id: 'old',
      sequence: 10,
      timestamp: DateTime(2026, 3, 9, 10),
    );
    final live = _highlightBall(
      id: 'live',
      sequence: 50,
      timestamp: null,
    );

    final merged = merger.merge(
      ballEvents: [old, live],
      replayMarkers: const [],
    );

    expect(merged.first.ballEvent?.id, 'live');
    expect(merged.last.ballEvent?.id, 'old');
  });

  test('newest ball highlight is first when older balls have wall-clock timestamps', () {
    final older = _highlightBall(
      id: 'older',
      sequence: 100,
      timestamp: DateTime(2026, 3, 9, 8),
    );
    final newer = _highlightBall(
      id: 'newer',
      sequence: 101,
      timestamp: DateTime(2026, 3, 9, 12),
    );

    final merged = merger.merge(
      ballEvents: [older, newer],
      replayMarkers: const [],
    );

    expect(merged.map((e) => e.ballEvent?.id), ['newer', 'older']);
  });

  test('orphan replay marker slots near chronology of ball highlights', () {
    final ball = _highlightBall(
      id: 'ball',
      sequence: 20,
      timestamp: DateTime(2026, 3, 9, 10, 5),
    );
    final marker = ReplayMarkerModel(
      id: 'm1',
      matchId: 'm1',
      kind: ReplayMarkerKind.custom,
      label: 'Manual replay',
      streamOffsetMs: 60_000,
      createdBy: 'u1',
      createdAt: DateTime(2026, 3, 9, 10, 6),
    );

    final merged = merger.merge(
      ballEvents: [ball],
      replayMarkers: [marker],
    );

    expect(merged.length, 2);
    expect(merged.first.replayMarker?.id, 'm1');
  });

  test('pre-live scoring highlight has no stream offset after new go-live', () {
    final liveStart = DateTime(2026, 3, 9, 14);
    final preLive = _highlightBall(
      id: 'pre',
      sequence: 5,
      timestamp: liveStart.subtract(const Duration(minutes: 30)),
    );
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
            sessionId: 'sess-new',
            url: 'https://www.youtube.com/watch?v=new',
            addedAt: liveStart,
            isLive: true,
          ),
        ],
      ),
    );

    final merged = merger.merge(
      ballEvents: [preLive],
      replayMarkers: const [],
      match: match,
    );

    expect(merged.single.streamOffsetMs, isNull);
    expect(merged.single.streamSessionId, isNull);
  });
}
