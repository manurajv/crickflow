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
    DateTime? streamStartedAt,
  }) {
    final ballHighlights =
        ballEvents.where(HighlightUtils.isHighlight).toList();

    final items = <MatchHighlightItem>[];

    for (final event in ballHighlights) {
      final marker = _markerForBall(replayMarkers, event.id);
      final offsetMs = marker?.streamOffsetMs ??
          _offsetMsFromStreamStart(streamStartedAt, event.timestamp);
      items.add(
        MatchHighlightItem(
          source: MatchHighlightSource.ballEvent,
          ballEvent: event,
          replayMarker: marker,
          label: HighlightUtils.label(event),
          subtitle:
              '${HighlightUtils.overBallLabel(event)} · ${event.commentary}',
          sortKey: offsetMs ?? event.sequence * 1000,
          streamOffsetMs: offsetMs,
          ballEventId: event.id,
        ),
      );
    }

    for (final marker in replayMarkers) {
      if (marker.ballEventId != null &&
          ballHighlights.any((e) => e.id == marker.ballEventId)) {
        continue;
      }
      items.add(MatchHighlightItem.fromReplayMarker(marker));
    }

    items.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return items;
  }

  int? _offsetMsFromStreamStart(DateTime? started, DateTime? eventTime) {
    if (started == null || eventTime == null) return null;
    if (eventTime.isBefore(started)) return null;
    return eventTime.difference(started).inMilliseconds;
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
