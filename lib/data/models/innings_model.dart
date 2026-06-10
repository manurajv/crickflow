import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';

/// Closed partnership between two batters.
class PartnershipRecord extends Equatable {
  const PartnershipRecord({
    required this.batterAId,
    required this.batterBId,
    this.batterAName = '',
    this.batterBName = '',
    this.runs = 0,
    this.balls = 0,
  });

  final String batterAId;
  final String batterBId;
  final String batterAName;
  final String batterBName;
  final int runs;
  final int balls;

  factory PartnershipRecord.fromMap(Map<String, dynamic> map) {
    return PartnershipRecord(
      batterAId: map['batterAId'] as String? ?? '',
      batterBId: map['batterBId'] as String? ?? '',
      batterAName: map['batterAName'] as String? ?? '',
      batterBName: map['batterBName'] as String? ?? '',
      runs: map['runs'] as int? ?? 0,
      balls: map['balls'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'batterAId': batterAId,
        'batterBId': batterBId,
        'batterAName': batterAName,
        'batterBName': batterBName,
        'runs': runs,
        'balls': balls,
      };

  @override
  List<Object?> get props => [batterAId, batterBId, runs, balls];
}

/// Fall-of-wicket entry for scorecard.
class FallOfWicketRecord extends Equatable {
  const FallOfWicketRecord({
    required this.wicketNumber,
    required this.batsmanId,
    this.batsmanName = '',
    required this.teamScore,
    required this.legalBalls,
    this.dismissal = '',
  });

  final int wicketNumber;
  final String batsmanId;
  final String batsmanName;
  final int teamScore;
  final int legalBalls;
  final String dismissal;

  factory FallOfWicketRecord.fromMap(Map<String, dynamic> map) {
    return FallOfWicketRecord(
      wicketNumber: map['wicketNumber'] as int? ?? 0,
      batsmanId: map['batsmanId'] as String? ?? '',
      batsmanName: map['batsmanName'] as String? ?? '',
      teamScore: map['teamScore'] as int? ?? 0,
      legalBalls: map['legalBalls'] as int? ?? 0,
      dismissal: map['dismissal'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'wicketNumber': wicketNumber,
        'batsmanId': batsmanId,
        'batsmanName': batsmanName,
        'teamScore': teamScore,
        'legalBalls': legalBalls,
        'dismissal': dismissal,
      };

  @override
  List<Object?> get props => [wicketNumber, batsmanId, teamScore];
}

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
    this.retiredHurt = false,
    this.isEligibleToReturn = false,
  });

  final String playerId;
  final String playerName;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final bool isOut;
  final String dismissalInfo;
  /// Left the crease hurt — not a wicket; may bat again.
  final bool retiredHurt;
  final bool isEligibleToReturn;

  BatsmanInningsModel copyWith({
    String? playerId,
    String? playerName,
    int? runs,
    int? balls,
    int? fours,
    int? sixes,
    bool? isOut,
    String? dismissalInfo,
    bool? retiredHurt,
    bool? isEligibleToReturn,
  }) {
    return BatsmanInningsModel(
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      runs: runs ?? this.runs,
      balls: balls ?? this.balls,
      fours: fours ?? this.fours,
      sixes: sixes ?? this.sixes,
      isOut: isOut ?? this.isOut,
      dismissalInfo: dismissalInfo ?? this.dismissalInfo,
      retiredHurt: retiredHurt ?? this.retiredHurt,
      isEligibleToReturn: isEligibleToReturn ?? this.isEligibleToReturn,
    );
  }

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
      retiredHurt: map['retiredHurt'] as bool? ?? false,
      isEligibleToReturn: map['isEligibleToReturn'] as bool? ?? false,
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
        if (retiredHurt) 'retiredHurt': retiredHurt,
        if (isEligibleToReturn) 'isEligibleToReturn': isEligibleToReturn,
      };

  @override
  List<Object?> get props => [playerId, runs, balls];
}

/// Fielding contributions for one player in an innings.
class FielderInningsModel extends Equatable {
  const FielderInningsModel({
    required this.playerId,
    this.playerName = '',
    this.catches = 0,
    this.runOuts = 0,
    this.stumpings = 0,
  });

  final String playerId;
  final String playerName;
  final int catches;
  final int runOuts;
  final int stumpings;

  factory FielderInningsModel.fromMap(Map<String, dynamic> map) {
    return FielderInningsModel(
      playerId: map['playerId'] as String? ?? '',
      playerName: map['playerName'] as String? ?? '',
      catches: map['catches'] as int? ?? 0,
      runOuts: map['runOuts'] as int? ?? 0,
      stumpings: map['stumpings'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'playerId': playerId,
        'playerName': playerName,
        'catches': catches,
        'runOuts': runOuts,
        'stumpings': stumpings,
      };

  @override
  List<Object?> get props => [playerId, catches, runOuts, stumpings];
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
    this.currentWicketKeeperId,
    this.currentWicketKeeperName,
    this.batsmen = const [],
    this.bowlers = const [],
    this.partnershipRuns = 0,
    this.partnershipBalls = 0,
    this.isFreeHitActive = false,
    this.targetRuns,
    this.isSuperOver = false,
    this.partnerships = const [],
    this.fallOfWickets = const [],
    this.fielders = const [],
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
  final String? currentWicketKeeperId;
  final String? currentWicketKeeperName;
  final List<BatsmanInningsModel> batsmen;
  final List<BowlerInningsModel> bowlers;
  final int partnershipRuns;
  final int partnershipBalls;
  final bool isFreeHitActive;
  /// Chase target set at innings start (2nd innings / super over).
  final int? targetRuns;
  final bool isSuperOver;
  final List<PartnershipRecord> partnerships;
  final List<FallOfWicketRecord> fallOfWickets;
  final List<FielderInningsModel> fielders;

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
      currentWicketKeeperId: map['currentWicketKeeperId'] as String?,
      currentWicketKeeperName: map['currentWicketKeeperName'] as String?,
      batsmen: (map['batsmen'] as List? ?? [])
          .map((e) => BatsmanInningsModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      bowlers: (map['bowlers'] as List? ?? [])
          .map((e) => BowlerInningsModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      partnershipRuns: map['partnershipRuns'] as int? ?? 0,
      partnershipBalls: map['partnershipBalls'] as int? ?? 0,
      isFreeHitActive: map['isFreeHitActive'] as bool? ?? false,
      targetRuns: map['targetRuns'] as int?,
      isSuperOver: map['isSuperOver'] as bool? ?? false,
      partnerships: (map['partnerships'] as List? ?? [])
          .map((e) => PartnershipRecord.fromMap(e as Map<String, dynamic>))
          .toList(),
      fallOfWickets: (map['fallOfWickets'] as List? ?? [])
          .map((e) => FallOfWicketRecord.fromMap(e as Map<String, dynamic>))
          .toList(),
      fielders: (map['fielders'] as List? ?? [])
          .map((e) => FielderInningsModel.fromMap(e as Map<String, dynamic>))
          .toList(),
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
        if (currentWicketKeeperId != null)
          'currentWicketKeeperId': currentWicketKeeperId,
        if (currentWicketKeeperName != null &&
            currentWicketKeeperName!.isNotEmpty)
          'currentWicketKeeperName': currentWicketKeeperName,
        'batsmen': batsmen.map((b) => b.toMap()).toList(),
        'bowlers': bowlers.map((b) => b.toMap()).toList(),
        'partnershipRuns': partnershipRuns,
        'partnershipBalls': partnershipBalls,
        'isFreeHitActive': isFreeHitActive,
        if (targetRuns != null) 'targetRuns': targetRuns,
        'isSuperOver': isSuperOver,
        // partnerships, fallOfWickets, fielders are derived from ball_events —
        // not persisted (see BALL_EVENT_ARCHITECTURE.md).
      };

  @override
  List<Object?> get props =>
      [inningsNumber, totalRuns, totalWickets, legalBalls];
}
