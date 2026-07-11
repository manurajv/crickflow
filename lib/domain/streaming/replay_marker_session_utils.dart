import '../../core/utils/youtube_utils.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/stream_playback_entry_model.dart';
import '../../features/streaming/data/models/replay_marker_model.dart';
import 'match_stream_playback.dart';
import 'replay_marker_commentary.dart';
import 'stream_playback_merger.dart';

/// A replay marker resolved to a specific watch session and seek offset.
class ResolvedReplayMarker {
  const ResolvedReplayMarker({
    required this.marker,
    required this.sourceIndex,
    required this.seekOffsetMs,
    required this.timelinePositionMs,
    required this.commentary,
  });

  final ReplayMarkerModel marker;
  final int sourceIndex;
  final int seekOffsetMs;
  final int timelinePositionMs;
  final String commentary;
}

/// One watchable stream session for marker layout and resolution.
class ReplayMarkerSession {
  const ReplayMarkerSession({
    required this.sourceIndex,
    required this.source,
    required this.durationMs,
    required this.timelineStartMs,
    this.sessionKey = '',
    this.startedAt,
    this.urlKey,
  });

  final int sourceIndex;
  final MatchStreamSource source;
  final int durationMs;
  final int timelineStartMs;
  final String sessionKey;
  final DateTime? startedAt;
  final String? urlKey;
}

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

/// Maps replay markers to playback sessions (supports multi-live matches).
class ReplayMarkerSessionUtils {
  ReplayMarkerSessionUtils._();

  static const _sessionMatchToleranceMs = 5000;
  static const _replayPreRollMs = 10_000;

  static String? playbackUrlKey(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    return YoutubeUtils.videoIdFromUrl(url) ?? url.trim();
  }

  static List<ReplayMarkerSession> buildSessions(
    List<MatchStreamSource> sources,
  ) {
    if (sources.isEmpty) return const [];

    final indexed = <({int index, MatchStreamSource source})>[
      for (var i = 0; i < sources.length; i++) (index: i, source: sources[i]),
    ]..sort((a, b) {
        final aAt = a.source.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bAt = b.source.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aAt.compareTo(bAt);
      });

    var timelineCursor = 0;
    final sessions = <ReplayMarkerSession>[];
    for (var i = 0; i < indexed.length; i++) {
      final item = indexed[i];
      final nextStart = i + 1 < indexed.length
          ? indexed[i + 1].source.addedAt
          : null;
      final durationMs = _sessionDurationMs(item.source, nextSessionStart: nextStart);
      if (durationMs <= 0) continue;
      sessions.add(
        ReplayMarkerSession(
          sourceIndex: item.index,
          source: item.source,
          durationMs: durationMs,
          timelineStartMs: timelineCursor,
          sessionKey: item.source.effectiveSessionKey,
          startedAt: item.source.addedAt,
          urlKey: playbackUrlKey(item.source.url),
        ),
      );
      timelineCursor += durationMs;
    }
    return sessions;
  }

  static int totalTimelineDurationMs(List<ReplayMarkerSession> sessions) {
    if (sessions.isEmpty) return 0;
    final last = sessions.last;
    return last.timelineStartMs + last.durationMs;
  }

  static List<ResolvedReplayMarker> resolve({
    required List<ReplayMarkerModel> markers,
    required List<MatchStreamSource> sources,
    Map<String, BallEventModel> ballEventsById = const {},
  }) {
    if (markers.isEmpty || sources.isEmpty) return const [];

    final sessions = buildSessions(sources);
    if (sessions.isEmpty) return const [];

    final resolved = <ResolvedReplayMarker>[];
    for (final marker in markers) {
      final session = _sessionForMarker(marker, sessions);
      if (session == null) continue;

      final seekOffsetMs = _seekOffsetMs(marker, session);
      if (seekOffsetMs < 0) continue;

      resolved.add(
        ResolvedReplayMarker(
          marker: marker,
          sourceIndex: session.sourceIndex,
          seekOffsetMs: seekOffsetMs,
          timelinePositionMs: session.timelineStartMs + seekOffsetMs,
          commentary: ReplayMarkerCommentary.format(
            marker,
            ball: marker.ballEventId != null
                ? ballEventsById[marker.ballEventId!]
                : null,
          ),
        ),
      );
    }

    resolved.sort((a, b) => a.timelinePositionMs.compareTo(b.timelinePositionMs));
    return resolved;
  }

  static int _sessionDurationMs(
    MatchStreamSource source, {
    DateTime? nextSessionStart,
  }) {
    final start = source.addedAt;
    var end = source.endedAt ?? (source.isLive ? DateTime.now() : null);
    if (end == null && nextSessionStart != null && start != null) {
      end = nextSessionStart;
    }
    if (start != null && end != null && end.isAfter(start)) {
      return end.difference(start).inMilliseconds.clamp(1, 8 * 60 * 60 * 1000);
    }

    return 120_000;
  }

  static ReplayMarkerSession? _sessionForMarker(
    ReplayMarkerModel marker,
    List<ReplayMarkerSession> sessions,
  ) {
    final markerSessionId = marker.streamSessionId.trim();
    if (markerSessionId.isNotEmpty) {
      for (final session in sessions) {
        if (session.sessionKey == markerSessionId ||
            session.source.effectiveSessionKey == markerSessionId) {
          return session;
        }
      }
    }

    final markerUrlKey = playbackUrlKey(marker.playbackUrl);
    final markerSessionStart = marker.streamSessionStartedAt;

    if (markerUrlKey != null) {
      final urlMatches =
          sessions.where((s) => s.urlKey == markerUrlKey).toList();
      if (urlMatches.length == 1) return urlMatches.first;
      if (urlMatches.isNotEmpty && markerSessionStart != null) {
        for (final session in urlMatches) {
          if (_sameSession(session.startedAt, markerSessionStart)) {
            return session;
          }
        }
      }
      if (urlMatches.isNotEmpty && marker.createdAt != null) {
        final byTime = _sessionContaining(marker.createdAt!, urlMatches);
        if (byTime != null) return byTime;
      }
    }

    if (markerSessionStart != null) {
      for (final session in sessions) {
        if (_sameSession(session.startedAt, markerSessionStart)) {
          return session;
        }
      }
    }

    if (marker.createdAt != null) {
      final byTime = _sessionContaining(marker.createdAt!, sessions);
      if (byTime != null) return byTime;
    }

    if (sessions.length == 1) return sessions.first;

    return null;
  }

  static ReplayMarkerSession? _sessionContaining(
    DateTime instant,
    List<ReplayMarkerSession> sessions,
  ) {
    ReplayMarkerSession? best;
    for (final session in sessions) {
      final start = session.startedAt;
      if (start == null) continue;
      var end = session.source.endedAt ??
          (session.source.isLive ? DateTime.now() : null);
      if (end == null) {
        final sessionIndex = sessions.indexOf(session);
        if (sessionIndex >= 0 && sessionIndex + 1 < sessions.length) {
          end = sessions[sessionIndex + 1].startedAt;
        }
      }
      if (end == null) continue;
      if (!instant.isBefore(start) && !instant.isAfter(end)) {
        best = session;
      }
    }
    return best;
  }

  static int _seekOffsetMs(
    ReplayMarkerModel marker,
    ReplayMarkerSession session,
  ) {
    final markerSessionId = marker.streamSessionId.trim();
    if (markerSessionId.isNotEmpty &&
        (session.sessionKey == markerSessionId ||
            session.source.effectiveSessionKey == markerSessionId)) {
      return marker.streamOffsetMs.clamp(0, session.durationMs);
    }

    final sessionStart = session.startedAt;
    final markerSessionStart = marker.streamSessionStartedAt;

    if (markerSessionStart != null &&
        sessionStart != null &&
        _sameSession(sessionStart, markerSessionStart)) {
      return marker.streamOffsetMs.clamp(0, session.durationMs);
    }

    if (marker.createdAt != null && sessionStart != null) {
      final rawMs = marker.createdAt!.difference(sessionStart).inMilliseconds;
      if (rawMs >= 0) {
        final withPreRoll =
            (rawMs - _replayPreRollMs).clamp(0, rawMs).toInt();
        return withPreRoll.clamp(0, session.durationMs);
      }
    }

    if (marker.streamOffsetMs <= session.durationMs + 30_000) {
      return marker.streamOffsetMs.clamp(0, session.durationMs);
    }

    return marker.streamOffsetMs.clamp(0, session.durationMs);
  }

  static bool _sameSession(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return (a.difference(b).inMilliseconds).abs() <= _sessionMatchToleranceMs;
  }

  /// Fields to persist when saving a marker during a live session.
  static LiveStreamSessionContext liveSessionContext({
    required String? youtubeWatchUrl,
    required List<StreamPlaybackEntryModel> playbackEntries,
    required DateTime? streamStartedAt,
  }) {
    final entries = playbackEntries
        .where(
          (e) =>
              e.url.trim().isNotEmpty ||
              e.sessionId.isNotEmpty ||
              e.addedAt != null,
        )
        .toList();

    StreamPlaybackEntryModel? liveEntry;
    for (var i = entries.length - 1; i >= 0; i--) {
      if (entries[i].isLive) {
        liveEntry = entries[i];
        break;
      }
    }

    liveEntry ??= entries.isNotEmpty ? entries.last : null;

    final playbackUrl = _resolvePlaybackUrl(liveEntry, youtubeWatchUrl);
    final startedAt = liveEntry?.addedAt ?? streamStartedAt;

    if (liveEntry == null && (playbackUrl == null || startedAt == null)) {
      return const LiveStreamSessionContext(sessionId: '');
    }

    final sessionId = liveEntry != null
        ? StreamPlaybackMerger.sessionKeyFor(liveEntry)
        : '${startedAt?.toUtc().millisecondsSinceEpoch ?? 0}_${playbackUrl?.hashCode ?? 0}';

    return LiveStreamSessionContext(
      sessionId: sessionId,
      playbackUrl: playbackUrl,
      sessionStartedAt: startedAt,
      sessionEndedAt: liveEntry?.endedAt,
    );
  }

  static String? _resolvePlaybackUrl(
    StreamPlaybackEntryModel? entry,
    String? youtubeWatchUrl,
  ) {
    final fromEntry = entry?.url.trim();
    if (fromEntry != null &&
        fromEntry.isNotEmpty &&
        !fromEntry.startsWith('pending:')) {
      return fromEntry;
    }
    final fallback = youtubeWatchUrl?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    if (fromEntry != null && fromEntry.isNotEmpty) return fromEntry;
    return null;
  }
}
