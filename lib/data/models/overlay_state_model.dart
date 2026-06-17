import 'package:equatable/equatable.dart';
import '../../core/utils/overs_formatter.dart';

/// Real-time overlay payload synced to stream viewers.
class OverlayStateModel extends Equatable {
  const OverlayStateModel({
    required this.matchId,
    this.teamAName = '',
    this.teamBName = '',
    this.battingTeamName = '',
    this.totalRuns = 0,
    this.totalWickets = 0,
    this.legalBalls = 0,
    this.ballsPerOver = 6,
    this.runRate = 0,
    this.requiredRunRate,
    this.target,
    this.strikerName = '',
    this.strikerRuns = 0,
    this.strikerBalls = 0,
    this.nonStrikerName = '',
    this.nonStrikerRuns = 0,
    this.nonStrikerBalls = 0,
    this.bowlerName = '',
    this.bowlerWickets = 0,
    this.bowlerRuns = 0,
    this.bowlerBalls = 0,
    this.matchStatus = 'Live',
    this.sponsorText = '',
    this.locationLabel = '',
    this.version = 0,
  });

  final String matchId;
  final String teamAName;
  final String teamBName;
  final String battingTeamName;
  final int totalRuns;
  final int totalWickets;
  final int legalBalls;
  final int ballsPerOver;
  final double runRate;
  final double? requiredRunRate;
  final int? target;
  final String strikerName;
  final int strikerRuns;
  final int strikerBalls;
  final String nonStrikerName;
  final int nonStrikerRuns;
  final int nonStrikerBalls;
  final String bowlerName;
  final int bowlerWickets;
  final int bowlerRuns;
  final int bowlerBalls;
  final String matchStatus;
  final String sponsorText;
  final String locationLabel;
  final int version;

  String get oversDisplay =>
      OversFormatter.formatOvers(legalBalls, ballsPerOver);

  String get scoreDisplay => '$totalRuns/$totalWickets';

  factory OverlayStateModel.fromMap(Map<String, dynamic> map) {
    return OverlayStateModel(
      matchId: map['matchId'] as String? ?? '',
      teamAName: map['teamAName'] as String? ?? '',
      teamBName: map['teamBName'] as String? ?? '',
      battingTeamName: map['battingTeamName'] as String? ?? '',
      totalRuns: map['totalRuns'] as int? ?? 0,
      totalWickets: map['totalWickets'] as int? ?? 0,
      legalBalls: map['legalBalls'] as int? ?? 0,
      ballsPerOver: map['ballsPerOver'] as int? ?? 6,
      runRate: (map['runRate'] as num?)?.toDouble() ?? 0,
      requiredRunRate: (map['requiredRunRate'] as num?)?.toDouble(),
      target: map['target'] as int?,
      strikerName: map['strikerName'] as String? ?? '',
      strikerRuns: map['strikerRuns'] as int? ?? 0,
      strikerBalls: map['strikerBalls'] as int? ?? 0,
      nonStrikerName: map['nonStrikerName'] as String? ?? '',
      nonStrikerRuns: map['nonStrikerRuns'] as int? ?? 0,
      nonStrikerBalls: map['nonStrikerBalls'] as int? ?? 0,
      bowlerName: map['bowlerName'] as String? ?? '',
      bowlerWickets: map['bowlerWickets'] as int? ?? 0,
      bowlerRuns: map['bowlerRuns'] as int? ?? 0,
      bowlerBalls: map['bowlerBalls'] as int? ?? 0,
      matchStatus: map['matchStatus'] as String? ?? 'Live',
      sponsorText: map['sponsorText'] as String? ?? '',
      locationLabel: map['locationLabel'] as String? ?? '',
      version: map['version'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'matchId': matchId,
        'teamAName': teamAName,
        'teamBName': teamBName,
        'battingTeamName': battingTeamName,
        'totalRuns': totalRuns,
        'totalWickets': totalWickets,
        'legalBalls': legalBalls,
        'ballsPerOver': ballsPerOver,
        'runRate': runRate,
        if (requiredRunRate != null) 'requiredRunRate': requiredRunRate,
        if (target != null) 'target': target,
        'strikerName': strikerName,
        'strikerRuns': strikerRuns,
        'strikerBalls': strikerBalls,
        'nonStrikerName': nonStrikerName,
        'nonStrikerRuns': nonStrikerRuns,
        'nonStrikerBalls': nonStrikerBalls,
        'bowlerName': bowlerName,
        'bowlerWickets': bowlerWickets,
        'bowlerRuns': bowlerRuns,
        'bowlerBalls': bowlerBalls,
        'matchStatus': matchStatus,
        'sponsorText': sponsorText,
        'locationLabel': locationLabel,
        'version': version,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  @override
  List<Object?> get props => [matchId, version, totalRuns];
}
