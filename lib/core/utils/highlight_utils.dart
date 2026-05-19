import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';

/// Rule-based highlight detection (Phase 3.1 — no ML).
class HighlightUtils {
  HighlightUtils._();

  static const String tagSix = 'six';
  static const String tagFour = 'four';
  static const String tagWicket = 'wicket';

  static bool isHighlight(BallEventModel event) {
    if (event.isHighlight) return true;
    return classify(event).isHighlight;
  }

  static ({bool isHighlight, String? tag}) classify(BallEventModel event) {
    if (event.eventType == BallEventType.wicket) {
      return (isHighlight: true, tag: tagWicket);
    }
    if (event.eventType == BallEventType.runs) {
      if (event.runs >= 6) return (isHighlight: true, tag: tagSix);
      if (event.runs == 4) return (isHighlight: true, tag: tagFour);
    }
    return (isHighlight: false, tag: null);
  }

  static String label(BallEventModel event) {
    final tag = event.highlightTag ?? classify(event).tag;
    return switch (tag) {
      tagSix => 'SIX',
      tagFour => 'FOUR',
      tagWicket => 'WICKET',
      _ => 'Highlight',
    };
  }

  static String overBallLabel(BallEventModel event) =>
      '${event.overNumber}.${event.ballInOver}';
}
