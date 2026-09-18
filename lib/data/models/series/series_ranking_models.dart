import 'package:equatable/equatable.dart';

/// Series-scoped club standings (independent of global team stats).
class SeriesClubRankingModel extends Equatable {
  const SeriesClubRankingModel({
    required this.id,
    required this.seriesId,
    required this.clubId,
    this.clubName = '',
    this.played = 0,
    this.won = 0,
    this.lost = 0,
    this.tied = 0,
    this.noResult = 0,
    this.points = 0,
    this.netRunRate = 0,
    this.runDifference = 0,
    this.bonusPoints = 0,
    this.updatedAt,
  });

  final String id;
  final String seriesId;
  final String clubId;
  final String clubName;
  final int played;
  final int won;
  final int lost;
  final int tied;
  final int noResult;
  final int points;
  final double netRunRate;
  final int runDifference;
  final int bonusPoints;
  final DateTime? updatedAt;

  factory SeriesClubRankingModel.fromMap(String id, Map<String, dynamic> map) {
    return SeriesClubRankingModel(
      id: id,
      seriesId: map['seriesId'] as String? ?? '',
      clubId: map['clubId'] as String? ?? '',
      clubName: map['clubName'] as String? ?? '',
      played: (map['played'] as num?)?.toInt() ?? 0,
      won: (map['won'] as num?)?.toInt() ?? 0,
      lost: (map['lost'] as num?)?.toInt() ?? 0,
      tied: (map['tied'] as num?)?.toInt() ?? 0,
      noResult: (map['noResult'] as num?)?.toInt() ?? 0,
      points: (map['points'] as num?)?.toInt() ?? 0,
      netRunRate: (map['netRunRate'] as num?)?.toDouble() ?? 0,
      runDifference: (map['runDifference'] as num?)?.toInt() ?? 0,
      bonusPoints: (map['bonusPoints'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'seriesId': seriesId,
        'clubId': clubId,
        'clubName': clubName,
        'played': played,
        'won': won,
        'lost': lost,
        'tied': tied,
        'noResult': noResult,
        'points': points,
        'netRunRate': netRunRate,
        'runDifference': runDifference,
        'bonusPoints': bonusPoints,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, seriesId, clubId, points, played];
}

/// Series-scoped player batting/bowling stats (independent of global stats).
class SeriesPlayerRankingModel extends Equatable {
  const SeriesPlayerRankingModel({
    required this.id,
    required this.seriesId,
    required this.userId,
    this.playerDocId,
    this.displayName = '',
    this.clubId,
    this.matches = 0,
    this.innings = 0,
    this.runs = 0,
    this.highestScore = 0,
    this.ballsFaced = 0,
    this.fours = 0,
    this.sixes = 0,
    this.thirties = 0,
    this.fifties = 0,
    this.hundreds = 0,
    this.bowlingMatches = 0,
    this.oversBowled = 0,
    this.bowlingRuns = 0,
    this.wickets = 0,
    this.maidens = 0,
    this.bestBowling = '',
    this.updatedAt,
  });

  final String id;
  final String seriesId;
  final String userId;
  final String? playerDocId;
  final String displayName;
  final String? clubId;
  final int matches;
  final int innings;
  final int runs;
  final int highestScore;
  final int ballsFaced;
  final int fours;
  final int sixes;
  final int thirties;
  final int fifties;
  final int hundreds;
  final int bowlingMatches;
  final double oversBowled;
  final int bowlingRuns;
  final int wickets;
  final int maidens;
  final String bestBowling;
  final DateTime? updatedAt;

  double get battingAverage =>
      innings > 0 ? runs / innings : 0;
  double get strikeRate =>
      ballsFaced > 0 ? (runs / ballsFaced) * 100 : 0;
  double get bowlingAverage =>
      wickets > 0 ? bowlingRuns / wickets : 0;
  double get economy =>
      oversBowled > 0 ? bowlingRuns / oversBowled : 0;

  factory SeriesPlayerRankingModel.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return SeriesPlayerRankingModel(
      id: id,
      seriesId: map['seriesId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      playerDocId: map['playerDocId'] as String?,
      displayName: map['displayName'] as String? ?? '',
      clubId: map['clubId'] as String?,
      matches: (map['matches'] as num?)?.toInt() ?? 0,
      innings: (map['innings'] as num?)?.toInt() ?? 0,
      runs: (map['runs'] as num?)?.toInt() ?? 0,
      highestScore: (map['highestScore'] as num?)?.toInt() ?? 0,
      ballsFaced: (map['ballsFaced'] as num?)?.toInt() ?? 0,
      fours: (map['fours'] as num?)?.toInt() ?? 0,
      sixes: (map['sixes'] as num?)?.toInt() ?? 0,
      thirties: (map['thirties'] as num?)?.toInt() ?? 0,
      fifties: (map['fifties'] as num?)?.toInt() ?? 0,
      hundreds: (map['hundreds'] as num?)?.toInt() ?? 0,
      bowlingMatches: (map['bowlingMatches'] as num?)?.toInt() ?? 0,
      oversBowled: (map['oversBowled'] as num?)?.toDouble() ?? 0,
      bowlingRuns: (map['bowlingRuns'] as num?)?.toInt() ?? 0,
      wickets: (map['wickets'] as num?)?.toInt() ?? 0,
      maidens: (map['maidens'] as num?)?.toInt() ?? 0,
      bestBowling: map['bestBowling'] as String? ?? '',
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'seriesId': seriesId,
        'userId': userId,
        if (playerDocId != null) 'playerDocId': playerDocId,
        'displayName': displayName,
        if (clubId != null) 'clubId': clubId,
        'matches': matches,
        'innings': innings,
        'runs': runs,
        'highestScore': highestScore,
        'ballsFaced': ballsFaced,
        'fours': fours,
        'sixes': sixes,
        'thirties': thirties,
        'fifties': fifties,
        'hundreds': hundreds,
        'bowlingMatches': bowlingMatches,
        'oversBowled': oversBowled,
        'bowlingRuns': bowlingRuns,
        'wickets': wickets,
        'maidens': maidens,
        'bestBowling': bestBowling,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, seriesId, userId, runs, wickets];
}
