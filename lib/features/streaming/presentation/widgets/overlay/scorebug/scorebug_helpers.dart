import '../../../../../../core/utils/cricket_math.dart';
import '../../../../../../data/models/overlay_state_model.dart';

/// Shared formatting helpers for portrait and landscape scorebugs.
class ScorebugHelpers {
  ScorebugHelpers._();

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
    final overs =
        CricketMath.formatOvers(overlay.bowlerBalls, overlay.ballsPerOver);
    return '${shortName(overlay.bowlerName, max: 12)} '
        '${overlay.bowlerWickets}-${overlay.bowlerRuns} $overs';
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
}
