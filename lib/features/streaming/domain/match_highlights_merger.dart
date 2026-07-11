import '../../../data/models/match_model.dart';
import '../../../domain/streaming/match_stream_playback.dart';
import '../../../domain/streaming/replay_marker_constants.dart';
import '../../../core/utils/highlight_utils.dart';
import '../../../data/models/ball_event_model.dart';
import '../data/models/replay_marker_model.dart';
import '../domain/streaming_enums.dart';

/// Unified highlight row from ball events and stream replay markers.
class MatchHighlightItem {
  const MatchHighlightItem({
    required this.source,
    this.ballEvent,
    this.replayMarker,
    required this.label,
    required this.subtitle,
    required this.sortKey,
    this.streamOffsetMs,
    this.ballEventId,
    this.streamSessionId,
  }) : assert(ballEvent != null || replayMarker != null);

  factory MatchHighlightItem.fromBallEvent(BallEventModel event) {
    return MatchHighlightItem(
      source: MatchHighlightSource.ballEvent,
      ballEvent: event,
      label: HighlightUtils.label(event),
      subtitle: '${HighlightUtils.overBallLabel(event)} · ${event.commentary}',
      sortKey: event.sequence * 1000,
      ballEventId: event.id,
    );
  }

  factory MatchHighlightItem.fromReplayMarker(ReplayMarkerModel marker) {
    return MatchHighlightItem(
      source: MatchHighlightSource.replayMarker,
      replayMarker: marker,
      label: ReplayMarkerUtils.label(marker),
      subtitle: marker.label,
      sortKey: marker.streamOffsetMs,
      streamOffsetMs: marker.streamOffsetMs,
      ballEventId: marker.ballEventId,
      streamSessionId: marker.streamSessionId,
    );
  }

  final MatchHighlightSource source;
  final BallEventModel? ballEvent;
  final ReplayMarkerModel? replayMarker;
  final String label;
  final String subtitle;
  final int sortKey;
  final int? streamOffsetMs;
  final String? ballEventId;
  final String? streamSessionId;

  String? get highlightTag {
    if (ballEvent != null) {
      return ballEvent!.highlightTag ?? HighlightUtils.classify(ballEvent!).tag;
    }
    return switch (replayMarker?.kind) {
      ReplayMarkerKind.wicket => HighlightUtils.tagWicket,
      ReplayMarkerKind.six => HighlightUtils.tagSix,
      ReplayMarkerKind.four => HighlightUtils.tagFour,
      _ => 'milestone',
    };
  }
}

enum MatchHighlightSource { ballEvent, replayMarker }

/// Merges scoring highlights with stream replay flags (deduped by ballEventId).
class MatchHighlightsMerger {
  const MatchHighlightsMerger();

  List<MatchHighlightItem> merge({
    required List<BallEventModel> ballEvents,
    required List<ReplayMarkerModel> replayMarkers,
    MatchModel? match,
  }) {
    final ballHighlights =
        ballEvents.where(HighlightUtils.isHighlight).toList();

    final items = <MatchHighlightItem>[];

    for (final event in ballHighlights) {
      final marker = _markerForBall(replayMarkers, event.id);
      final parentSession = match != null
          ? MatchStreamPlayback.resolveSessionForHighlight(
              match,
              sessionId: marker?.streamSessionId,
              eventTime: event.timestamp,
            )
          : null;
      final sessionStart =
          parentSession?.addedAt ?? match?.stream.startedAt;
      final markerOffset = marker != null && marker.streamOffsetMs > 0
          ? marker.streamOffsetMs
          : null;
      final computedOffset = markerOffset ??
          replayMarkerOffsetMs(
            sessionStartedAt: sessionStart,
            eventTime: event.timestamp,
          );
      final streamOffset =
          computedOffset > 0 ? computedOffset : null;
      items.add(
        MatchHighlightItem(
          source: MatchHighlightSource.ballEvent,
          ballEvent: event,
          replayMarker: marker,
          label: HighlightUtils.label(event),
          subtitle:
              '${HighlightUtils.overBallLabel(event)} · ${event.commentary}',
          sortKey: _chronologicalKeyForBall(event),
          streamOffsetMs: streamOffset,
          ballEventId: event.id,
          streamSessionId:
              marker?.streamSessionId ?? parentSession?.sessionId,
        ),
      );
    }

    for (final marker in replayMarkers) {
      if (marker.ballEventId != null &&
          ballHighlights.any((e) => e.id == marker.ballEventId)) {
        continue;
      }
      final parentSession = match != null
          ? MatchStreamPlayback.resolveSessionForHighlight(
              match,
              sessionId: marker.streamSessionId,
              eventTime: marker.createdAt,
            )
          : null;
      items.add(
        MatchHighlightItem(
          source: MatchHighlightSource.replayMarker,
          replayMarker: marker,
          label: ReplayMarkerUtils.label(marker),
          subtitle: marker.label,
          sortKey: _chronologicalKeyForMarker(marker),
          streamOffsetMs:
              marker.streamOffsetMs > 0 ? marker.streamOffsetMs : null,
          ballEventId: marker.ballEventId,
          streamSessionId:
              marker.streamSessionId.isNotEmpty
                  ? marker.streamSessionId
                  : parentSession?.sessionId,
        ),
      );
    }

    items.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return items;
  }

  /// Newest-first ordering — match time, not stream offset (resets per go-live).
  static int _chronologicalKeyForBall(BallEventModel event) {
    final ts = event.timestamp?.millisecondsSinceEpoch;
    if (ts != null && ts > 0) return ts;
    return event.sequence;
  }

  static int _chronologicalKeyForMarker(ReplayMarkerModel marker) {
    final ts = marker.createdAt?.millisecondsSinceEpoch;
    if (ts != null && ts > 0) return ts;
    return marker.streamOffsetMs;
  }

  ReplayMarkerModel? _markerForBall(
    List<ReplayMarkerModel> markers,
    String ballEventId,
  ) {
    for (final marker in markers) {
      if (marker.ballEventId == ballEventId) return marker;
    }
    return null;
  }
}

/// Display helpers for replay markers in highlights UI.
class ReplayMarkerUtils {
  ReplayMarkerUtils._();

  static String label(ReplayMarkerModel marker) => switch (marker.kind) {
        ReplayMarkerKind.wicket => 'WICKET',
        ReplayMarkerKind.six => 'SIX',
        ReplayMarkerKind.four => 'FOUR',
        ReplayMarkerKind.century => 'CENTURY',
        ReplayMarkerKind.milestone => 'MILESTONE',
        ReplayMarkerKind.custom => 'REPLAY',
      };
}
