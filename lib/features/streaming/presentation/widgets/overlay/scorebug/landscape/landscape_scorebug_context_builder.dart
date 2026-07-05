import '../../../../../../../core/constants/app_constants.dart';
import '../../../../../../../data/models/ball_event_model.dart';
import '../../../../../../../data/models/match_model.dart';
import '../../../../../../../data/models/overlay_state_model.dart';
import '../../../../../../../features/scoring/presentation/utils/scoring_display_utils.dart';
import 'landscape_scorebug_context.dart';

/// Builds [LandscapeScorebugContext] from live match data for the scorebug UI.
class LandscapeScorebugContextBuilder {
  LandscapeScorebugContextBuilder._();

  static const crickflowLogoUrl = AppConstants.crickflowLogoUrl;

  static LandscapeScorebugContext build({
    required OverlayStateModel overlay,
    MatchModel? match,
    String? tournamentTitle,
    String? battingTeamLogoUrl,
    String? bowlingTeamLogoUrl,
    List<BallEventModel> events = const [],
  }) {
    final matchTitle = _matchTitle(overlay, match);
    final tournament = tournamentTitle?.trim() ?? '';

    if (match == null) {
      return LandscapeScorebugContext(
        matchTitle: matchTitle,
        tournamentTitle: tournament,
        battingTeamLogoUrl: battingTeamLogoUrl,
        bowlingTeamLogoUrl: bowlingTeamLogoUrl,
        beforeFirstBall: overlay.legalBalls == 0 &&
            overlay.strikerName.isEmpty &&
            overlay.nonStrikerName.isEmpty,
        legalBalls: overlay.legalBalls,
        ballsPerOver: overlay.ballsPerOver,
        currentOverNumber: _overNumberFromLegalBalls(
          overlay.legalBalls,
          overlay.ballsPerOver,
        ),
        ballsInCurrentOver: _ballsInOverFromLegalBalls(
          overlay.legalBalls,
          overlay.ballsPerOver,
        ),
      );
    }

    final innings = match.currentInnings;
    if (innings == null) {
      return LandscapeScorebugContext(
        matchTitle: matchTitle,
        tournamentTitle: tournament,
        battingTeamLogoUrl: battingTeamLogoUrl,
        bowlingTeamLogoUrl: bowlingTeamLogoUrl,
        legalBalls: overlay.legalBalls,
        ballsPerOver: overlay.ballsPerOver,
        isChase: overlay.target != null,
        currentOverNumber: _overNumberFromLegalBalls(
          overlay.legalBalls,
          overlay.ballsPerOver,
        ),
        ballsInCurrentOver: _ballsInOverFromLegalBalls(
          overlay.legalBalls,
          overlay.ballsPerOver,
        ),
      );
    }

    final rules = match.rules;
    final chase = ScoringDisplayUtils.chaseDisplay(match, innings, rules);
    final overEvents = ScoringDisplayUtils.currentOverEvents(
      events: events,
      inn: innings,
      ballsPerOver: rules.ballsPerOver,
    );
    final thisOverLabels = overEvents
        .map(ScoringDisplayUtils.ballBubbleLabel)
        .where((label) => label.isNotEmpty)
        .toList();

    return LandscapeScorebugContext(
      matchTitle: matchTitle,
      tournamentTitle: tournament,
      battingTeamLogoUrl: battingTeamLogoUrl,
      bowlingTeamLogoUrl: bowlingTeamLogoUrl,
      powerplayBadge: ScoringDisplayUtils.activePowerplayLabel(match, innings),
      thisOverLabels: thisOverLabels,
      partnershipRuns: innings.partnershipRuns,
      partnershipBalls: innings.partnershipBalls,
      runsNeeded: chase?.runsNeeded,
      ballsRemaining: chase?.ballsRemaining,
      totalOvers: rules.totalOvers,
      inningsNumber: innings.inningsNumber,
      isChase: chase != null && chase.isChasing,
      beforeFirstBall: overlay.legalBalls == 0 &&
          overlay.strikerName.isEmpty &&
          overlay.nonStrikerName.isEmpty,
      currentOverNumber: ScoringDisplayUtils.currentOverNumber(
        innings,
        rules.ballsPerOver,
      ),
      ballsInCurrentOver: ScoringDisplayUtils.ballsInCurrentOver(innings),
      legalBalls: overlay.legalBalls,
      ballsPerOver: overlay.ballsPerOver,
    );
  }

  static String _matchTitle(OverlayStateModel overlay, MatchModel? match) {
    if (match != null && match.title.trim().isNotEmpty) {
      return match.title.trim();
    }
    final a = overlay.teamAName.trim();
    final b = overlay.teamBName.trim();
    if (a.isNotEmpty && b.isNotEmpty) return '$a vs $b';
    if (overlay.battingTeamName.isNotEmpty) return overlay.battingTeamName;
    return 'Match';
  }

  static int _overNumberFromLegalBalls(int legalBalls, int ballsPerOver) {
    if (legalBalls <= 0 || ballsPerOver <= 0) return 1;
    if (legalBalls % ballsPerOver == 0) {
      return (legalBalls ~/ ballsPerOver) + 1;
    }
    return ((legalBalls - 1) ~/ ballsPerOver) + 1;
  }

  static int _ballsInOverFromLegalBalls(int legalBalls, int ballsPerOver) {
    if (legalBalls <= 0 || ballsPerOver <= 0) return 0;
    return legalBalls % ballsPerOver;
  }
}
