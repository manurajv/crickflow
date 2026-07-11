import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../features/streaming/data/models/replay_marker_model.dart';
import '../../features/streaming/domain/streaming_enums.dart';

/// Commentary-style labels for stream replay markers.
class ReplayMarkerCommentary {
  ReplayMarkerCommentary._();

  static String format(
    ReplayMarkerModel marker, {
    BallEventModel? ball,
  }) {
    return switch (marker.kind) {
      ReplayMarkerKind.wicket => _wicket(marker, ball),
      ReplayMarkerKind.six => _boundary('6', marker, ball),
      ReplayMarkerKind.four => _boundary('4', marker, ball),
      ReplayMarkerKind.century => _century(marker),
      ReplayMarkerKind.milestone => _fifty(marker),
      ReplayMarkerKind.custom => _custom(marker),
    };
  }

  static String _wicket(ReplayMarkerModel marker, BallEventModel? ball) {
    final batter = _batsmanName(ball, wicket: true);
    final bowler = _bowlerName(ball);
    final howOut = _howOut(ball);
  if (ball != null) {
      return 'out $howOut, $bowler to $batter';
    }
    final fallback = marker.label.trim();
    if (fallback.isNotEmpty) {
      return 'out $howOut, $bowler to $fallback';
    }
    return 'out $howOut, $bowler to $batter';
  }

  static String _boundary(
    String runs,
    ReplayMarkerModel marker,
    BallEventModel? ball,
  ) {
    final bowler = _bowlerName(ball);
    final batter = _batsmanName(ball);
    if (ball != null) {
      return '$runs, $bowler to $batter';
    }
    final fallback = marker.label.trim();
    if (fallback.isNotEmpty && !_isGenericRunsLabel(fallback)) {
      return '$runs, $fallback';
    }
    return '$runs, $bowler to $batter';
  }

  static String _century(ReplayMarkerModel marker) {
    final name = marker.label.trim();
    if (name.isEmpty) return 'Century';
    return '$name reaches a century';
  }

  static String _fifty(ReplayMarkerModel marker) {
    final name = marker.label.trim();
    if (name.isEmpty) return 'Fifty';
    return '$name reaches fifty';
  }

  static String _custom(ReplayMarkerModel marker) {
    final label = marker.label.trim();
    return label.isNotEmpty ? label : 'Special moment';
  }

  static String _bowlerName(BallEventModel? ball) {
    final name = ball?.bowlerName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Bowler';
  }

  static String _batsmanName(BallEventModel? ball, {bool wicket = false}) {
    if (ball == null) return 'Batter';
    if (wicket) {
      final dismissed = ball.dismissedPlayerName?.trim();
      if (dismissed != null && dismissed.isNotEmpty) return dismissed;
    }
    final striker = ball.lineupStrikerName?.trim();
    if (striker != null && striker.isNotEmpty) return striker;
    return 'Batter';
  }

  static String _howOut(BallEventModel? ball) {
    if (ball == null) return 'out';
    final type = ball.wicketType;
    if (type != null) return _wicketTypeLabel(type);
    final text = ball.dismissalText?.trim();
    if (text != null && text.isNotEmpty) {
      return _normalizeHowOut(text);
    }
    return 'out';
  }

  static String _wicketTypeLabel(WicketType type) => switch (type) {
        WicketType.caught => 'caught',
        WicketType.caughtBehind => 'caught behind',
        WicketType.caughtAndBowled => 'caught & bowled',
        WicketType.bowled => 'bowled',
        WicketType.lbw => 'lbw',
        WicketType.runOut => 'run out',
        WicketType.mankad => 'mankad',
        WicketType.stumped => 'stumped',
        WicketType.hitWicket => 'hit wicket',
        WicketType.handledBall => 'handled the ball',
        WicketType.obstructingField => 'obstructing the field',
        WicketType.timedOut => 'timed out',
        WicketType.retiredOut => 'retired out',
        WicketType.retiredHurt => 'retired hurt',
        WicketType.hitBallTwice => 'hit the ball twice',
        WicketType.other => 'out',
      };

  static String _normalizeHowOut(String text) {
    final lower = text.toLowerCase();
    if (lower.startsWith('out ')) return text.substring(4).trim();
    return text;
  }

  static bool _isGenericRunsLabel(String label) {
    final lower = label.toLowerCase();
    return lower == '6 runs' ||
        lower == '4 runs' ||
        lower == 'manual marker' ||
        lower == 'replay';
  }
}
