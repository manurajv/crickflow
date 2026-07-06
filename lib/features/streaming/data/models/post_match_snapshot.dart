import 'package:equatable/equatable.dart';

class PostMatchBatterLine extends Equatable {
  const PostMatchBatterLine({
    required this.name,
    required this.runs,
    required this.balls,
    this.isNotOut = false,
  });

  final String name;
  final int runs;
  final int balls;
  final bool isNotOut;

  @override
  List<Object?> get props => [name, runs, balls, isNotOut];
}

class PostMatchBowlerLine extends Equatable {
  const PostMatchBowlerLine({
    required this.name,
    required this.wickets,
    required this.runs,
    required this.overs,
  });

  final String name;
  final int wickets;
  final int runs;
  final String overs;

  @override
  List<Object?> get props => [name, wickets, runs, overs];
}

class PostMatchTeamSummary extends Equatable {
  const PostMatchTeamSummary({
    required this.teamName,
    this.logoUrl,
    required this.oversLabel,
    required this.score,
    this.wonToss = false,
    this.topBatters = const [],
    this.topBowlers = const [],
  });

  final String teamName;
  final String? logoUrl;
  final String oversLabel;
  final String score;
  final bool wonToss;
  final List<PostMatchBatterLine> topBatters;
  final List<PostMatchBowlerLine> topBowlers;

  @override
  List<Object?> get props =>
      [teamName, logoUrl, oversLabel, score, wonToss, topBatters, topBowlers];
}

/// Read-only data for the post-match summary + thank-you presentation.
class PostMatchSnapshot extends Equatable {
  const PostMatchSnapshot({
    required this.matchTitle,
    required this.matchTypeSubtitle,
    this.tournamentLogoUrl,
    this.tournamentName = '',
    required this.venue,
    required this.crickflowLogoUrl,
    this.sponsorLogoUrls = const [],
    required this.teams,
    required this.resultText,
  });

  static const empty = PostMatchSnapshot(
    matchTitle: '',
    matchTypeSubtitle: '',
    venue: '',
    crickflowLogoUrl: '',
    teams: [],
    resultText: '',
  );

  final String matchTitle;
  final String matchTypeSubtitle;
  final String? tournamentLogoUrl;
  final String tournamentName;
  final String venue;
  final String crickflowLogoUrl;
  final List<String> sponsorLogoUrls;
  final List<PostMatchTeamSummary> teams;
  final String resultText;

  bool get isValid =>
      matchTitle.isNotEmpty && teams.isNotEmpty && resultText.isNotEmpty;

  @override
  List<Object?> get props => [
        matchTitle,
        matchTypeSubtitle,
        tournamentLogoUrl,
        tournamentName,
        venue,
        crickflowLogoUrl,
        sponsorLogoUrls,
        teams,
        resultText,
      ];
}
