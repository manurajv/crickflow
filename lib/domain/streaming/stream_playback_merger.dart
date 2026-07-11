import '../../core/constants/enums.dart';
import '../../data/models/stream_playback_entry_model.dart';
import '../../data/models/match_model.dart';

/// Merges watch URLs into ordered playback history (newest first in UI).
class StreamPlaybackMerger {
  StreamPlaybackMerger._();

  /// Collect stored sessions only — each entry keeps its own [addedAt]/[endedAt].
  static List<StreamPlaybackEntryModel> collect(StreamMetadataModel stream) {
    final stored = stream.playbackEntries
        .where(
          (e) =>
              e.url.trim().isNotEmpty ||
              e.sessionId.isNotEmpty ||
              e.addedAt != null,
        )
        .toList();

    if (stored.isNotEmpty) {
      final sorted = _dedupeSessions(
        List<StreamPlaybackEntryModel>.from(stored)..sort(_compareEntries),
      );
      return _alignWithActiveStream(stream, sorted);
    }

    // Legacy matches before playbackEntries existed.
    final legacy = <StreamPlaybackEntryModel>[];
    final primary = stream.youtubeWatchUrl?.trim();
    if (primary != null && primary.isNotEmpty) {
      legacy.add(
        StreamPlaybackEntryModel(
          url: primary,
          addedAt: stream.startedAt,
          isLive: stream.status == StreamStatus.live ||
              stream.status == StreamStatus.connecting,
        ),
      );
    }
    final secondary = stream.secondaryYoutubeWatchUrl?.trim();
    if (secondary != null && secondary.isNotEmpty) {
      legacy.add(
        StreamPlaybackEntryModel(
          url: secondary,
          addedAt: stream.startedAt,
          isLive: stream.status == StreamStatus.live ||
              stream.status == StreamStatus.connecting,
        ),
      );
    }
    legacy.sort(_compareEntries);
    return _alignWithActiveStream(stream, legacy);
  }

  static String sessionKeyFor(StreamPlaybackEntryModel entry) {
    if (entry.sessionId.trim().isNotEmpty) return entry.sessionId.trim();
    final start = entry.addedAt?.toUtc().millisecondsSinceEpoch ?? 0;
    final end = entry.endedAt?.toUtc().millisecondsSinceEpoch ?? 0;
    return '${start}_${end}_${entry.isLive}_${entry.url.hashCode}';
  }

  static List<StreamPlaybackEntryModel> _dedupeSessions(
    List<StreamPlaybackEntryModel> entries,
  ) {
    final seenIds = <String>{};
    final out = <StreamPlaybackEntryModel>[];
    for (final entry in entries) {
      final sid = entry.sessionId.trim();
      if (sid.isNotEmpty) {
        if (!seenIds.add(sid)) continue;
      }
      out.add(entry);
    }
    return out;
  }

  static bool _isPendingWatchUrl(String url) => url.trim().startsWith('pending:');

  /// Ensures an in-progress YouTube live appears even when only [youtubeWatchUrl]
  /// was synced, or upgrades a pending placeholder to the real watch link.
  static List<StreamPlaybackEntryModel> _alignWithActiveStream(
    StreamMetadataModel stream,
    List<StreamPlaybackEntryModel> entries,
  ) {
    final active = stream.status == StreamStatus.live ||
        stream.status == StreamStatus.connecting;
    if (!active) return entries;

    final canonical = stream.youtubeWatchUrl?.trim() ?? '';
    final hasCanonical =
        canonical.isNotEmpty && !_isPendingWatchUrl(canonical);

    final liveIdx = entries.lastIndexWhere((e) => e.isLive);
    if (liveIdx >= 0) {
      final live = entries[liveIdx];
      if (hasCanonical && _isPendingWatchUrl(live.url)) {
        final updated = [...entries];
        updated[liveIdx] = live.copyWith(url: canonical);
        return updated;
      }
      return entries;
    }

    if (hasCanonical && entries.isEmpty) {
      final augmented = [
        ...entries,
        StreamPlaybackEntryModel(
          url: canonical,
          addedAt: stream.startedAt,
          isLive: true,
        ),
      ]..sort(_compareEntries);
      return augmented;
    }

    return entries;
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

  /// Starts a new live session — ends other live rows only; replays are untouched.
  static List<StreamPlaybackEntryModel> beginLiveSession({
    required List<StreamPlaybackEntryModel> existing,
    required String sessionId,
    required String url,
    required DateTime addedAt,
    String? addedByUserId,
    String? addedByName,
    String? label,
  }) {
    final trimmed = url.trim();
    if (trimmed.isEmpty || sessionId.trim().isEmpty) return existing;

    final updated = [
      for (final entry in existing)
        if (entry.isLive)
          entry.copyWith(isLive: false, endedAt: addedAt)
        else
          entry,
      StreamPlaybackEntryModel(
        sessionId: sessionId,
        url: trimmed,
        addedAt: addedAt,
        isLive: true,
        addedByUserId: addedByUserId,
        addedByName: addedByName,
        label: label ?? '',
      ),
    ];
    updated.sort(_compareEntries);
    return updated;
  }

  /// Adds a new live session or manual link — keeps prior sessions in history.
  static List<StreamPlaybackEntryModel> appendSession({
    required List<StreamPlaybackEntryModel> existing,
    required String? url,
    bool isLive = true,
    DateTime? addedAt,
    DateTime? endedAt,
    String? sessionId,
    String? addedByUserId,
    String? addedByName,
    String? label,
    bool forceNewSession = false,
  }) {
    if (url == null || url.trim().isEmpty) return existing;

    final trimmed = url.trim();
    final now = addedAt ?? DateTime.now();
    final sid = sessionId?.trim() ?? '';

    if (!isLive) {
      return _endLiveSessions(
        existing: existing,
        url: trimmed,
        endedAt: endedAt ?? now,
        addedAt: addedAt,
        addedByUserId: addedByUserId,
        addedByName: addedByName,
        label: label,
      );
    }

    if (forceNewSession) {
      return beginLiveSession(
        existing: existing,
        sessionId: sid.isNotEmpty ? sid : _fallbackSessionId(now, trimmed),
        url: trimmed,
        addedAt: now,
        addedByUserId: addedByUserId,
        addedByName: addedByName,
        label: label,
      );
    }

    final liveIndex = existing.lastIndexWhere((e) => e.isLive);
    if (liveIndex >= 0) {
      final updated = [...existing];
      final live = updated[liveIndex];
      updated[liveIndex] = live.copyWith(
        url: trimmed,
        isLive: true,
        sessionId: live.sessionId.isNotEmpty
            ? live.sessionId
            : (sid.isNotEmpty ? sid : _fallbackSessionId(now, trimmed)),
        addedAt: live.addedAt ?? now,
        endedAt: null,
      );
      updated.sort(_compareEntries);
      return updated;
    }

    return beginLiveSession(
      existing: existing,
      sessionId: sid.isNotEmpty ? sid : _fallbackSessionId(now, trimmed),
      url: trimmed,
      addedAt: now,
      addedByUserId: addedByUserId,
      addedByName: addedByName,
      label: label,
    );
  }

  static List<StreamPlaybackEntryModel> _endLiveSessions({
    required List<StreamPlaybackEntryModel> existing,
    required String url,
    required DateTime endedAt,
    DateTime? addedAt,
    String? addedByUserId,
    String? addedByName,
    String? label,
  }) {
    final updated = [...existing];
    var matched = false;
    for (var i = updated.length - 1; i >= 0; i--) {
      if (!updated[i].isLive) continue;
      updated[i] = updated[i].copyWith(isLive: false, endedAt: endedAt);
      matched = true;
      break;
    }
    if (!matched) {
      updated.add(
        StreamPlaybackEntryModel(
          url: url,
          addedAt: addedAt ?? endedAt,
          endedAt: endedAt,
          isLive: false,
          addedByUserId: addedByUserId,
          addedByName: addedByName,
          label: label ?? '',
        ),
      );
    }
    updated.sort(_compareEntries);
    return updated;
  }

  /// Register or update a watch URL when going live, ending, or pasting a link.
  static List<StreamPlaybackEntryModel> merge({
    required List<StreamPlaybackEntryModel> existing,
    required String? url,
    required bool isLive,
    DateTime? addedAt,
    DateTime? endedAt,
    String? sessionId,
    String? addedByUserId,
    String? addedByName,
    String? label,
  }) {
    if (url == null || url.trim().isEmpty) {
      return existing;
    }

    final hasLive = existing.any((e) => e.isLive);
    return appendSession(
      existing: existing,
      url: url,
      isLive: isLive,
      addedAt: addedAt,
      endedAt: endedAt,
      sessionId: sessionId,
      addedByUserId: addedByUserId,
      addedByName: addedByName,
      label: label,
      forceNewSession: isLive && !hasLive,
    );
  }

  static String? latestWatchUrl(List<StreamPlaybackEntryModel> entries) {
    if (entries.isEmpty) return null;
    final sorted = List<StreamPlaybackEntryModel>.from(entries)
      ..sort(_compareEntries);
    for (final entry in sorted) {
      if (!_isPendingWatchUrl(entry.url)) return entry.url;
    }
    return null;
  }

  /// Marks every active live session as ended (preserves each session's times).
  static List<StreamPlaybackEntryModel> endAllLiveSessions({
    required List<StreamPlaybackEntryModel> existing,
    DateTime? endedAt,
  }) {
    final end = endedAt ?? DateTime.now();
    return existing
        .map(
          (e) => e.isLive ? e.copyWith(isLive: false, endedAt: end) : e,
        )
        .toList();
  }

  /// Updates the current live entry's watch URL (e.g. YouTube auto after API).
  /// Never modifies ended replay sessions.
  static List<StreamPlaybackEntryModel> syncLiveWatchUrl({
    required List<StreamPlaybackEntryModel> existing,
    required String url,
    DateTime? sessionStartedAt,
    String? sessionId,
    String? addedByUserId,
    String? addedByName,
  }) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return existing;

    final liveIndex = existing.lastIndexWhere((e) => e.isLive);
    if (liveIndex >= 0) {
      final updated = [...existing];
      final live = updated[liveIndex];
      updated[liveIndex] = live.copyWith(
        url: trimmed,
        isLive: true,
        sessionId: live.sessionId.isNotEmpty
            ? live.sessionId
            : (sessionId ?? _fallbackSessionId(live.addedAt ?? DateTime.now(), trimmed)),
        addedAt: live.addedAt ?? sessionStartedAt,
        endedAt: null,
      );
      return updated;
    }

    final started = sessionStartedAt ?? DateTime.now();
    return beginLiveSession(
      existing: existing,
      sessionId: sessionId ?? _fallbackSessionId(started, trimmed),
      url: trimmed,
      addedAt: started,
      addedByUserId: addedByUserId,
      addedByName: addedByName,
    );
  }

  static String _fallbackSessionId(DateTime addedAt, String url) {
    return '${addedAt.toUtc().millisecondsSinceEpoch}_${url.hashCode}';
  }
}
