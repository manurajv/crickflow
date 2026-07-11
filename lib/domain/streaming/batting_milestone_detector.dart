/// Batter-only scoring milestones (not bowler figures or partnerships).
abstract final class BattingMilestoneDetector {
  static const cricketBattingMilestones = [50, 100, 150, 200];

  /// Highest batting milestone crossed on this ball, if any.
  static int? crossedMilestone(int previousRuns, int currentRuns) {
    if (currentRuns <= previousRuns) return null;
    for (var i = cricketBattingMilestones.length - 1; i >= 0; i--) {
      final milestone = cricketBattingMilestones[i];
      if (previousRuns < milestone && currentRuns >= milestone) {
        return milestone;
      }
    }
    return null;
  }

  static bool isCricketBattingMilestone(int runs) =>
      cricketBattingMilestones.contains(runs);
}
