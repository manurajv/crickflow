import 'match_info_models.dart';
import 'match_summary_models.dart';

class UpcomingMatchPreview {
  const UpcomingMatchPreview({
    required this.teamAName,
    required this.teamBName,
    this.teamALogoUrl,
    this.teamBLogoUrl,
    this.formatLabel = '',
    this.venueLabel = '',
    this.dateLabel = '',
    this.timeLabel = '',
    this.scheduledAt,
    this.statusBadge = 'Upcoming',
  });

  final String teamAName;
  final String teamBName;
  final String? teamALogoUrl;
  final String? teamBLogoUrl;
  final String formatLabel;
  final String venueLabel;
  final String dateLabel;
  final String timeLabel;
  final DateTime? scheduledAt;
  final String statusBadge;
}

class HeadToHeadRecentMatch {
  const HeadToHeadRecentMatch({
    required this.dateLabel,
    required this.summary,
    required this.winnerName,
  });

  final String dateLabel;
  final String summary;
  final String winnerName;
}

class HeadToHeadSnapshot {
  const HeadToHeadSnapshot({
    this.hasHistory = false,
    this.matchesPlayed = 0,
    this.teamAWins = 0,
    this.teamBWins = 0,
    this.teamAWonBatFirst = 0,
    this.teamBWonBatFirst = 0,
    this.teamAWonBowlFirst = 0,
    this.teamBWonBowlFirst = 0,
    this.teamAAvgScore = 0,
    this.teamBAvgScore = 0,
    this.teamAHighest = 0,
    this.teamBHighest = 0,
    this.teamALowest = 0,
    this.teamBLowest = 0,
    this.teamAWinPct = 0,
    this.teamBWinPct = 0,
    this.recentMatches = const [],
    this.comparison,
  });

  static const empty = HeadToHeadSnapshot();

  final bool hasHistory;
  final int matchesPlayed;
  final int teamAWins;
  final int teamBWins;
  final int teamAWonBatFirst;
  final int teamBWonBatFirst;
  final int teamAWonBowlFirst;
  final int teamBWonBowlFirst;
  final double teamAAvgScore;
  final double teamBAvgScore;
  final int teamAHighest;
  final int teamBHighest;
  final int teamALowest;
  final int teamBLowest;
  final double teamAWinPct;
  final double teamBWinPct;
  final List<HeadToHeadRecentMatch> recentMatches;
  final TeamComparisonSummary? comparison;
}

class UpcomingMilestoneCard {
  const UpcomingMilestoneCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.playerName,
    required this.progressLabel,
    this.progress = 0,
  });

  final String emoji;
  final String title;
  final String description;
  final String playerName;
  final String progressLabel;
  final double progress;
}

class UpcomingMatchBanner {
  const UpcomingMatchBanner({
    required this.title,
    this.imageUrl,
    this.kind = 'vs',
  });

  final String title;
  final String? imageUrl;
  final String kind;
}

class UpcomingMatchSnapshot {
  const UpcomingMatchSnapshot({
    this.preview = const UpcomingMatchPreview(
      teamAName: 'Team A',
      teamBName: 'Team B',
    ),
    this.headToHead = HeadToHeadSnapshot.empty,
    this.infoRows = const [],
    this.officials = const [],
    this.milestones = const [],
    this.banners = const [],
    this.tournamentId,
    this.teamAId,
    this.teamBId,
  });

  static const empty = UpcomingMatchSnapshot();

  final UpcomingMatchPreview preview;
  final HeadToHeadSnapshot headToHead;
  final List<MatchInfoRow> infoRows;
  final List<MatchInfoOfficial> officials;
  final List<UpcomingMilestoneCard> milestones;
  final List<UpcomingMatchBanner> banners;
  final String? tournamentId;
  final String? teamAId;
  final String? teamBId;

  bool get hasOfficials => officials.isNotEmpty;
  bool get hasMilestones => milestones.isNotEmpty;
  bool get hasInfo => infoRows.isNotEmpty;
}
