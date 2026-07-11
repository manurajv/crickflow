import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/enums.dart';
import '../../core/utils/facebook_utils.dart';
import '../../core/utils/youtube_utils.dart';
import '../../data/models/match_model.dart';
import '../../data/models/stream_playback_entry_model.dart';
import '../../features/streaming/domain/streaming_enums.dart';
import 'stream_playback_merger.dart';

/// A single watchable stream angle (YouTube, Facebook, etc.).
class MatchStreamSource {
  const MatchStreamSource({
    required this.url,
    required this.label,
    this.sessionId = '',
    this.sessionKey = '',
    this.platform = StreamPlaybackPlatform.unknown,
    this.isLive = false,
    this.addedAt,
    this.endedAt,
    this.statusLabel = '',
    this.startTimeLabel = '',
  });

  final String url;
  final String label;
  /// Raw `playbackEntries.sessionId` (before UI dedupe suffix).
  final String sessionId;
  final String sessionKey;
  final StreamPlaybackPlatform platform;
  final bool isLive;
  final DateTime? addedAt;
  final DateTime? endedAt;
  final String statusLabel;
  final String startTimeLabel;

  String get effectiveSessionKey =>
      sessionKey.isNotEmpty ? sessionKey : url;

  bool get isEmbeddable =>
      platform == StreamPlaybackPlatform.youtube ||
      platform == StreamPlaybackPlatform.facebook;

  bool get hasPlayableUrl =>
      url.trim().isNotEmpty && !MatchStreamPlayback.isPendingWatchUrl(url);

  IconData get platformIcon => switch (platform) {
        StreamPlaybackPlatform.youtube => Icons.play_circle_outline,
        StreamPlaybackPlatform.facebook => Icons.facebook,
        StreamPlaybackPlatform.twitch => Icons.videogame_asset_outlined,
        StreamPlaybackPlatform.unknown => Icons.live_tv_outlined,
      };
}

enum StreamPlaybackPlatform { youtube, facebook, twitch, unknown }

/// Helpers for deciding when a match has watchable streams and listing them.
class MatchStreamPlayback {
  MatchStreamPlayback._();

  static bool isPendingWatchUrl(String url) =>
      url.trim().startsWith('pending:');

  /// `pending:youtube:<sessionId>` — watch URL not ready yet after go-live.
  static StreamPlaybackPlatform platformFromPendingUrl(String url) {
    if (!isPendingWatchUrl(url)) return StreamPlaybackPlatform.unknown;
    final parts = url.split(':');
    if (parts.length >= 2) {
      return switch (parts[1]) {
        'youtube' => StreamPlaybackPlatform.youtube,
        'facebook' => StreamPlaybackPlatform.facebook,
        'twitch' => StreamPlaybackPlatform.twitch,
        _ => StreamPlaybackPlatform.unknown,
      };
    }
    return StreamPlaybackPlatform.unknown;
  }

  static String pendingWatchUrl({
    required StreamPlaybackPlatform platform,
    required String sessionId,
  }) {
    final key = switch (platform) {
      StreamPlaybackPlatform.youtube => 'youtube',
      StreamPlaybackPlatform.facebook => 'facebook',
      StreamPlaybackPlatform.twitch => 'twitch',
      StreamPlaybackPlatform.unknown => 'unknown',
    };
    return 'pending:$key:$sessionId';
  }

  static StreamPlaybackPlatform platformFromUrl(String url) {
    if (isPendingWatchUrl(url)) {
      return platformFromPendingUrl(url);
    }
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return StreamPlaybackPlatform.youtube;
    }
    if (lower.contains('facebook.com') || lower.contains('fb.watch')) {
      return StreamPlaybackPlatform.facebook;
    }
    if (lower.contains('twitch.tv')) {
      return StreamPlaybackPlatform.twitch;
    }
    return StreamPlaybackPlatform.unknown;
  }

  static bool hasWatchablePlayback(MatchModel match) {
    if (playableSourcesFor(match).isNotEmpty) return true;
    return hasActiveAwaitingWatchUrl(match);
  }

  /// True while a go-live is in progress but the public URL is not ready yet.
  static bool hasActiveAwaitingWatchUrl(MatchModel match) {
    final active = match.stream.status == StreamStatus.live ||
        match.stream.status == StreamStatus.connecting;
    if (!active) return false;
    return StreamPlaybackMerger.collect(match.stream).any(
          (e) => e.isLive && isPendingWatchUrl(e.url),
        );
  }

  static bool isStreamActive(MatchModel match) {
    final status = match.stream.status;
    return status == StreamStatus.live || status == StreamStatus.connecting;
  }

  /// Sources with a real public URL — used for the stream selector.
  static List<MatchStreamSource> playableSourcesFor(MatchModel match) =>
      sourcesFor(match).where((s) => s.hasPlayableUrl).toList(growable: false);

  static bool isStreamingOrStreamed(MatchModel match) {
    final status = match.stream.status;
    if (status == StreamStatus.live || status == StreamStatus.connecting) {
      return true;
    }
    if (status == StreamStatus.ended && hasWatchablePlayback(match)) {
      return true;
    }
    return hasWatchablePlayback(match);
  }

  static bool needsWatchUrl(MatchModel match) {
    final s = match.stream;
    final active = s.status == StreamStatus.live ||
        s.status == StreamStatus.connecting;
    return active && playableSourcesFor(match).isEmpty;
  }

  /// Newest-first ordering for the hub stream switcher.
  static List<MatchStreamSource> sourcesFor(MatchModel match) {
    final entries = StreamPlaybackMerger.collect(match.stream);
    final active = isStreamActive(match);
    final filtered = entries.where((entry) {
      final url = entry.url.trim();
      if (url.isEmpty) return entry.sessionId.isNotEmpty || entry.addedAt != null;
      if (!isPendingWatchUrl(url)) return true;
      return active && entry.isLive;
    }).toList();

    final out = <MatchStreamSource>[];
    final usedKeys = <String>{};

    for (var i = 0; i < filtered.length; i++) {
      final entry = filtered[i];
      final url = _resolveEntryUrl(entry, match.stream);
      var sessionKey = StreamPlaybackMerger.sessionKeyFor(entry);
      if (usedKeys.contains(sessionKey)) {
        sessionKey = '${sessionKey}_$i';
      }
      usedKeys.add(sessionKey);

      final platform = platformFromUrl(
        url.isNotEmpty ? url : entry.url,
      );
      final statusLabel = _statusLabel(entry, i, filtered);
      final sessionStart = _inferSessionStart(entry, match.stream);
      final startTimeLabel = formatSessionStartTime(sessionStart);
      final rawSessionId = entry.sessionId.trim();

      out.add(
        MatchStreamSource(
          sessionId: rawSessionId,
          sessionKey: sessionKey,
          url: url,
          label: _labelFor(platform, statusLabel, startTimeLabel),
          platform: platform,
          isLive: entry.isLive,
          addedAt: sessionStart,
          endedAt: entry.endedAt,
          statusLabel: statusLabel,
          startTimeLabel: startTimeLabel,
        ),
      );
    }
    return out;
  }

  /// Resolves a playback entry URL, upgrading an active live pending row when
  /// [StreamMetadataModel.youtubeWatchUrl] was pasted before entries synced.
  static String _resolveEntryUrl(
    StreamPlaybackEntryModel entry,
    StreamMetadataModel stream,
  ) {
    final trimmed = entry.url.trim();
    if (trimmed.isNotEmpty && !isPendingWatchUrl(trimmed)) return trimmed;

    if (entry.isLive &&
        isPendingWatchUrl(trimmed) &&
        isStreamActiveFromMetadata(stream)) {
      final canonical = stream.youtubeWatchUrl?.trim() ?? '';
      if (canonical.isNotEmpty && !isPendingWatchUrl(canonical)) {
        final canonicalKey = _urlIdentityKey(canonical);
        final usedByOtherSession = stream.playbackEntries.any(
          (e) =>
              !e.isLive &&
              e.sessionId.trim() != entry.sessionId.trim() &&
              _urlIdentityKey(e.url) == canonicalKey &&
              canonicalKey.isNotEmpty,
        );
        if (!usedByOtherSession) return canonical;
      }
    }
    return trimmed;
  }

  static String _urlIdentityKey(String url) {
    final trimmed = url.trim().toLowerCase();
    if (trimmed.isEmpty) return '';
    final vMatch = RegExp(r'[?&]v=([^&]+)').firstMatch(trimmed);
    if (vMatch != null) return 'yt:${vMatch.group(1)}';
    final shortMatch = RegExp(r'youtu\.be/([^?&]+)').firstMatch(trimmed);
    if (shortMatch != null) return 'yt:${shortMatch.group(1)}';
    return trimmed;
  }

  static bool isStreamActiveFromMetadata(StreamMetadataModel stream) {
    return stream.status == StreamStatus.live ||
        stream.status == StreamStatus.connecting;
  }

  static DateTime? _inferSessionStart(
    StreamPlaybackEntryModel entry,
    StreamMetadataModel stream,
  ) {
    if (entry.addedAt != null) return entry.addedAt;
    if (entry.isLive && stream.startedAt != null) return stream.startedAt;

    final sid = entry.sessionId.trim();
    if (sid.isNotEmpty) {
      final ms = int.tryParse(sid.split('_').first);
      if (ms != null && ms > 1_000_000_000_000) {
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
      }
    }

    final storedSessions = stream.playbackEntries
        .where(
          (e) =>
              e.url.trim().isNotEmpty ||
              e.sessionId.isNotEmpty ||
              e.addedAt != null,
        )
        .length;
    if (stream.startedAt != null && storedSessions <= 1) {
      return stream.startedAt;
    }
    return null;
  }

  static String formatSessionStartTime(DateTime? start) {
    if (start == null) return '';
    return DateFormat('d MMM, h:mm a').format(start.toLocal());
  }

  static String _statusLabel(
    StreamPlaybackEntryModel entry,
    int indexInNewestFirst,
    List<StreamPlaybackEntryModel> allNewestFirst,
  ) {
    if (entry.isLive) return 'Live Now';

    final firstCompletedIndex =
        allNewestFirst.indexWhere((e) => !e.isLive);
    if (firstCompletedIndex == indexInNewestFirst) {
      return 'Latest Stream';
    }

    return 'Previous Stream';
  }

  static String _labelFor(
    StreamPlaybackPlatform platform,
    String statusLabel,
    String startTimeLabel,
  ) {
    final platformName = platformLabel(platform);
    if (startTimeLabel.isNotEmpty) {
      return '$platformName • $statusLabel • $startTimeLabel';
    }
    return '$platformName • $statusLabel';
  }

  static String platformLabel(StreamPlaybackPlatform platform) {
    return switch (platform) {
      StreamPlaybackPlatform.youtube => 'YouTube',
      StreamPlaybackPlatform.facebook => 'Facebook',
      StreamPlaybackPlatform.twitch => 'Twitch',
      StreamPlaybackPlatform.unknown => 'Stream',
    };
  }

  static String openInLabel(StreamPlaybackPlatform platform) =>
      'Open in ${platformLabel(platform)}';

  static bool shouldShowStreamByDefault(MatchModel match) {
    return hasWatchablePlayback(match);
  }

  /// True when the live broadcast was started in landscape (for fullscreen UX).
  static bool isLandscapeBroadcast(
    MatchModel match, {
    StreamOrientationMode? studioOrientation,
  }) {
    final stored = match.stream.broadcastOrientation?.trim();
    if (stored != null && stored.isNotEmpty) {
      return parseStreamOrientation(stored) == StreamOrientationMode.landscape;
    }
    if (studioOrientation != null) {
      return studioOrientation == StreamOrientationMode.landscape;
    }
    return false;
  }

  /// Picks the playback session a highlight belongs to (by marker session id or
  /// ball event time), so seek switches to the correct parent stream URL.
  static MatchStreamSource? resolveSessionForHighlight(
    MatchModel match, {
    String? sessionId,
    DateTime? eventTime,
  }) {
    final sources = sourcesFor(match).where((s) => s.hasPlayableUrl).toList();
    if (sources.isEmpty) return null;

    final sid = sessionId?.trim() ?? '';
    if (sid.isNotEmpty) {
      for (final source in sources) {
        if (source.sessionId == sid ||
            source.sessionKey == sid ||
            source.effectiveSessionKey == sid) {
          return source;
        }
      }
    }

    if (eventTime != null) {
      for (final source in sources) {
        final start = source.addedAt;
        if (start == null) continue;
        final end = source.endedAt ?? (source.isLive ? DateTime.now() : null);
        if (eventTime.isBefore(start)) continue;
        if (end != null && eventTime.isAfter(end)) continue;
        return source;
      }
      return null;
    }

    return null;
  }

  /// Whether a highlight can be played or shared in a stream (not scoring-only).
  static bool highlightIsStreamable(
    MatchModel match, {
    int? streamOffsetMs,
    String? streamSessionId,
    DateTime? eventTime,
    bool fromReplayMarker = false,
  }) {
    if (streamOffsetMs == null || streamOffsetMs <= 0) return false;

    if (fromReplayMarker) {
      final session = resolveSessionForHighlight(
        match,
        sessionId: streamSessionId,
      );
      return session != null && session.hasPlayableUrl;
    }

    if (eventTime == null) return false;

    final session = resolveSessionForHighlight(
      match,
      sessionId: streamSessionId,
      eventTime: eventTime,
    );
    if (session == null || !session.hasPlayableUrl) return false;

    final start = session.addedAt;
    if (start == null) return false;
    final end = session.endedAt ?? (session.isLive ? DateTime.now() : null);
    if (eventTime.isBefore(start)) return false;
    if (end != null && eventTime.isAfter(end)) return false;
    return true;
  }

  static String? normalizeWatchUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final withScheme = trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'https://$trimmed';
    if (platformFromUrl(withScheme) == StreamPlaybackPlatform.facebook ||
        withScheme.contains('<iframe') ||
        withScheme.contains('data-href') ||
        withScheme.contains('plugins/video.php')) {
      return FacebookUtils.normalizeWatchUrl(withScheme) ?? withScheme;
    }
    return withScheme;
  }

  static String? canonicalWatchUrl(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final normalized = normalizeWatchUrl(trimmed);
    if (normalized == null) return null;
    if (platformFromUrl(normalized) == StreamPlaybackPlatform.youtube) {
      final id = YoutubeUtils.videoIdFromUrl(normalized);
      if (id != null && id.isNotEmpty) {
        return 'https://www.youtube.com/watch?v=$id';
      }
    }
    return normalized;
  }

  static bool isValidWatchUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    if (isPendingWatchUrl(url)) return false;
    final normalized = canonicalWatchUrl(url);
    if (normalized == null) return false;
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme) return false;
    if (platformFromUrl(normalized) == StreamPlaybackPlatform.youtube) {
      return YoutubeUtils.videoIdFromUrl(normalized) != null;
    }
    if (platformFromUrl(normalized) == StreamPlaybackPlatform.facebook) {
      return FacebookUtils.normalizeWatchUrl(normalized) != null;
    }
    return uri.host.isNotEmpty;
  }
}
