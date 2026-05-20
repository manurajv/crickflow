import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';

/// Fully customizable rules for standard or tennis cricket.
class MatchRulesModel extends Equatable {
  const MatchRulesModel({
    this.format = MatchFormat.standard,
    this.ballType,
    this.totalOvers = 20,
    this.ballsPerOver = 6,
    this.wideRuns = 1,
    this.noBallRuns = 1,
    this.freeHitEnabled = true,
    this.maxInnings = 2,
    this.maxWickets = 10,
    this.superOverEnabled = false,
    this.powerplayOvers,
    this.pointsPerWin = 2,
    this.pointsPerTie = 1,
    this.pointsPerLoss = 0,
    this.extrasCountToBowler = false,
    this.lastManStanding = false,
    this.notes,
  });

  final MatchFormat format;
  /// Leather / tennis / indoor — defaults from [format] when null.
  final CricketBallType? ballType;
  final int totalOvers;
  final int ballsPerOver;
  final int wideRuns;
  final int noBallRuns;
  final bool freeHitEnabled;
  final int maxInnings;
  final int maxWickets;
  final bool superOverEnabled;
  final int? powerplayOvers;
  final int pointsPerWin;
  final int pointsPerTie;
  final int pointsPerLoss;
  final bool extrasCountToBowler;
  final bool lastManStanding;
  final String? notes;

  int get totalBalls => totalOvers * ballsPerOver;

  static CricketBallType defaultBallTypeFor(MatchFormat format) {
    return switch (format) {
      MatchFormat.tennis => CricketBallType.tennis,
      MatchFormat.custom => CricketBallType.indoor,
      MatchFormat.standard => CricketBallType.leather,
    };
  }

  CricketBallType get resolvedBallType =>
      ballType ?? defaultBallTypeFor(format);

  factory MatchRulesModel.tennisCricket() => const MatchRulesModel(
        format: MatchFormat.tennis,
        ballType: CricketBallType.tennis,
        totalOvers: 6,
        ballsPerOver: 6,
        wideRuns: 1,
        noBallRuns: 1,
        maxInnings: 1,
        maxWickets: 10,
      );

  factory MatchRulesModel.standardT20() => const MatchRulesModel(
        format: MatchFormat.standard,
        ballType: CricketBallType.leather,
        totalOvers: 20,
        ballsPerOver: 6,
      );

  factory MatchRulesModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return MatchRulesModel.standardT20();
    return MatchRulesModel(
      format: MatchFormat.values.firstWhere(
        (e) => e.name == map['format'],
        orElse: () => MatchFormat.standard,
      ),
      ballType: _ballTypeFromString(map['ballType'] as String?),
      totalOvers: map['totalOvers'] as int? ?? 20,
      ballsPerOver: map['ballsPerOver'] as int? ?? 6,
      wideRuns: map['wideRuns'] as int? ?? 1,
      noBallRuns: map['noBallRuns'] as int? ?? 1,
      freeHitEnabled: map['freeHitEnabled'] as bool? ?? true,
      maxInnings: map['maxInnings'] as int? ?? 2,
      maxWickets: map['maxWickets'] as int? ?? 10,
      superOverEnabled: map['superOverEnabled'] as bool? ?? false,
      powerplayOvers: map['powerplayOvers'] as int?,
      pointsPerWin: map['pointsPerWin'] as int? ?? 2,
      pointsPerTie: map['pointsPerTie'] as int? ?? 1,
      pointsPerLoss: map['pointsPerLoss'] as int? ?? 0,
      extrasCountToBowler: map['extrasCountToBowler'] as bool? ?? false,
      lastManStanding: map['lastManStanding'] as bool? ?? false,
      notes: map['notes'] as String?,
    );
  }

  static CricketBallType? _ballTypeFromString(String? raw) {
    if (raw == null) return null;
    return CricketBallType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => CricketBallType.leather,
    );
  }

  Map<String, dynamic> toMap() => {
        'format': format.name,
        'ballType': resolvedBallType.name,
        'totalOvers': totalOvers,
        'ballsPerOver': ballsPerOver,
        'wideRuns': wideRuns,
        'noBallRuns': noBallRuns,
        'freeHitEnabled': freeHitEnabled,
        'maxInnings': maxInnings,
        'maxWickets': maxWickets,
        'superOverEnabled': superOverEnabled,
        if (powerplayOvers != null) 'powerplayOvers': powerplayOvers,
        'pointsPerWin': pointsPerWin,
        'pointsPerTie': pointsPerTie,
        'pointsPerLoss': pointsPerLoss,
        'extrasCountToBowler': extrasCountToBowler,
        'lastManStanding': lastManStanding,
        if (notes != null) 'notes': notes,
      };

  MatchRulesModel copyWith({
    MatchFormat? format,
    CricketBallType? ballType,
    int? totalOvers,
    int? ballsPerOver,
    int? wideRuns,
    int? noBallRuns,
    bool? freeHitEnabled,
    int? maxInnings,
    int? maxWickets,
    bool? superOverEnabled,
    int? powerplayOvers,
    int? pointsPerWin,
    int? pointsPerTie,
    int? pointsPerLoss,
    bool? extrasCountToBowler,
    bool? lastManStanding,
    String? notes,
  }) {
    return MatchRulesModel(
      format: format ?? this.format,
      ballType: ballType ?? this.ballType,
      totalOvers: totalOvers ?? this.totalOvers,
      ballsPerOver: ballsPerOver ?? this.ballsPerOver,
      wideRuns: wideRuns ?? this.wideRuns,
      noBallRuns: noBallRuns ?? this.noBallRuns,
      freeHitEnabled: freeHitEnabled ?? this.freeHitEnabled,
      maxInnings: maxInnings ?? this.maxInnings,
      maxWickets: maxWickets ?? this.maxWickets,
      superOverEnabled: superOverEnabled ?? this.superOverEnabled,
      powerplayOvers: powerplayOvers ?? this.powerplayOvers,
      pointsPerWin: pointsPerWin ?? this.pointsPerWin,
      pointsPerTie: pointsPerTie ?? this.pointsPerTie,
      pointsPerLoss: pointsPerLoss ?? this.pointsPerLoss,
      extrasCountToBowler: extrasCountToBowler ?? this.extrasCountToBowler,
      lastManStanding: lastManStanding ?? this.lastManStanding,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
        format,
        totalOvers,
        ballsPerOver,
        wideRuns,
        noBallRuns,
        freeHitEnabled,
        maxInnings,
        maxWickets,
      ];
}
