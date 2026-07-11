import '../../data/models/stream_playback_entry_model.dart';
import 'match_stream_playback.dart';
import 'stream_playback_merger.dart';

/// Live playback session fields to stamp on every replay marker.
class LiveStreamSessionContext {
  const LiveStreamSessionContext({
    required this.sessionId,
    this.playbackUrl,
    this.sessionStartedAt,
    this.sessionEndedAt,
  });

  final String sessionId;
  final String? playbackUrl;
  final DateTime? sessionStartedAt;
  final DateTime? sessionEndedAt;

  bool get isValid => sessionId.isNotEmpty;
}

/// Resolves the active live session when saving replay markers from Stream Studio.
class ReplayMarkerSessionUtils {
  ReplayMarkerSessionUtils._();

  /// Fields to persist when saving a marker during a live session.
  static LiveStreamSessionContext liveSessionContext({
    required String? youtubeWatchUrl,
    required List<StreamPlaybackEntryModel> playbackEntries,
    required DateTime? streamStartedAt,
  }) {
    final entries = playbackEntries
        .where(
          (e) => e.isLive || e.sessionId.isNotEmpty || e.addedAt != null,
        )
        .toList();

    StreamPlaybackEntryModel? liveEntry;
    for (final entry in entries) {
      if (entry.isLive) {
        liveEntry = entry;
        break;
      }
    }

    if (liveEntry != null) {
      final sessionId = liveEntry.sessionId.trim().isNotEmpty
          ? liveEntry.sessionId.trim()
          : StreamPlaybackMerger.sessionKeyFor(liveEntry);
      if (sessionId.isNotEmpty) {
        return LiveStreamSessionContext(
          sessionId: sessionId,
          playbackUrl: _playbackUrlFromEntry(liveEntry),
          sessionStartedAt: liveEntry.addedAt ?? streamStartedAt,
          sessionEndedAt: liveEntry.endedAt,
        );
      }
    }

    return const LiveStreamSessionContext(sessionId: '');
  }

  static String? _playbackUrlFromEntry(StreamPlaybackEntryModel entry) {
    final fromEntry = entry.url.trim();
    if (fromEntry.isNotEmpty &&
        !MatchStreamPlayback.isPendingWatchUrl(fromEntry)) {
      return fromEntry;
    }
    return null;
  }
}
