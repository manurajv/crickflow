import '../../core/constants/enums.dart';
import '../../core/utils/youtube_utils.dart';
import '../../data/models/stream_playback_entry_model.dart';
import '../../data/models/match_model.dart';

/// Merges watch URLs into ordered playback history (newest first in UI).
class StreamPlaybackMerger {
  StreamPlaybackMerger._();

  static String? _videoKey(String url) =>
      YoutubeUtils.videoIdFromUrl(url) ?? url.trim();

  /// Collect all entries including legacy primary/secondary URL fields.
  static List<StreamPlaybackEntryModel> collect(StreamMetadataModel stream) {
    final list = List<StreamPlaybackEntryModel>.from(stream.playbackEntries);

    bool hasUrl(String url) {
      final key = _videoKey(url);
      if (key == null) return false;
      return list.any((e) => _videoKey(e.url) == key);
    }

    void ensureLegacy(
      String? url, {
      DateTime? addedAt,
      String? label,
      bool isLive = false,
    }) {
      final trimmed = url?.trim();
      if (trimmed == null || trimmed.isEmpty || hasUrl(trimmed)) return;
      list.add(
        StreamPlaybackEntryModel(
          url: trimmed,
          addedAt: addedAt,
          label: label ?? '',
          isLive: isLive,
        ),
      );
    }

    final isMatchLive = stream.status == StreamStatus.live ||
        stream.status == StreamStatus.connecting;

    ensureLegacy(
      stream.youtubeWatchUrl,
      addedAt: stream.startedAt,
      label: stream.cameraALabel,
      isLive: isMatchLive && stream.playbackEntries.isEmpty,
    );
    ensureLegacy(
      stream.secondaryYoutubeWatchUrl,
      addedAt: stream.startedAt,
      label: stream.cameraBLabel,
      isLive: isMatchLive,
    );

    list.sort(_compareEntries);
    return list;
  }

  static int _compareEntries(
    StreamPlaybackEntryModel a,
    StreamPlaybackEntryModel b,
  ) {
    if (a.isLive != b.isLive) {
      return a.isLive ? -1 : 1;
    }
    final aAt = a.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bAt = b.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bAt.compareTo(aAt);
  }

  /// Adds a new live session or manual link — keeps prior sessions in history.
  static List<StreamPlaybackEntryModel> appendSession({
    required List<StreamPlaybackEntryModel> existing,
    required String? url,
    bool isLive = true,
    DateTime? addedAt,
    String? addedByUserId,
    String? addedByName,
    String? label,
    bool forceNewSession = false,
  }) {
    if (url == null || url.trim().isEmpty) return existing;

    final trimmed = url.trim();
    final now = addedAt ?? DateTime.now();
    final key = _videoKey(trimmed)!;

    if (!isLive) {
      final updated = [...existing];
      for (var i = 0; i < updated.length; i++) {
        if (_videoKey(updated[i].url) == key && updated[i].isLive) {
          updated[i] = updated[i].copyWith(isLive: false);
        }
      }
      updated.sort(_compareEntries);
      return updated;
    }

    final hasActiveSameUrl = existing.any(
      (e) => e.isLive && _videoKey(e.url) == key,
    );
    if (!forceNewSession && hasActiveSameUrl) {
      return merge(
        existing: existing,
        url: trimmed,
        isLive: true,
        addedAt: now,
        addedByUserId: addedByUserId,
        addedByName: addedByName,
        label: label,
      );
    }

    final updated = [
      for (final entry in existing)
        if (entry.isLive && _videoKey(entry.url) == key)
          entry.copyWith(isLive: false)
        else
          entry,
      StreamPlaybackEntryModel(
        url: trimmed,
        addedAt: now,
        isLive: true,
        addedByUserId: addedByUserId,
        addedByName: addedByName,
        label: label ?? '',
      ),
    ];
    updated.sort(_compareEntries);
    return updated;
  }

  /// Register or update a watch URL when going live, ending, or pasting a link.
  static List<StreamPlaybackEntryModel> merge({
    required List<StreamPlaybackEntryModel> existing,
    required String? url,
    required bool isLive,
    DateTime? addedAt,
    String? addedByUserId,
    String? addedByName,
    String? label,
  }) {
    if (url == null || url.trim().isEmpty) {
      return existing;
    }

    if (isLive) {
      return appendSession(
        existing: existing,
        url: url,
        isLive: true,
        addedAt: addedAt,
        addedByUserId: addedByUserId,
        addedByName: addedByName,
        label: label,
        forceNewSession: true,
      );
    }

    return appendSession(
      existing: existing,
      url: url,
      isLive: false,
      addedAt: addedAt,
    );
  }

  static String? latestWatchUrl(List<StreamPlaybackEntryModel> entries) {
    if (entries.isEmpty) return null;
    final sorted = List<StreamPlaybackEntryModel>.from(entries)
      ..sort(_compareEntries);
    return sorted.first.url;
  }
}
