import '../../data/models/ball_event_model.dart';
import '../../features/streaming/data/models/replay_marker_model.dart';
import '../../features/streaming/domain/streaming_enums.dart';
import 'batting_milestone_detector.dart';

/// Professional title + optional scoreboard subtitle for replay markers.
class ReplayMarkerPresentation {
  const ReplayMarkerPresentation({
    required this.title,
    this.subtitle,
    this.kindLabel = '',
  });

  final String title;
  final String? subtitle;
  final String kindLabel;
}

/// Broadcast-style labels for stream replay markers.
class ReplayMarkerCommentary {
  ReplayMarkerCommentary._();

  static ReplayMarkerPresentation present(
    ReplayMarkerModel marker, {
    BallEventModel? ball,
  }) {
    final kindLabel = kindLabelFor(marker.kind);
    final title = switch (marker.kind) {
      ReplayMarkerKind.wicket => _wicketTitle(marker, ball),
      ReplayMarkerKind.six => _boundaryTitle('SIX', marker, ball),
      ReplayMarkerKind.four => _boundaryTitle('FOUR', marker, ball),
      ReplayMarkerKind.century =>
        _milestoneTitle('CENTURY', marker, ball, runs: 100),
      ReplayMarkerKind.milestone => _milestoneTitle('FIFTY', marker, ball),
      ReplayMarkerKind.custom => _customTitle(marker),
    };
    return ReplayMarkerPresentation(
      title: title,
      subtitle: _scoreboardSubtitle(ball),
      kindLabel: kindLabel,
    );
  }

  /// Backwards-compatible single-line label (title only).
  static String format(
    ReplayMarkerModel marker, {
    BallEventModel? ball,
  }) =>
      present(marker, ball: ball).title;

  static String kindLabelFor(ReplayMarkerKind kind) => switch (kind) {
        ReplayMarkerKind.wicket => 'Wicket',
        ReplayMarkerKind.six => 'Six',
        ReplayMarkerKind.four => 'Four',
        ReplayMarkerKind.century => 'Century',
        ReplayMarkerKind.milestone => 'Fifty',
        ReplayMarkerKind.custom => 'Custom',
      };

  static String _wicketTitle(ReplayMarkerModel marker, BallEventModel? ball) {
    final batter = _batsmanName(ball, wicket: true);
    if (ball != null) {
      return 'WICKET • $batter dismissed';
    }
    final fallback = marker.label.trim();
    if (fallback.isNotEmpty && !_isNoiseLabel(fallback)) {
      return 'WICKET • $fallback';
    }
    return 'WICKET • $batter dismissed';
  }

  static String _boundaryTitle(
    String kind,
    ReplayMarkerModel marker,
    BallEventModel? ball,
  ) {
    final batter = _batsmanName(ball);
    if (batter != 'Batter') {
      return '$kind • $batter';
    }
    final fallback = marker.label.trim();
    if (fallback.isNotEmpty && !_isGenericRunsLabel(fallback)) {
      return '$kind • $fallback';
    }
    return '$kind • $batter';
  }

  static String _milestoneTitle(
    String defaultKind,
    ReplayMarkerModel marker,
    BallEventModel? ball, {
    int? runs,
  }) {
    final milestoneRuns = runs ??
        _milestoneRunsFromLabel(marker.label) ??
        (marker.kind == ReplayMarkerKind.century ? 100 : 50);
    final kind = switch (milestoneRuns) {
      50 => 'FIFTY',
      100 => 'CENTURY',
      200 => 'DOUBLE CENTURY',
      _ => defaultKind,
    };
    final batter = _batsmanName(ball);
    if (batter != 'Batter') {
      return '$kind • ${_milestonePhrase(batter, milestoneRuns)}';
    }
    final name = _batterNameFromLabel(marker.label);
    if (name != null) {
      return '$kind • ${_milestonePhrase(name, milestoneRuns)}';
    }
    return '$kind • ${_milestonePhrase('Batter', milestoneRuns)}';
  }

  static String _milestonePhrase(String batter, int runs) => switch (runs) {
        50 => '$batter reaches 50',
        100 => '$batter reaches 100',
        150 => '$batter reaches 150',
        200 => '$batter reaches 200',
        _ => '$batter reaches $runs',
      };

  static String _customTitle(ReplayMarkerModel marker) {
    final label = marker.label.trim();
    return label.isNotEmpty ? label : 'Special moment';
  }

  static String? _scoreboardSubtitle(BallEventModel? ball) {
    if (ball == null) return null;
    final over = '${ball.overNumber}.${ball.ballInOver}';
    final score = ball.teamScoreAtWicket;
    if (score != null) {
      return '$over ov • $score';
    }
    return '$over ov';
  }

  static int? _milestoneRunsFromLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (lower.contains('double century') || lower.contains('200')) return 200;
    if (lower.contains('century') || lower.contains('100')) return 100;
    if (lower.contains('150')) return 150;
    if (lower.contains('fifty') || lower.contains('50')) return 50;
    final match = RegExp(r'\b(\d{2,3})\b').firstMatch(trimmed);
    if (match != null) {
      final value = int.tryParse(match.group(1)!);
      if (value != null &&
          BattingMilestoneDetector.isCricketBattingMilestone(value)) {
        return value;
      }
    }
    return null;
  }

  static String? _batterNameFromLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty || _isNoiseLabel(trimmed)) return null;
    final reaches =
        RegExp(r'^(.+?)\s+reaches\b', caseSensitive: false).firstMatch(trimmed);
    if (reaches != null) {
      final name = reaches.group(1)?.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    if (trimmed.length < 40 && !trimmed.contains('partnership')) {
      return trimmed;
    }
    return null;
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

  static bool _isGenericRunsLabel(String label) {
    final lower = label.toLowerCase();
    return lower == '6 runs' ||
        lower == '4 runs' ||
        lower == 'manual marker' ||
        lower == 'replay' ||
        lower == 'new bowler' ||
        lower == 'new batter';
  }

  static bool _isNoiseLabel(String label) {
    final lower = label.toLowerCase();
    return lower.contains('partnership') ||
        lower.contains('bowler') && lower.contains('runs') ||
        _isGenericRunsLabel(label);
  }
}
