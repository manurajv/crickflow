/// Extended match context for the landscape broadcast scorebug.
class LandscapeScorebugContext {
  const LandscapeScorebugContext({
    this.matchTitle = '',
    this.tournamentTitle = '',
    this.battingTeamLogoUrl,
    this.bowlingTeamLogoUrl,
    this.powerplayBadge,
    this.thisOverLabels = const [],
    this.partnershipRuns = 0,
    this.partnershipBalls = 0,
    this.runsNeeded,
    this.ballsRemaining,
    this.totalOvers = 20,
    this.inningsNumber = 1,
    this.isChase = false,
    this.beforeFirstBall = false,
    this.currentOverNumber = 1,
    this.ballsInCurrentOver = 0,
    this.legalBalls = 0,
    this.ballsPerOver = 6,
  });

  final String matchTitle;
  final String tournamentTitle;
  final String? battingTeamLogoUrl;
  final String? bowlingTeamLogoUrl;
  final String? powerplayBadge;
  final List<String> thisOverLabels;
  final int partnershipRuns;
  final int partnershipBalls;
  final int? runsNeeded;
  final int? ballsRemaining;
  final int totalOvers;
  final int inningsNumber;
  final bool isChase;
  final bool beforeFirstBall;
  final int currentOverNumber;
  final int ballsInCurrentOver;
  final int legalBalls;
  final int ballsPerOver;

  bool get isFirstInnings => inningsNumber <= 1;

  String get preBallCenterTitle {
    if (tournamentTitle.isNotEmpty) return tournamentTitle;
    if (matchTitle.isNotEmpty) return matchTitle;
    return '';
  }

  bool get inPowerplay => powerplayBadge != null && powerplayBadge!.isNotEmpty;

  /// When projected-score banners may appear in the 1st innings.
  /// Up to 20 overs: last 50%; 21+ overs: last 20%.
  double get projectionPhaseStartProgress =>
      totalOvers > 20 ? 0.8 : 0.5;

  bool get showProjectionPhase {
    if (!isFirstInnings || totalOvers <= 0) return false;
    return legalProgress >= projectionPhaseStartProgress;
  }

  double get legalProgress {
    final totalBalls = totalOvers * ballsPerOver;
    if (totalBalls <= 0) return 0;
    return (legalBalls / totalBalls).clamp(0.0, 1.0);
  }

  LandscapeScorebugContext copyWith({
    String? matchTitle,
    String? tournamentTitle,
    String? battingTeamLogoUrl,
    String? bowlingTeamLogoUrl,
    String? powerplayBadge,
    List<String>? thisOverLabels,
    int? partnershipRuns,
    int? partnershipBalls,
    int? runsNeeded,
    int? ballsRemaining,
    int? totalOvers,
    int? inningsNumber,
    bool? isChase,
    bool? beforeFirstBall,
    int? currentOverNumber,
    int? ballsInCurrentOver,
    int? legalBalls,
    int? ballsPerOver,
  }) {
    return LandscapeScorebugContext(
      matchTitle: matchTitle ?? this.matchTitle,
      tournamentTitle: tournamentTitle ?? this.tournamentTitle,
      battingTeamLogoUrl: battingTeamLogoUrl ?? this.battingTeamLogoUrl,
      bowlingTeamLogoUrl: bowlingTeamLogoUrl ?? this.bowlingTeamLogoUrl,
      powerplayBadge: powerplayBadge ?? this.powerplayBadge,
      thisOverLabels: thisOverLabels ?? this.thisOverLabels,
      partnershipRuns: partnershipRuns ?? this.partnershipRuns,
      partnershipBalls: partnershipBalls ?? this.partnershipBalls,
      runsNeeded: runsNeeded ?? this.runsNeeded,
      ballsRemaining: ballsRemaining ?? this.ballsRemaining,
      totalOvers: totalOvers ?? this.totalOvers,
      inningsNumber: inningsNumber ?? this.inningsNumber,
      isChase: isChase ?? this.isChase,
      beforeFirstBall: beforeFirstBall ?? this.beforeFirstBall,
      currentOverNumber: currentOverNumber ?? this.currentOverNumber,
      ballsInCurrentOver: ballsInCurrentOver ?? this.ballsInCurrentOver,
      legalBalls: legalBalls ?? this.legalBalls,
      ballsPerOver: ballsPerOver ?? this.ballsPerOver,
    );
  }
}
