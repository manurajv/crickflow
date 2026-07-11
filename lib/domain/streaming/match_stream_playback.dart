import 'package:intl/intl.dart';

import '../../core/constants/enums.dart';
import '../../core/utils/facebook_utils.dart';
import '../../core/utils/youtube_utils.dart';
import '../../data/models/match_model.dart';
import '../../data/models/stream_playback_entry_model.dart';
import 'stream_playback_merger.dart';

/// A single watchable stream angle (YouTube, Facebook, etc.).
class MatchStreamSource {
  const MatchStreamSource({
    required this.url,
    required this.label,
    this.sessionKey = '',
    this.platform = StreamPlaybackPlatform.unknown,
    this.isLive = false,
    this.addedAt,
    this.endedAt,
  });

  final String url;
  final String label;
  final String sessionKey;
  final StreamPlaybackPlatform platform;
  final bool isLive;
  final DateTime? addedAt;
  final DateTime? endedAt;

  String get effectiveSessionKey =>
      sessionKey.isNotEmpty ? sessionKey : url;

  bool get isEmbeddable =>
      platform == StreamPlaybackPlatform.youtube ||
      platform == StreamPlaybackPlatform.facebook;
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

  static bool hasWatchablePlayback(MatchModel match) =>
      sourcesFor(match).isNotEmpty;

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
    return active && !hasWatchablePlayback(match);
  }

  /// Newest / live-first ordering for the scorecard switcher.
  static List<MatchStreamSource> sourcesFor(MatchModel match) {
    final entries = StreamPlaybackMerger.collect(match.stream);
    final out = <MatchStreamSource>[];
    final usedKeys = <String>{};

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final url = _resolveEntryUrl(entry, match.stream);
      var sessionKey = StreamPlaybackMerger.sessionKeyFor(entry);
      if (usedKeys.contains(sessionKey)) {
        sessionKey = '${sessionKey}_$i';
      }
      usedKeys.add(sessionKey);

      out.add(
        MatchStreamSource(
          sessionKey: sessionKey,
          url: url,
          label: _labelFor(entry, url),
          platform: platformFromUrl(url.isNotEmpty ? url : entry.url),
          isLive: entry.isLive,
          addedAt: entry.addedAt,
          endedAt: entry.endedAt,
        ),
      );
    }
    return out;
  }

  static String _resolveEntryUrl(
    StreamPlaybackEntryModel entry,
    StreamMetadataModel stream,
  ) {
    final trimmed = entry.url.trim();
    if (trimmed.isNotEmpty && !isPendingWatchUrl(trimmed)) return trimmed;
    if (entry.isLive) {
      final fallback = stream.youtubeWatchUrl?.trim();
      if (fallback != null &&
          fallback.isNotEmpty &&
          !isPendingWatchUrl(fallback)) {
        return fallback;
      }
    }
    return trimmed;
  }

  static String _labelFor(StreamPlaybackEntryModel entry, String resolvedUrl) {
    final platform =
        platformLabel(platformFromUrl(resolvedUrl.isNotEmpty ? resolvedUrl : entry.url));
    final fmt = DateFormat.jm();

    if (entry.isLive) {
      final start = entry.addedAt;
      if (start != null) {
        return 'Live · $platform · ${fmt.format(start.toLocal())}';
      }
      return 'Live · $platform';
    }

    final start = entry.addedAt;
    final end = entry.endedAt;
    if (start != null && end != null) {
      return 'Replay · $platform · ${fmt.format(start.toLocal())} – ${fmt.format(end.toLocal())}';
    }
    if (start != null) {
      return 'Replay · $platform · ${fmt.format(start.toLocal())}';
    }
    return 'Replay · $platform';
  }

  static String platformLabel(StreamPlaybackPlatform platform) {
    return switch (platform) {
      StreamPlaybackPlatform.youtube => 'YouTube',
      StreamPlaybackPlatform.facebook => 'Facebook',
      StreamPlaybackPlatform.twitch => 'Twitch',
      StreamPlaybackPlatform.unknown => 'Browser',
    };
  }

  static String openInLabel(StreamPlaybackPlatform platform) =>
      'Open in ${platformLabel(platform)}';

  static bool shouldShowStreamByDefault(MatchModel match) {
    return hasWatchablePlayback(match);
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

  static bool isValidWatchUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    if (isPendingWatchUrl(url)) return false;
    final normalized = normalizeWatchUrl(url);
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