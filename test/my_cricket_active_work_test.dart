import 'package:flutter_test/flutter_test.dart';

import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_setup_draft_models.dart';
import 'package:crickflow/data/models/stream_playback_entry_model.dart';
import 'package:crickflow/data/models/tournament_model.dart';
import 'package:crickflow/features/my_cricket/my_cricket_filters.dart';
import 'package:crickflow/features/streaming/data/active_stream_session.dart';

void main() {
  const userId = 'user-1';

  MatchModel match({
    MatchStatus status = MatchStatus.live,
    MatchMode mode = MatchMode.normal,
    StreamStatus streamStatus = StreamStatus.idle,
    List<StreamPlaybackEntryModel> playbackEntries = const [],
  }) {
    return MatchModel(
      id: 'match-1',
      title: 'A vs B',
      status: status,
      matchMode: mode,
      scorer1UserId: userId,
      stream: StreamMetadataModel(
        status: streamStatus,
        playbackEntries: playbackEntries,
      ),
    );
  }

  test('assigned scorer can resume an active quick match', () {
    final active = match(
      status: MatchStatus.tossCompleted,
      mode: MatchMode.quick,
    );

    expect(userScoresMatch(active, userId), isTrue);
    expect(canResumeScoring(active, userId), isTrue);
  });

  test('completed scoring match is not resumable', () {
    final completed = match(status: MatchStatus.completed);

    expect(userScoresMatch(completed, userId), isTrue);
    expect(canResumeScoring(completed, userId), isFalse);
  });

  test('stream history identifies broadcaster and active studio', () {
    final streaming = match(
      streamStatus: StreamStatus.live,
      playbackEntries: const [
        StreamPlaybackEntryModel(
          url: 'https://youtube.com/watch?v=abc',
          addedByUserId: userId,
          isLive: true,
        ),
      ],
    );

    expect(userStreamedMatch(streaming, userId), isTrue);
    expect(canResumeStreaming(streaming, userId), isTrue);
    expect(ActiveStreamSession.isResumeEligible(streaming), isTrue);
  });

  test('assigned streamer appears before their first broadcast', () {
    final assigned = MatchModel(
      id: 'assigned-stream',
      title: 'Assigned stream',
      setup: const MatchSetupData(
        liveStreamers: [MatchOfficialEntry(name: 'Streamer', userId: userId)],
      ),
    );

    expect(userStreamedMatch(assigned, userId), isTrue);
  });

  test('copyWith preserves primary scorer assignments', () {
    final original = match();
    final copied = original.copyWith(status: MatchStatus.inningsBreak);

    expect(copied.scorer1UserId, userId);
  });

  test('completed match never resumes a stale stream session', () {
    final completed = match(
      status: MatchStatus.completed,
      streamStatus: StreamStatus.live,
    );

    expect(ActiveStreamSession.isResumeEligible(completed), isFalse);
  });

  test('newest match sorting includes completed match date', () {
    final olderLive = MatchModel(
      id: 'live',
      title: 'Older live match',
      status: MatchStatus.live,
      startedAt: DateTime(2026, 8, 1),
    );
    final recentCompleted = MatchModel(
      id: 'completed',
      title: 'Recent completed match',
      status: MatchStatus.completed,
      completedAt: DateTime(2026, 9, 1),
    );

    final sorted = sortMyCricketMatches([
      olderLive,
      recentCompleted,
    ], MyCricketSort.newest);

    expect(sorted.map((item) => item.id), ['completed', 'live']);
  });

  test('tournaments support newest, oldest, and name sorting', () {
    final alpha = TournamentModel(
      id: 'alpha',
      name: 'Alpha Cup',
      startDate: DateTime(2025, 1, 1),
    );
    final beta = TournamentModel(
      id: 'beta',
      name: 'Beta Cup',
      startDate: DateTime(2026, 1, 1),
    );

    expect(
      sortMyCricketTournaments([
        alpha,
        beta,
      ], MyCricketSort.newest).map((item) => item.id),
      ['beta', 'alpha'],
    );
    expect(
      sortMyCricketTournaments([
        alpha,
        beta,
      ], MyCricketSort.oldest).map((item) => item.id),
      ['alpha', 'beta'],
    );
    expect(
      sortMyCricketTournaments([
        beta,
        alpha,
      ], MyCricketSort.name).map((item) => item.id),
      ['alpha', 'beta'],
    );
  });
}
