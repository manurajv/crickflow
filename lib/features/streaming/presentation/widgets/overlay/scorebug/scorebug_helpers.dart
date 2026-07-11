import '../../../../../../core/utils/cricket_math.dart';
import '../../../../../../data/models/overlay_state_model.dart';
import '../../../../data/models/stream_overlay_theme.dart';

/// Shared formatting helpers for portrait and landscape scorebugs.
class ScorebugHelpers {
  ScorebugHelpers._();

  /// Uppercase batter name — layout ellipsis trims when space runs out.
  static String batterName(String name) => name.trim().toUpperCase();

  static String teamAbbrev(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '—';
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return words
          .take(2)
          .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
          .join();
    }
    return trimmed.length <= 3
        ? trimmed.toUpperCase()
        : trimmed.substring(0, 3).toUpperCase();
  }

  static String shortName(String name, {int max = 14}) {
    final upper = name.trim().toUpperCase();
    if (upper.length <= max) return upper;
    return upper.substring(0, max);
  }

  static String bowlerLine(OverlayStateModel overlay) {
    return '${bowlerName(overlay)} ${bowlerFigures(overlay)}';
  }

  static String bowlerName(OverlayStateModel overlay, {int max = 14}) =>
      shortName(overlay.bowlerName, max: max);

  static String bowlerFigures(OverlayStateModel overlay) {
    final overs =
        CricketMath.formatOvers(overlay.bowlerBalls, overlay.ballsPerOver);
    return '${overlay.bowlerWickets}-${overlay.bowlerRuns} $overs';
  }

  static String? chaseLine(OverlayStateModel overlay) {
    if (overlay.target != null && overlay.requiredRunRate != null) {
      return 'TARGET ${overlay.target} • RRR ${overlay.requiredRunRate!.toStringAsFixed(2)}';
    }
    if (overlay.target != null) {
      return 'TARGET ${overlay.target}';
    }
    if (overlay.requiredRunRate != null) {
      return 'RRR ${overlay.requiredRunRate!.toStringAsFixed(2)}';
    }
    return null;
  }

  static String runRateLine(OverlayStateModel overlay) {
    return 'CRR ${overlay.runRate.toStringAsFixed(2)}';
  }

  /// Projected final score from current runs at different run rates.
  static List<({double rr, int score, bool isCurrent})> projectedScores({
    required int totalRuns,
    required int legalBalls,
    required int totalOvers,
    required int ballsPerOver,
    required double currentRunRate,
  }) {
    final totalBalls = totalOvers * ballsPerOver;
    final remainingBalls = (totalBalls - legalBalls).clamp(0, totalBalls);
    int project(double rr) =>
        totalRuns + ((rr * remainingBalls) / ballsPerOver).round();

    return [
      (rr: currentRunRate, score: project(currentRunRate), isCurrent: true),
      (rr: 6, score: project(6), isCurrent: false),
      (rr: 8, score: project(8), isCurrent: false),
      (rr: 10, score: project(10), isCurrent: false),
    ];
  }

  static String bowlingTeamName({
    required String teamAName,
    required String teamBName,
    required String battingTeamName,
  }) {
    if (battingTeamName == teamAName) return teamBName;
    if (battingTeamName == teamBName) return teamAName;
    return teamBName;
  }

  /// Center scorebug events (FOUR/SIX/WICKET) — not side-panel intros.
  static bool isCenterScorebugEvent(StreamEventOverlay? event) {
    if (event == null) return false;
    return !event.isSidePanelEvent;
  }

  static StreamEventOverlay? centerScorebugEvent(StreamEventOverlay? event) {
    if (!isCenterScorebugEvent(event)) return null;
    return event;
  }
}

/// One batter in a fixed scorebug slot (left or right).
class ScorebugBatterSlot {
  const ScorebugBatterSlot({
    required this.name,
    required this.runs,
    required this.balls,
    required this.onStrike,
  });

  final String name;
  final int runs;
  final int balls;
  final bool onStrike;
}

/// Keeps each batter in a fixed scorebug column; only on-strike styling moves.
class ScorebugBatterSlotTracker {
  String? _leftName;
  String? _rightName;

  void reset() {
    _leftName = null;
    _rightName = null;
  }

  List<ScorebugBatterSlot> resolve(OverlayStateModel overlay) {
    final striker = overlay.strikerName.trim();
    final nonStriker = overlay.nonStrikerName.trim();
    final atCrease = <String>{
      if (striker.isNotEmpty) striker,
      if (nonStriker.isNotEmpty) nonStriker,
    };

    if (atCrease.isEmpty) {
      _leftName = null;
      _rightName = null;
      return const [];
    }

    if (_leftName != null &&
        _rightName != null &&
        !atCrease.contains(_leftName!) &&
        !atCrease.contains(_rightName!)) {
      _leftName = null;
      _rightName = null;
    }

    if (_leftName == null && _rightName == null) {
      _leftName = striker.isNotEmpty ? striker : nonStriker;
      _rightName = nonStriker.isNotEmpty && nonStriker != _leftName
          ? nonStriker
          : (striker.isNotEmpty && striker != _leftName ? striker : null);
    } else {
      _refreshSlotNames(striker, nonStriker, atCrease);
    }

    final slots = <ScorebugBatterSlot>[];
    if (_leftName != null && _leftName!.isNotEmpty) {
      slots.add(_slotFor(_leftName!, overlay));
    }
    if (_rightName != null &&
        _rightName!.isNotEmpty &&
        _rightName != _leftName) {
      slots.add(_slotFor(_rightName!, overlay));
    }
    return slots;
  }

  void _refreshSlotNames(
    String striker,
    String nonStriker,
    Set<String> atCrease,
  ) {
    if (_leftName != null && !atCrease.contains(_leftName!)) {
      _leftName = _replacementName(atCrease, exclude: _rightName) ??
          (striker.isNotEmpty ? striker : nonStriker);
    }
    if (_rightName != null && !atCrease.contains(_rightName!)) {
      _rightName = _replacementName(atCrease, exclude: _leftName) ??
          (nonStriker.isNotEmpty ? nonStriker : striker);
    }

    for (final name in atCrease) {
      if (name == _leftName || name == _rightName) continue;
      if (_leftName == null || !atCrease.contains(_leftName!)) {
        _leftName = name;
      } else if (_rightName == null || !atCrease.contains(_rightName!)) {
        _rightName = name;
      } else {
        _rightName = name;
      }
    }

    if (_leftName == null || _leftName!.isEmpty) {
      _leftName = striker.isNotEmpty ? striker : nonStriker;
    }
    if ((_rightName == null || _rightName!.isEmpty) &&
        nonStriker.isNotEmpty &&
        nonStriker != _leftName) {
      _rightName = nonStriker;
    } else if ((_rightName == null || _rightName!.isEmpty) &&
        striker.isNotEmpty &&
        striker != _leftName) {
      _rightName = striker;
    }
  }

  String? _replacementName(Set<String> atCrease, {String? exclude}) {
    for (final name in atCrease) {
      if (name != exclude) return name;
    }
    return null;
  }

  ScorebugBatterSlot _slotFor(String name, OverlayStateModel overlay) {
    if (overlay.strikerName.trim() == name) {
      return ScorebugBatterSlot(
        name: name,
        runs: overlay.strikerRuns,
        balls: overlay.strikerBalls,
        onStrike: true,
      );
    }
    if (overlay.nonStrikerName.trim() == name) {
      return ScorebugBatterSlot(
        name: name,
        runs: overlay.nonStrikerRuns,
        balls: overlay.nonStrikerBalls,
        onStrike: false,
      );
    }
    return ScorebugBatterSlot(name: name, runs: 0, balls: 0, onStrike: false);
  }
}
