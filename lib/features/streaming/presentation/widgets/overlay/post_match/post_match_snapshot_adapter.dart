import '../../../../data/models/innings_break_snapshot.dart';
import '../../../../data/models/post_match_snapshot.dart';

/// Maps [PostMatchSnapshot] into [InningsBreakShell] / thank-you card fields.
class PostMatchSnapshotAdapter {
  PostMatchSnapshotAdapter._();

  static InningsBreakSnapshot shellSnapshot(PostMatchSnapshot post) {
    return InningsBreakSnapshot(
      matchTitle: post.matchTitle,
      inningsTitle: 'Match Summary',
      battingTeamName: post.matchTitle,
      bowlingTeamName: '',
      battingTeamLogoUrl: post.tournamentLogoUrl,
      bowlingTeamLogoUrl: null,
      tournamentLogoUrl: post.tournamentLogoUrl,
      tournamentName: post.tournamentName,
      venue: post.venue,
      crickflowLogoUrl: post.crickflowLogoUrl,
      sponsorLogoUrls: post.sponsorLogoUrls,
      batters: const [],
      bowlers: const [],
      extras: 0,
      extrasDetail: '',
      totalRuns: 0,
      totalWickets: 0,
      overs: '',
      runRate: 0,
      fours: 0,
      sixes: 0,
      dotBalls: 0,
      boundaries: 0,
      partnershipTotal: 0,
      battingHighlights: const [],
      bowlingHighlights: const [],
      partnerships: const [],
      fallOfWickets: const [],
      target: 0,
      runsRequired: 0,
      oversRemaining: 0,
      requiredRunRate: 0,
      chaseOvers: 0,
      ballsPerOver: 6,
      wagonWheelShots: const [],
      wagonWheelInsights: null,
      hasAnalytics: false,
      screens: const [],
    );
  }
}
