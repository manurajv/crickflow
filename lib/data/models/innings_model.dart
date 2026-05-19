import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';

class BatsmanInningsModel extends Equatable {
  const BatsmanInningsModel({
    required this.playerId,
    this.playerName = '',
    this.runs = 0,
    this.balls = 0,
    this.fours = 0,
    this.sixes = 0,
    this.isOut = false,
    this.dismissalInfo = '',
  });

  final String playerId;
  final String playerName;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final bool isOut;
  final String dismissalInfo;

  factory BatsmanInningsModel.fromMap(Map<String, dynamic> map) {
    return BatsmanInningsModel(
      playerId: map['playerId'] as String? ?? '',
      playerName: map['playerName'] as String? ?? '',
      runs: map['runs'] as int? ?? 0,
      balls: map['balls'] as int? ?? 0,
      fours: map['fours'] as int? ?? 0,
      sixes: map['sixes'] as int? ?? 0,
      isOut: map['isOut'] as bool? ?? false,
      dismissalInfo: map['dismissalInfo'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'playerId': playerId,
        'playerName': playerName,
        'runs': runs,
        'balls': balls,
        'fours': fours,
        'sixes': sixes,
        'isOut': isOut,
        'dismissalInfo': dismissalInfo,
      };

  @override
  List<Object?> get props => [playerId, runs, balls];
}

class BowlerInningsModel extends Equatable {
  const BowlerInningsModel({
    required this.playerId,
    this.playerName = '',
    this.oversBowledBalls = 0,
    this.runsConceded = 0,
    this.wickets = 0,
    this.wides = 0,
    this.noBalls = 0,
  });

  final String playerId;
  final String playerName;
  final int oversBowledBalls;
  final int runsConceded;
  final int wickets;
  final int wides;
  final int noBalls;

  factory BowlerInningsModel.fromMap(Map<String, dynamic> map) {
    return BowlerInningsModel(
      playerId: map['playerId'] as String? ?? '',
      playerName: map['playerName'] as String? ?? '',
      oversBowledBalls: map['oversBowledBalls'] as int? ?? 0,
      runsConceded: map['runsConceded'] as int? ?? 0,
      wickets: map['wickets'] as int? ?? 0,
      wides: map['wides'] as int? ?? 0,
      noBalls: map['noBalls'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'playerId': playerId,
        'playerName': playerName,
        'oversBowledBalls': oversBowledBalls,
        'runsConceded': runsConceded,
        'wickets': wickets,
        'wides': wides,
        'noBalls': noBalls,
      };

  @override
  List<Object?> get props => [playerId, wickets, runsConceded];
}

class InningsModel extends Equatable {
  const InningsModel({
    required this.inningsNumber,
    required this.battingTeamId,
    required this.bowlingTeamId,
    this.status = InningsStatus.notStarted,
    this.totalRuns = 0,
    this.totalWickets = 0,
    this.legalBalls = 0,
    this.extras = 0,
    this.strikerId,
    this.nonStrikerId,
    this.currentBowlerId,
    this.batsmen = const [],
    this.bowlers = const [],
    this.partnershipRuns = 0,
    this.partnershipBalls = 0,
    this.isFreeHitActive = false,
  });

  final int inningsNumber;
  final String battingTeamId;
  final String bowlingTeamId;
  final InningsStatus status;
  final int totalRuns;
  final int totalWickets;
  final int legalBalls;
  final int extras;
  final String? strikerId;
  final String? nonStrikerId;
  final String? currentBowlerId;
  final List<BatsmanInningsModel> batsmen;
  final List<BowlerInningsModel> bowlers;
  final int partnershipRuns;
  final int partnershipBalls;
  final bool isFreeHitActive;

  factory InningsModel.fromMap(Map<String, dynamic> map) {
    return InningsModel(
      inningsNumber: map['inningsNumber'] as int? ?? 1,
      battingTeamId: map['battingTeamId'] as String? ?? '',
      bowlingTeamId: map['bowlingTeamId'] as String? ?? '',
      status: InningsStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => InningsStatus.notStarted,
      ),
      totalRuns: map['totalRuns'] as int? ?? 0,
      totalWickets: map['totalWickets'] as int? ?? 0,
      legalBalls: map['legalBalls'] as int? ?? 0,
      extras: map['extras'] as int? ?? 0,
      strikerId: map['strikerId'] as String?,
      nonStrikerId: map['nonStrikerId'] as String?,
      currentBowlerId: map['currentBowlerId'] as String?,
      batsmen: (map['batsmen'] as List? ?? [])
          .map((e) => BatsmanInningsModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      bowlers: (map['bowlers'] as List? ?? [])
          .map((e) => BowlerInningsModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      partnershipRuns: map['partnershipRuns'] as int? ?? 0,
      partnershipBalls: map['partnershipBalls'] as int? ?? 0,
      isFreeHitActive: map['isFreeHitActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'inningsNumber': inningsNumber,
        'battingTeamId': battingTeamId,
        'bowlingTeamId': bowlingTeamId,
        'status': status.name,
        'totalRuns': totalRuns,
        'totalWickets': totalWickets,
        'legalBalls': legalBalls,
        'extras': extras,
        if (strikerId != null) 'strikerId': strikerId,
        if (nonStrikerId != null) 'nonStrikerId': nonStrikerId,
        if (currentBowlerId != null) 'currentBowlerId': currentBowlerId,
        'batsmen': batsmen.map((b) => b.toMap()).toList(),
        'bowlers': bowlers.map((b) => b.toMap()).toList(),
        'partnershipRuns': partnershipRuns,
        'partnershipBalls': partnershipBalls,
        'isFreeHitActive': isFreeHitActive,
      };

  @override
  List<Object?> get props =>
      [inningsNumber, totalRuns, totalWickets, legalBalls];
}
