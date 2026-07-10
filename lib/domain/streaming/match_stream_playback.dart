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
    this.platform = StreamPlaybackPlatform.unknown,
    this.isLive = false,
    this.addedAt,
  });

  final String url;
  final String label;
  final StreamPlaybackPlatform platform;
  final bool isLive;
  final DateTime? addedAt;

  bool get isEmbeddable =>
      platform == StreamPlaybackPlatform.youtube ||
      platform == StreamPlaybackPlatform.facebook;
}

enum StreamPlaybackPlatform { youtube, facebook, twitch, unknown }

/// Helpers for deciding when a match has watchable streams and listing them.
class MatchStreamPlayback {
  MatchStreamPlayback._();

  static StreamPlaybackPlatform platformFromUrl(String url) {
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

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      out.add(
        MatchStreamSource(
          url: entry.url,
          label: _labelFor(entry, i, entries.length),
          platform: platformFromUrl(entry.url),
          isLive: entry.isLive,
          addedAt: entry.addedAt,
        ),
      );
    }
    return out;
  }

  static String _labelFor(
    StreamPlaybackEntryModel entry,
    int index,
    int total,
  ) {
    final who = entry.addedByName?.trim();
    final suffix =
        who != null && who.isNotEmpty ? ' ($who)' : '';

    String base;
    if (entry.label.trim().isNotEmpty) {
      base = entry.label.trim();
    } else if (entry.isLive) {
      base = index == 0 ? 'Latest live' : 'Live ${index + 1}';
    } else {
      final at = entry.addedAt;
      if (at != null) {
        final time = DateFormat.jm().format(at.toLocal());
        base = total > 1 ? 'Replay · $time' : 'Replay';
      } else {
        base = total > 1 ? 'Stream ${index + 1}' : 'Stream';
      }
    }
    return '$base$suffix';
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
    if (!hasWatchablePlayback(match)) return false;
    if (match.stream.status == StreamStatus.live ||
        match.stream.status == StreamStatus.connecting) {
      return true;
    }
    if (match.status == MatchStatus.live ||
        match.status == MatchStatus.inningsBreak) {
      return true;
    }
    return match.status == MatchStatus.completed;
  }

  static String? normalizeWatchUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  static bool isValidWatchUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
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