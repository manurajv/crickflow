import 'overs_formatter.dart';
/// Cricket statistics and rate calculations.
class CricketMath {
  CricketMath._();

  static double strikeRate(int runs, int balls) {
    if (balls == 0) return 0;
    return (runs / balls) * 100;
  }

  static double economyRate(int runs, int balls, int ballsPerOver) =>
      OversFormatter.calculateEconomy(runs, balls, ballsPerOver);

  static double runRate(int runs, int balls, int ballsPerOver) =>
      OversFormatter.calculateRunRate(runs, balls, ballsPerOver);

  static double requiredRunRate({
    required int runsNeeded,
    required int ballsRemaining,
    required int ballsPerOver,
  }) =>
      OversFormatter.calculateRequiredRunRate(
        runsNeeded: runsNeeded,
        ballsRemaining: ballsRemaining,
        ballsPerOver: ballsPerOver,
      );

  static double battingAverage(int runs, int dismissals) {
    if (dismissals == 0) return runs.toDouble();
    return runs / dismissals;
  }

  static double bowlingAverage(int runs, int wickets) {
    if (wickets == 0) return 0;
    return runs / wickets;
  }

  static String formatOvers(int legalBalls, int ballsPerOver) =>
      OversFormatter.formatOvers(legalBalls, ballsPerOver);

  static int ballsFromOvers(double totalOvers, int ballsPerOver) {
    final bpo = OversFormatter.normalizeBallsPerOver(ballsPerOver);
    final whole = totalOvers.floor();
    final fraction = ((totalOvers - whole) * 10).round();
    return whole * bpo + fraction;
  }
}
