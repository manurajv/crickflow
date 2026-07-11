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

  /// Union playback history from local and remote snapshots.
  static List<StreamPlaybackEntryModel> unionEntries(
    List<StreamPlaybackEntryModel> a,
    List<StreamPlaybackEntryModel> b,
  ) {
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;

    final byKey = <String, StreamPlaybackEntryModel>{};
    for (final entry in [...a, ...b]) {
      final key = entry.sessionId.trim().isNotEmpty
          ? entry.sessionId.trim()
          : sessionKeyFor(entry);
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = entry;
        continue;
      }
      final winner = _pickRicherPlaybackEntry(existing, entry);
      byKey[key] = winner;
    }

    final out = byKey.values.toList()..sort(_compareEntries);
    return out;
  }

  /// Freezes resolved watch URLs onto ended rows (e.g. pending → real link).
  ///
  /// When [forSessionId] is set, only that session's row is updated — never
  /// cross-contaminates prior playback history with a newer session's URL.
  static List<StreamPlaybackEntryModel> finalizeEndedSessionUrls({
    required List<StreamPlaybackEntryModel> entries,
    String? canonicalWatchUrl,
    String? forSessionId,
  }) {
    final canonical = canonicalWatchUrl?.trim() ?? '';
    if (canonical.isEmpty || _isPendingWatchUrl(canonical)) return entries;

    final targetSessionId = forSessionId?.trim() ?? '';

    return [
      for (final entry in entries)
        if (!entry.isLive &&
            (entry.url.trim().isEmpty || _isPendingWatchUrl(entry.url)) &&
            _entryMatchesSessionTarget(entry, targetSessionId))
          entry.copyWith(url: canonical)
        else
          entry,
    ];
  }

  static bool _entryMatchesSessionTarget(
    StreamPlaybackEntryModel entry,
    String targetSessionId,
  ) {
    if (targetSessionId.isEmpty) return true;
    final entrySid = entry.sessionId.trim();
    if (entrySid.isNotEmpty && entrySid == targetSessionId) return true;
    final pendingSid = _pendingSessionId(entry.url);
    return pendingSid != null && pendingSid == targetSessionId;
  }

  static String? _pendingSessionId(String url) {
    if (!_isPendingWatchUrl(url)) return null;
    final parts = url.trim().split(':');
    if (parts.length >= 3) return parts[2].trim();
    return null;
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
        final canonicalKey = _urlIdentityKey(canonical);
        final usedByOtherSession = entries.any(
          (e) =>
              !e.isLive &&
              e.sessionId.trim() != live.sessionId.trim() &&
              _urlIdentityKey(e.url) == canonicalKey &&
              canonicalKey.isNotEmpty,
        );
        if (!usedByOtherSession) {
          final updated = [...entries];
          updated[liveIdx] = live.copyWith(url: canonical);
          return updated;
        }
      }
      return entries;
    }

    if (hasCanonical) {
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

  /// Resolved watch URL for the current live row only (null when still pending).
  static String? activeLiveWatchUrl(List<StreamPlaybackEntryModel> entries) {
    final liveRows = entries.where((e) => e.isLive).toList()
      ..sort(_compareEntries);
    if (liveRows.isEmpty) return null;
    final url = liveRows.first.url.trim();
    if (url.isEmpty || _isPendingWatchUrl(url)) return null;
    return url;
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
    return attachWatchUrlToSession(
      existing: existing,
      url: url,
      sessionId: sessionId,
      sessionStartedAt: sessionStartedAt,
      addedByUserId: addedByUserId,
      addedByName: addedByName,
      requireLive: true,
    );
  }

  /// Attaches a public watch URL to exactly one session — by [sessionId] when
  /// provided, otherwise the current live row. Never mutates prior sessions.
  static List<StreamPlaybackEntryModel> attachWatchUrlToSession({
    required List<StreamPlaybackEntryModel> existing,
    required String url,
    String? sessionId,
    DateTime? sessionStartedAt,
    String? addedByUserId,
    String? addedByName,
    bool requireLive = false,
  }) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return existing;

    final sid = sessionId?.trim() ?? '';
    var targetIndex = -1;

    if (sid.isNotEmpty) {
      targetIndex = existing.indexWhere((e) => e.sessionId.trim() == sid);
    }
    if (targetIndex < 0) {
      targetIndex = existing.lastIndexWhere((e) => e.isLive);
    }

    if (targetIndex >= 0) {
      final updated = [...existing];
      final target = updated[targetIndex];
      if (requireLive && !target.isLive) return existing;
      updated[targetIndex] = target.copyWith(
        url: trimmed,
        isLive: target.isLive || !requireLive,
        sessionId: target.sessionId.isNotEmpty
            ? target.sessionId
            : (sid.isNotEmpty
                ? sid
                : _fallbackSessionId(target.addedAt ?? DateTime.now(), trimmed)),
        addedAt: target.addedAt ?? sessionStartedAt,
        endedAt: target.isLive ? null : target.endedAt,
        addedByUserId: addedByUserId ?? target.addedByUserId,
        addedByName: addedByName ?? target.addedByName,
      );
      updated.sort(_compareEntries);
      return updated;
    }

    if (requireLive) {
      final started = sessionStartedAt ?? DateTime.now();
      return beginLiveSession(
        existing: existing,
        sessionId: sid.isNotEmpty ? sid : _fallbackSessionId(started, trimmed),
        url: trimmed,
        addedAt: started,
        addedByUserId: addedByUserId,
        addedByName: addedByName,
      );
    }

    return existing;
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

  static String _fallbackSessionId(DateTime addedAt, String url) {
    return '${addedAt.toUtc().millisecondsSinceEpoch}_${url.hashCode}';
  }

  static StreamPlaybackEntryModel _pickRicherPlaybackEntry(
    StreamPlaybackEntryModel existing,
    StreamPlaybackEntryModel incoming,
  ) {
    final existingScore = _playbackEntryRichness(existing);
    final incomingScore = _playbackEntryRichness(incoming);
    if (incomingScore > existingScore) return incoming;
    if (existingScore > incomingScore) return existing;
    if (incoming.isLive && !existing.isLive) return incoming;
    return existing;
  }

  static int _playbackEntryRichness(StreamPlaybackEntryModel entry) {
    final url = entry.url.trim();
    if (url.isNotEmpty && !_isPendingWatchUrl(url)) return 3;
    if (_isPendingWatchUrl(url)) return 1;
    if (url.isNotEmpty) return 2;
    return 0;
  }
}
