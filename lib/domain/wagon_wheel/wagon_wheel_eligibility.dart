import '../../core/constants/enums.dart';
import '../../data/models/match_rules_model.dart';
import '../services/scoring_engine.dart';

/// Decides when the wagon wheel capture popup should appear during scoring.
class WagonWheelEligibility {
  WagonWheelEligibility._();

  static bool isTrackingEnabled(MatchRulesModel rules) =>
      rules.wagonWheelEnabled && !rules.isIndoor;

  static bool shouldCapture(BallEventInput input, MatchRulesModel rules) {
    if (!isTrackingEnabled(rules)) return false;

    return switch (input.type) {
      BallEventType.runs => _isScoringRun(input.runs),
      BallEventType.noBall => _noBallFromBat(input),
      _ => false,
    };
  }

  static int batsmanRunsForShot(BallEventInput input) {
    return switch (input.type) {
      BallEventType.runs => input.runs,
      BallEventType.noBall =>
        (input.noBallRunsMode ?? NoBallRunsMode.bat) == NoBallRunsMode.bat
            ? input.runs
            : 0,
      _ => 0,
    };
  }

  static bool _isScoringRun(int runs) => runs >= 1 && runs <= 6;

  static bool _noBallFromBat(BallEventInput input) {
    final mode = input.noBallRunsMode ?? NoBallRunsMode.bat;
    return mode == NoBallRunsMode.bat && input.runs > 0;
  }
}
