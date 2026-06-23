import 'package:equatable/equatable.dart';
import '../../../core/constants/enums.dart';
import '../match_rules_model.dart';

/// Tournament-wide default rules — applied to generated fixtures unless overridden.
class TournamentRulesModel extends Equatable {
  const TournamentRulesModel({
    this.wideRuns = 1,
    this.noBallRuns = 1,
    this.wideCountsAsLegalDelivery = false,
    this.noBallCountsAsLegalDelivery = false,
    this.powerplayOvers,
    this.oversPerBowler = 4,
    this.playersPerTeam = 11,
    this.impactPlayerEnabled = false,
    this.wagonWheelEnabled = false,
    this.wagonWheelShotSelection = false,
    this.pointsPerWin = 2,
    this.pointsPerTie = 1,
    this.pointsPerLoss = 0,
    this.pointsPerNoResult = 1,
    this.ballType,
    this.pitchType,
    this.totalOvers = 20,
    this.ballsPerOver = 6,
    this.notes = '',
  });

  final int wideRuns;
  final int noBallRuns;
  final bool wideCountsAsLegalDelivery;
  final bool noBallCountsAsLegalDelivery;
  final int? powerplayOvers;
  final int oversPerBowler;
  final int playersPerTeam;
  final bool impactPlayerEnabled;
  final bool wagonWheelEnabled;
  final bool wagonWheelShotSelection;
  final int pointsPerWin;
  final int pointsPerTie;
  final int pointsPerLoss;
  final int pointsPerNoResult;
  final CricketBallType? ballType;
  final PitchType? pitchType;
  final int totalOvers;
  final int ballsPerOver;
  final String notes;

  factory TournamentRulesModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const TournamentRulesModel();
    return TournamentRulesModel(
      wideRuns: map['wideRuns'] as int? ?? 1,
      noBallRuns: map['noBallRuns'] as int? ?? 1,
      wideCountsAsLegalDelivery:
          map['wideCountsAsLegalDelivery'] as bool? ?? false,
      noBallCountsAsLegalDelivery:
          map['noBallCountsAsLegalDelivery'] as bool? ?? false,
      powerplayOvers: map['powerplayOvers'] as int?,
      oversPerBowler: map['oversPerBowler'] as int? ?? 4,
      playersPerTeam: map['playersPerTeam'] as int? ?? 11,
      impactPlayerEnabled: map['impactPlayerEnabled'] as bool? ?? false,
      wagonWheelEnabled: map['wagonWheelEnabled'] as bool? ?? false,
      wagonWheelShotSelection:
          map['wagonWheelShotSelection'] as bool? ?? false,
      pointsPerWin: map['pointsPerWin'] as int? ?? 2,
      pointsPerTie: map['pointsPerTie'] as int? ?? 1,
      pointsPerLoss: map['pointsPerLoss'] as int? ?? 0,
      pointsPerNoResult: map['pointsPerNoResult'] as int? ?? 1,
      ballType: map['ballType'] != null
          ? CricketBallType.values.firstWhere(
              (e) => e.name == map['ballType'],
              orElse: () => CricketBallType.tennis,
            )
          : null,
      pitchType: map['pitchType'] != null
          ? PitchType.values.firstWhere(
              (e) => e.name == map['pitchType'],
              orElse: () => PitchType.cement,
            )
          : null,
      totalOvers: map['totalOvers'] as int? ?? 20,
      ballsPerOver: map['ballsPerOver'] as int? ?? 6,
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'wideRuns': wideRuns,
        'noBallRuns': noBallRuns,
        'wideCountsAsLegalDelivery': wideCountsAsLegalDelivery,
        'noBallCountsAsLegalDelivery': noBallCountsAsLegalDelivery,
        if (powerplayOvers != null) 'powerplayOvers': powerplayOvers,
        'oversPerBowler': oversPerBowler,
        'playersPerTeam': playersPerTeam,
        'impactPlayerEnabled': impactPlayerEnabled,
        'wagonWheelEnabled': wagonWheelEnabled,
        'wagonWheelShotSelection': wagonWheelShotSelection,
        'pointsPerWin': pointsPerWin,
        'pointsPerTie': pointsPerTie,
        'pointsPerLoss': pointsPerLoss,
        'pointsPerNoResult': pointsPerNoResult,
        if (ballType != null) 'ballType': ballType!.name,
        if (pitchType != null) 'pitchType': pitchType!.name,
        'totalOvers': totalOvers,
        'ballsPerOver': ballsPerOver,
        'notes': notes,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  MatchRulesModel toMatchRules() {
    return MatchRulesModel(
      ballType: ballType,
      pitchType: pitchType,
      totalOvers: totalOvers,
      ballsPerOver: ballsPerOver,
      playersPerTeam: playersPerTeam,
      oversPerBowler: oversPerBowler,
      wideRuns: wideRuns,
      noBallRuns: noBallRuns,
      wideCountsAsLegalDelivery: wideCountsAsLegalDelivery,
      noBallCountsAsLegalDelivery: noBallCountsAsLegalDelivery,
      impactPlayerEnabled: impactPlayerEnabled,
      wagonWheelEnabled: wagonWheelEnabled,
      wagonWheelShotSelection: wagonWheelShotSelection,
      powerplayOvers: powerplayOvers,
      pointsPerWin: pointsPerWin,
      pointsPerTie: pointsPerTie,
      pointsPerLoss: pointsPerLoss,
      notes: notes.isEmpty ? null : notes,
    );
  }

  @override
  List<Object?> get props => [wideRuns, noBallRuns, pointsPerWin];
}
