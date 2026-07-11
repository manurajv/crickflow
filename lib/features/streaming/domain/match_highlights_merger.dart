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
      final parentSession = match != null &&
              marker == null &&
              event.timestamp != null
          ? MatchStreamPlayback.resolveSessionForHighlight(
              match,
              eventTime: event.timestamp,
            )
          : null;

      int? streamOffset;
      String? streamSessionId;

      if (marker != null && marker.streamOffsetMs > 0) {
        streamSessionId = marker.streamSessionId.isNotEmpty
            ? marker.streamSessionId
            : parentSession?.sessionId;
        if (match != null &&
            MatchStreamPlayback.highlightIsStreamable(
              match,
              streamOffsetMs: marker.streamOffsetMs,
              streamSessionId: streamSessionId,
              eventTime: event.timestamp ?? marker.createdAt,
              fromReplayMarker: true,
            )) {
          streamOffset = marker.streamOffsetMs;
        } else {
          streamSessionId = null;
        }
      } else if (parentSession != null && event.timestamp != null) {
        final computed = replayMarkerOffsetMs(
          sessionStartedAt: parentSession.addedAt,
          eventTime: event.timestamp,
        );
        if (computed > 0 &&
            match != null &&
            MatchStreamPlayback.highlightIsStreamable(
              match,
              streamOffsetMs: computed,
              streamSessionId: parentSession.sessionId,
              eventTime: event.timestamp,
            )) {
          streamOffset = computed;
          streamSessionId = parentSession.sessionId;
        }
      }

      items.add(
        MatchHighlightItem(
          source: MatchHighlightSource.ballEvent,
          ballEvent: event,
          replayMarker: marker,
          label: HighlightUtils.label(event),
          subtitle:
              '${HighlightUtils.overBallLabel(event)} · ${event.commentary}',
          sortKey: _ballSortKey(event),
          streamOffsetMs: streamOffset,
          ballEventId: event.id,
          streamSessionId: streamSessionId,
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
      final sessionId = marker.streamSessionId.isNotEmpty
          ? marker.streamSessionId
          : parentSession?.sessionId;
      final streamable = match != null &&
          MatchStreamPlayback.highlightIsStreamable(
            match,
            streamOffsetMs: marker.streamOffsetMs,
            streamSessionId: sessionId,
            fromReplayMarker: true,
          );
      items.add(
        MatchHighlightItem(
          source: MatchHighlightSource.replayMarker,
          replayMarker: marker,
          label: ReplayMarkerUtils.label(marker),
          subtitle: marker.label,
          sortKey: _orphanMarkerSortKey(marker, ballHighlights),
          streamOffsetMs: streamable && marker.streamOffsetMs > 0
              ? marker.streamOffsetMs
              : null,
          ballEventId: marker.ballEventId,
          streamSessionId: sessionId,
        ),
      );
    }

    items.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return items;
  }

  /// Newest-first — uses match [sequence] so live/offline balls without
  /// timestamps still sort above older persisted highlights.
  static int _ballSortKey(BallEventModel event) => event.sequence * 2;

  /// Orphan replay markers slot into sequence space beside ball highlights.
  static int _orphanMarkerSortKey(
    ReplayMarkerModel marker,
    List<BallEventModel> ballHighlights,
  ) {
    final linkedId = marker.ballEventId;
    if (linkedId != null) {
      for (final ball in ballHighlights) {
        if (ball.id == linkedId) return ball.sequence * 2 + 1;
      }
    }

    final created = marker.createdAt;
    if (created != null) {
      var anchorSeq = 0;
      for (final ball in ballHighlights) {
        final ts = ball.timestamp;
        if (ts != null && !ts.isAfter(created) && ball.sequence > anchorSeq) {
          anchorSeq = ball.sequence;
        }
      }
      if (anchorSeq > 0) return anchorSeq * 2 + 1;

      var nextSeq = 0;
      for (final ball in ballHighlights) {
        final ts = ball.timestamp;
        if (ts != null && ts.isAfter(created)) {
          nextSeq = nextSeq == 0
              ? ball.sequence
              : (nextSeq < ball.sequence ? nextSeq : ball.sequence);
        }
      }
      if (nextSeq > 0) return (nextSeq - 1) * 2 + 1;
    }

    final maxSeq = _maxBallSequence(ballHighlights);
    if (created != null) return maxSeq * 2 + 1;
    return marker.streamOffsetMs > 0 ? marker.streamOffsetMs : maxSeq * 2 + 1;
  }

  static int _maxBallSequence(List<BallEventModel> ballHighlights) {
    if (ballHighlights.isEmpty) return 0;
    return ballHighlights
        .map((e) => e.sequence)
        .reduce((a, b) => a > b ? a : b);
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
