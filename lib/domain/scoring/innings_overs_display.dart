import '../../core/utils/overs_formatter.dart';
import '../../data/models/innings_model.dart';

/// Innings-level overs / run-rate display from legal balls and balls-per-over.
class InningsOversDisplay {
  InningsOversDisplay._();

  static String format(InningsModel inn, int ballsPerOver) {
    return OversFormatter.formatOvers(inn.legalBalls, ballsPerOver);
  }

  static double decimal(InningsModel inn, int ballsPerOver) {
    return OversFormatter.calculateOvers(inn.legalBalls, ballsPerOver);
  }

  static double runRate(InningsModel inn, int ballsPerOver) {
    return OversFormatter.calculateRunRate(
      inn.totalRuns,
      inn.legalBalls,
      ballsPerOver,
    );
  }
}
