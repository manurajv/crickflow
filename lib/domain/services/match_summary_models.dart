import 'package:equatable/equatable.dart';

enum SummaryHeroKind {
  playerOfMatch,
  fighterOfMatch,
  bestBatter,
  bestBowler,
  bestFielder,
}

class MatchSummarySnapshot extends Equatable {
  const MatchSummarySnapshot({
    this.hasData = false,
    this.isLive = false,
    this.isCompleted = false,
    this.result,
    this.insight,
    this.heroes = const [],
    this.starBatters = const [],
    this.starBowlers = const [],
    this.starFielders = const [],
    this.starAllRounders = const [],
    this.bestPartnership,
    this.teamComparison,
    this.timeline = const [],
    this.awards = const [],
  });

  final bool hasData;
  final bool isLive;
  final bool isCompleted;
  final MatchResultSummary? result;
  final MatchInsightSummary? insight;
  final List<SummaryHeroCard> heroes;
  final List<SummaryPerformerCard> starBatters;
  final List<SummaryPerformerCard> starBowlers;
  final List<SummaryPerformerCard> starFielders;
  final List<SummaryPerformerCard> starAllRounders;
  final SummaryPartnershipCard? bestPartnership;
  final TeamComparisonSummary? teamComparison;
  final List<MatchTimelineEvent> timeline;
  final List<MatchSummaryAward> awards;

  @override
  List<Object?> get props => [hasData, isLive, result?.resultLine];
}

class MatchResultSummary extends Equatable {
  const MatchResultSummary({
    required this.teamAName,
    required this.teamBName,
    this.teamAScore,
    this.teamBScore,
    this.resultLine,
    this.formatLabel = '',
    this.venue = '',
    this.dateLabel = '',
    this.durationLabel = '',
    this.tossLabel = '',
    this.playerOfMatchName = '',
    this.statusLabel = '',
  });

  final String teamAName;
  final String teamBName;
  final String? teamAScore;
  final String? teamBScore;
  final String? resultLine;
  final String formatLabel;
  final String venue;
  final String dateLabel;
  final String durationLabel;
  final String tossLabel;
  final String playerOfMatchName;
  final String statusLabel;

  @override
  List<Object?> get props => [teamAName, teamBName, resultLine];
}

class MatchInsightSummary extends Equatable {
  const MatchInsightSummary({
    required this.headline,
    required this.playerName,
    this.photoUrl,
    required this.contributionPercent,
    required this.prefix,
    required this.middle,
    required this.suffix,
    this.isPersonalized = false,
  });

  final String headline;
  final String playerName;
  final String? photoUrl;
  final double contributionPercent;
  /// Text before the player name (e.g. "Tough match, ").
  final String prefix;
  /// Text after the name and before the percentage.
  final String middle;
  /// Text after the percentage.
  final String suffix;
  final bool isPersonalized;

  String get plainText =>
      '$prefix$playerName$middle${contributionPercent.toStringAsFixed(2)}%$suffix';

  @override
  List<Object?> get props =>
      [headline, playerName, contributionPercent, prefix, middle, suffix];
}

class SummaryHeroCard extends Equatable {
  const SummaryHeroCard({
    required this.kind,
    required this.title,
    required this.playerName,
    required this.teamName,
    this.photoUrl,
    this.battingLine = '',
    this.bowlingLine = '',
    this.fieldingLine = '',
    this.mvpScore = 0,
  });

  final SummaryHeroKind kind;
  final String title;
  final String playerName;
  final String teamName;
  final String? photoUrl;
  final String battingLine;
  final String bowlingLine;
  final String fieldingLine;
  final double mvpScore;

  String get primaryStatLine {
    if (battingLine.isNotEmpty) return battingLine;
    if (bowlingLine.isNotEmpty) return bowlingLine;
    return fieldingLine;
  }

  String? get secondaryStatLine {
    if (battingLine.isNotEmpty && bowlingLine.isNotEmpty) return bowlingLine;
    if (fieldingLine.isNotEmpty &&
        battingLine.isEmpty &&
        bowlingLine.isEmpty) {
      return null;
    }
    if (fieldingLine.isNotEmpty) return fieldingLine;
    return null;
  }

  @override
  List<Object?> get props => [kind, playerName];
}

class SummaryPerformerCard extends Equatable {
  const SummaryPerformerCard({
    required this.playerId,
    required this.playerName,
    required this.teamName,
    this.photoUrl,
    required this.statLine,
    this.subtitle = '',
  });

  final String playerId;
  final String playerName;
  final String teamName;
  final String? photoUrl;
  final String statLine;
  final String subtitle;

  @override
  List<Object?> get props => [playerId, statLine];
}

class SummaryPartnershipCard extends Equatable {
  const SummaryPartnershipCard({
    required this.runs,
    required this.balls,
    required this.batterAName,
    required this.batterBName,
    required this.batterARuns,
    required this.batterBRuns,
    required this.inningsLabel,
  });

  final int runs;
  final int balls;
  final String batterAName;
  final String batterBName;
  final int batterARuns;
  final int batterBRuns;
  final String inningsLabel;

  double get batterAShare => runs == 0 ? 0.5 : batterARuns / runs;
  double get batterBShare => runs == 0 ? 0.5 : batterBRuns / runs;

  @override
  List<Object?> get props => [runs, batterAName, batterBName];
}

class TeamComparisonMetric extends Equatable {
  const TeamComparisonMetric({
    required this.label,
    required this.teamAValue,
    required this.teamBValue,
    this.teamANumeric,
    this.teamBNumeric,
  });

  final String label;
  final String teamAValue;
  final String teamBValue;
  final double? teamANumeric;
  final double? teamBNumeric;

  @override
  List<Object?> get props => [label, teamAValue, teamBValue];
}

class TeamComparisonSummary extends Equatable {
  const TeamComparisonSummary({
    required this.teamAName,
    required this.teamBName,
    this.metrics = const [],
  });

  final String teamAName;
  final String teamBName;
  final List<TeamComparisonMetric> metrics;

  @override
  List<Object?> get props => [teamAName, teamBName, metrics];
}

class MatchTimelineEvent extends Equatable {
  const MatchTimelineEvent({
    required this.label,
    required this.detail,
    this.inningsLabel = '',
    required this.order,
  });

  final String label;
  final String detail;
  final String inningsLabel;
  final int order;

  @override
  List<Object?> get props => [label, detail, order];
}

class MatchSummaryAward extends Equatable {
  const MatchSummaryAward({
    required this.emoji,
    required this.title,
    required this.playerName,
    this.subtitle = '',
  });

  final String emoji;
  final String title;
  final String playerName;
  final String subtitle;

  @override
  List<Object?> get props => [title, playerName];
}
