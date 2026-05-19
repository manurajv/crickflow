/// Cricket statistics and rate calculations.
class CricketMath {
  CricketMath._();

  static double strikeRate(int runs, int balls) {
    if (balls == 0) return 0;
    return (runs / balls) * 100;
  }

  static double economyRate(int runs, int balls, int ballsPerOver) {
    if (balls == 0 || ballsPerOver == 0) return 0;
    final overs = balls / ballsPerOver;
    if (overs == 0) return 0;
    return runs / overs;
  }

  static double runRate(int runs, int balls, int ballsPerOver) {
    return economyRate(runs, balls, ballsPerOver);
  }

  static double requiredRunRate({
    required int runsNeeded,
    required int ballsRemaining,
    required int ballsPerOver,
  }) {
    if (ballsRemaining <= 0 || ballsPerOver == 0) return 0;
    final oversRemaining = ballsRemaining / ballsPerOver;
    if (oversRemaining == 0) return 0;
    return runsNeeded / oversRemaining;
  }

  static double battingAverage(int runs, int dismissals) {
    if (dismissals == 0) return runs.toDouble();
    return runs / dismissals;
  }

  static double bowlingAverage(int runs, int wickets) {
    if (wickets == 0) return 0;
    return runs / wickets;
  }

  static String formatOvers(int legalBalls, int ballsPerOver) {
    if (ballsPerOver <= 0) return '0.0';
    final completed = legalBalls ~/ ballsPerOver;
    final remainder = legalBalls % ballsPerOver;
    return '$completed.$remainder';
  }

  static int ballsFromOvers(double totalOvers, int ballsPerOver) {
    final whole = totalOvers.floor();
    final fraction = ((totalOvers - whole) * 10).round();
    return whole * ballsPerOver + fraction;
  }
}
