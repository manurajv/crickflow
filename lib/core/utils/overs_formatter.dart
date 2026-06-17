import '../constants/app_constants.dart';

/// Single source of truth for cricket overs display and rate calculations.
///
/// Stores only legal ball counts in Firestore; all overs text and rates derive
/// from [ballsPerOver] on the match rules.
class OversFormatter {
  OversFormatter._();

  static int normalizeBallsPerOver(int ballsPerOver) {
    if (ballsPerOver <= 0) return AppConstants.defaultBallsPerOver;
    return ballsPerOver;
  }

  static int oversCompleted(int legalBalls, int ballsPerOver) {
    final bpo = normalizeBallsPerOver(ballsPerOver);
    return legalBalls ~/ bpo;
  }

  static int remainingBalls(int legalBalls, int ballsPerOver) {
    final bpo = normalizeBallsPerOver(ballsPerOver);
    return legalBalls % bpo;
  }

  /// Decimal overs bowled/faced (e.g. 7 legal balls @ 4 bpo → 1.75).
  static double calculateOvers(int legalBalls, int ballsPerOver) {
    final bpo = normalizeBallsPerOver(ballsPerOver);
    if (legalBalls <= 0) return 0;
    return legalBalls / bpo;
  }

  /// Cricket notation: completedOvers.remainingBalls (e.g. 7 @ 4 bpo → `1.3`).
  static String formatOvers(int legalBalls, int ballsPerOver) {
    final bpo = normalizeBallsPerOver(ballsPerOver);
    if (legalBalls <= 0) return '0.0';
    return '${oversCompleted(legalBalls, bpo)}.${remainingBalls(legalBalls, bpo)}';
  }

  static double calculateEconomy(int runs, int legalBalls, int ballsPerOver) {
    final overs = calculateOvers(legalBalls, ballsPerOver);
    if (overs == 0) return 0;
    return runs / overs;
  }

  static double calculateRunRate(int runs, int legalBalls, int ballsPerOver) {
    return calculateEconomy(runs, legalBalls, ballsPerOver);
  }

  static double calculateRequiredRunRate({
    required int runsNeeded,
    required int ballsRemaining,
    required int ballsPerOver,
  }) {
    if (runsNeeded <= 0) return 0;
    final oversRemaining = calculateOvers(ballsRemaining, ballsPerOver);
    if (oversRemaining == 0) return 0;
    return runsNeeded / oversRemaining;
  }

  /// Economy when aggregate overs are already summed in decimal form.
  static double economyFromDecimalOvers(int runs, double oversBowled) {
    if (oversBowled <= 0) return 0;
    return runs / oversBowled;
  }
}
