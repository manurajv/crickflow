import 'package:flutter_test/flutter_test.dart';

import 'package:crickflow/data/models/stream_playback_entry_model.dart';
import 'package:crickflow/domain/streaming/stream_playback_merger.dart';

void main() {
  test('beginLiveSession keeps prior ended sessions', () {
    final firstEnded = StreamPlaybackEntryModel(
      sessionId: 'sess-1',
      url: 'https://www.youtube.com/watch?v=first',
      addedAt: DateTime(2026, 3, 9, 8, 0),
      endedAt: DateTime(2026, 3, 9, 9, 0),
      isLive: false,
    );
    final secondStart = DateTime(2026, 3, 9, 10, 0);

    final entries = StreamPlaybackMerger.beginLiveSession(
      existing: [firstEnded],
      sessionId: 'sess-2',
      url: 'https://www.youtube.com/watch?v=second',
      addedAt: secondStart,
    );

    expect(entries.length, 2);
    expect(entries.where((e) => !e.isLive).length, 1);
    expect(entries.singleWhere((e) => e.isLive).sessionId, 'sess-2');
  });

  test('unionEntries merges distinct sessions from two snapshots', () {
    final local = [
      const StreamPlaybackEntryModel(
        sessionId: 'a',
        url: 'https://www.youtube.com/watch?v=a',
        isLive: true,
      ),
    ];
    final remote = [
      const StreamPlaybackEntryModel(
        sessionId: 'b',
        url: 'https://www.youtube.com/watch?v=b',
        addedAt: null,
        endedAt: null,
        isLive: false,
      ),
    ];

    final merged = StreamPlaybackMerger.unionEntries(local, remote);
    expect(merged.length, 2);
    expect(merged.map((e) => e.sessionId).toSet(), {'a', 'b'});
  });

  test('finalizeEndedSessionUrls resolves pending replay links', () {
    final entries = StreamPlaybackMerger.finalizeEndedSessionUrls(
      entries: const [
        StreamPlaybackEntryModel(
          sessionId: 'sess-1',
          url: 'pending:youtube:sess-1',
          isLive: false,
        ),
      ],
      canonicalWatchUrl: 'https://www.youtube.com/watch?v=abc',
      forSessionId: 'sess-1',
    );

    expect(entries.single.url, 'https://www.youtube.com/watch?v=abc');
  });

  test('finalizeEndedSessionUrls does not cross-update other sessions', () {
    final entries = StreamPlaybackMerger.finalizeEndedSessionUrls(
      entries: const [
        StreamPlaybackEntryModel(
          sessionId: 'sess-1',
          url: 'pending:youtube:sess-1',
          isLive: false,
        ),
        StreamPlaybackEntryModel(
          sessionId: 'sess-2',
          url: 'pending:youtube:sess-2',
          isLive: false,
        ),
      ],
      canonicalWatchUrl: 'https://www.youtube.com/watch?v=sess2only',
      forSessionId: 'sess-2',
    );

    expect(
      entries.firstWhere((e) => e.sessionId == 'sess-1').url,
      'pending:youtube:sess-1',
    );
    expect(
      entries.firstWhere((e) => e.sessionId == 'sess-2').url,
      'https://www.youtube.com/watch?v=sess2only',
    );
  });

  test('unionEntries prefers resolved URL over pending for same session', () {
    const sessionId = 'sess-1';
    final local = [
      const StreamPlaybackEntryModel(
        sessionId: sessionId,
        url: 'pending:youtube:sess-1',
        isLive: true,
      ),
    ];
    final remote = [
      const StreamPlaybackEntryModel(
        sessionId: sessionId,
        url: 'https://www.youtube.com/watch?v=abc',
        isLive: true,
      ),
    ];

    final merged = StreamPlaybackMerger.unionEntries(local, remote);
    expect(merged.single.url, 'https://www.youtube.com/watch?v=abc');
  });

  test('attachWatchUrlToSession updates only matching session', () {
    final first = StreamPlaybackEntryModel(
      sessionId: 'sess-1',
      url: 'https://www.youtube.com/watch?v=first',
      addedAt: DateTime(2026, 3, 9, 8),
      endedAt: DateTime(2026, 3, 9, 9),
      isLive: false,
    );
    final live = StreamPlaybackEntryModel(
      sessionId: 'sess-2',
      url: 'pending:youtube:sess-2',
      addedAt: DateTime(2026, 3, 9, 10),
      isLive: true,
    );

    final updated = StreamPlaybackMerger.attachWatchUrlToSession(
      existing: [first, live],
      url: 'https://www.facebook.com/share/v/abc',
      sessionId: 'sess-2',
      requireLive: true,
    );

    expect(
      updated.firstWhere((e) => e.sessionId == 'sess-1').url,
      first.url,
    );
    expect(
      updated.firstWhere((e) => e.sessionId == 'sess-2').url,
      'https://www.facebook.com/share/v/abc',
    );
    expect(
      updated.firstWhere((e) => e.sessionId == 'sess-2').sessionId,
      'sess-2',
    );
  });

  test('activeLiveWatchUrl ignores ended sessions when live is pending', () {
    final entries = [
      StreamPlaybackEntryModel(
        sessionId: 'sess-1',
        url: 'https://www.youtube.com/watch?v=first',
        addedAt: DateTime(2026, 3, 9, 8),
        endedAt: DateTime(2026, 3, 9, 9),
        isLive: false,
      ),
      StreamPlaybackEntryModel(
        sessionId: 'sess-2',
        url: 'pending:youtube:sess-2',
        addedAt: DateTime(2026, 3, 9, 10),
        isLive: true,
      ),
    ];

    expect(StreamPlaybackMerger.activeLiveWatchUrl(entries), isNull);
    expect(
      StreamPlaybackMerger.latestWatchUrl(entries),
      'https://www.youtube.com/watch?v=first',
    );
  });

  test('activeLiveWatchUrl returns resolved live session url', () {
    final entries = [
      const StreamPlaybackEntryModel(
        sessionId: 'sess-1',
        url: 'https://www.youtube.com/watch?v=first',
        isLive: false,
      ),
      const StreamPlaybackEntryModel(
        sessionId: 'sess-2',
        url: 'https://www.youtube.com/watch?v=second',
        isLive: true,
      ),
    ];

    expect(
      StreamPlaybackMerger.activeLiveWatchUrl(entries),
      'https://www.youtube.com/watch?v=second',
    );
  });
}
