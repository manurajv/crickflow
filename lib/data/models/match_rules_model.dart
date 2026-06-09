import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';

/// Fully customizable rules for standard or tennis cricket.
class MatchRulesModel extends Equatable {
  const MatchRulesModel({
    this.format = MatchFormat.standard,
    this.cricketMatchType = CricketMatchType.limitedOvers,
    this.ballType,
    this.totalOvers = 20,
    this.ballsPerOver = 6,
    this.oversPerBowler = 4,
    this.isManualOversPerBowler = false,
    this.wideRuns = 1,
    this.noBallRuns = 1,
    this.freeHitEnabled = true,
    this.maxInnings = 2,
    this.maxWickets = 10,
    this.superOverEnabled = false,
    this.powerplayOvers,
    this.powerplaySlots = const [[], [], []],
    this.wagonWheelEnabled = false,
    this.wagonWheelDots = false,
    this.wagonWheelRuns123 = false,
    this.wagonWheelShotSelection = false,
    this.wideCountsAsLegalDelivery = false,
    this.noBallCountsAsLegalDelivery = false,
    this.impactPlayerEnabled = false,
    this.pitchType,
    this.matchOfficials = const [],
    this.pointsPerWin = 2,
    this.pointsPerTie = 1,
    this.pointsPerLoss = 0,
    this.extrasCountToBowler = false,
    this.lastManStanding = false,
    this.notes,
  });

  final MatchFormat format;
  final CricketMatchType cricketMatchType;
  final CricketBallType? ballType;
  final int totalOvers;
  final int ballsPerOver;
  final int oversPerBowler;
  final bool isManualOversPerBowler;
  final int wideRuns;
  final int noBallRuns;
  final bool freeHitEnabled;
  final int maxInnings;
  final int maxWickets;
  final bool superOverEnabled;
  /// Legacy single powerplay length (optional).
  final int? powerplayOvers;
  /// Up to three powerplays; each inner list is selected over numbers.
  final List<List<int>> powerplaySlots;
  final bool wagonWheelEnabled;
  final bool wagonWheelDots;
  final bool wagonWheelRuns123;
  final bool wagonWheelShotSelection;
  final bool wideCountsAsLegalDelivery;
  final bool noBallCountsAsLegalDelivery;
  final bool impactPlayerEnabled;
  final PitchType? pitchType;
  final List<MatchOfficialRole> matchOfficials;
  final int pointsPerWin;
  final int pointsPerTie;
  final int pointsPerLoss;
  final bool extrasCountToBowler;
  final bool lastManStanding;
  final String? notes;

  int get totalBalls => totalOvers * ballsPerOver;

  int get activePowerplayCount =>
      powerplaySlots.where((s) => s.isNotEmpty).length;

  bool get isIndoor => cricketMatchType == CricketMatchType.indoor;

  bool get isTestMatch => cricketMatchType == CricketMatchType.testMatch;

  /// Primary ON/OFF toggle for wagon wheel capture during scoring.
  bool get wagonWheelActive => wagonWheelEnabled;

  /// `ceil(totalOvers / 5)` — minimum 1.
  static int calculateOversPerBowler(int totalOvers) {
    if (totalOvers < 1) return 1;
    return (totalOvers / 5).ceil();
  }

  static int clampOversPerBowler(int value, int totalOvers) {
    final maxOvers = totalOvers < 1 ? 1 : totalOvers;
    return value.clamp(1, maxOvers);
  }

  MatchRulesModel withTotalOvers(int totalOvers) {
    final nextTotal = totalOvers < 1 ? 1 : totalOvers;
    if (isManualOversPerBowler) {
      return copyWith(
        totalOvers: nextTotal,
        oversPerBowler: clampOversPerBowler(oversPerBowler, nextTotal),
      );
    }
    return copyWith(
      totalOvers: nextTotal,
      oversPerBowler: calculateOversPerBowler(nextTotal),
      isManualOversPerBowler: false,
    );
  }

  MatchRulesModel withManualOversPerBowler(int value) {
    return copyWith(
      oversPerBowler: clampOversPerBowler(value, totalOvers),
      isManualOversPerBowler: true,
    );
  }

  MatchRulesModel resetOversPerBowlerToAuto() {
    return copyWith(
      oversPerBowler: calculateOversPerBowler(totalOvers),
      isManualOversPerBowler: false,
    );
  }

  static CricketBallType defaultBallTypeFor(MatchFormat format) {
    return switch (format) {
      MatchFormat.tennis => CricketBallType.tennis,
      MatchFormat.custom => CricketBallType.indoor,
      MatchFormat.standard => CricketBallType.leather,
    };
  }

  static MatchFormat formatForMatchType(CricketMatchType type) {
    return switch (type) {
      CricketMatchType.indoor => MatchFormat.tennis,
      _ => MatchFormat.standard,
    };
  }

  static CricketBallType ballTypeForMatchType(CricketMatchType type) {
    return switch (type) {
      CricketMatchType.indoor => CricketBallType.indoor,
      CricketMatchType.limitedOvers => CricketBallType.leather,
      CricketMatchType.testMatch => CricketBallType.leather,
    };
  }

  static MatchRulesModel forMatchType(CricketMatchType type) {
    return switch (type) {
      CricketMatchType.indoor => MatchRulesModel(
          cricketMatchType: CricketMatchType.indoor,
          format: MatchFormat.tennis,
          ballType: CricketBallType.tennis,
          totalOvers: 6,
          oversPerBowler: calculateOversPerBowler(6),
          maxInnings: 1,
          wagonWheelEnabled: false,
          wagonWheelDots: false,
          wagonWheelRuns123: false,
          wagonWheelShotSelection: false,
        ),
      CricketMatchType.testMatch => MatchRulesModel(
          cricketMatchType: CricketMatchType.testMatch,
          totalOvers: 50,
          oversPerBowler: calculateOversPerBowler(50),
          maxInnings: 2,
        ),
      CricketMatchType.limitedOvers => MatchRulesModel.standardT20().copyWith(
            cricketMatchType: CricketMatchType.limitedOvers,
          ),
    };
  }

  CricketBallType get resolvedBallType =>
      ballType ?? ballTypeForMatchType(cricketMatchType);

  /// Maximum legal balls one bowler may bowl in an innings (full match allocation).
  int get maxBowlerLegalBalls => totalOvers * ballsPerOver;

  /// One-over super over (ICC-style defaults).
  factory MatchRulesModel.superOver() => const MatchRulesModel(
        totalOvers: 1,
        ballsPerOver: 6,
        maxWickets: 2,
        maxInnings: 1,
        freeHitEnabled: true,
      );

  factory MatchRulesModel.tennisCricket() => const MatchRulesModel(
        format: MatchFormat.tennis,
        cricketMatchType: CricketMatchType.indoor,
        ballType: CricketBallType.indoor,
        totalOvers: 6,
        ballsPerOver: 6,
        oversPerBowler: 6,
        wideRuns: 1,
        noBallRuns: 1,
        maxInnings: 1,
        maxWickets: 10,
      );

  factory MatchRulesModel.standardT20() => MatchRulesModel(
        format: MatchFormat.standard,
        cricketMatchType: CricketMatchType.limitedOvers,
        ballType: CricketBallType.tennis,
        totalOvers: 20,
        ballsPerOver: 6,
        oversPerBowler: calculateOversPerBowler(20),
        isManualOversPerBowler: false,
      );

  factory MatchRulesModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return MatchRulesModel.standardT20();
    return MatchRulesModel(
      format: MatchFormat.values.firstWhere(
        (e) => e.name == map['format'],
        orElse: () => MatchFormat.standard,
      ),
      cricketMatchType: _cricketMatchTypeFromString(
        map['cricketMatchType'] as String?,
      ),
      ballType: _ballTypeFromString(map['ballType'] as String?),
      totalOvers: map['totalOvers'] as int? ?? 20,
      ballsPerOver: map['ballsPerOver'] as int? ?? 6,
      oversPerBowler: map['oversPerBowler'] as int? ??
          calculateOversPerBowler(map['totalOvers'] as int? ?? 20),
      isManualOversPerBowler:
          map['isManualOversPerBowler'] as bool? ?? false,
      wideRuns: map['wideRuns'] as int? ?? 1,
      noBallRuns: map['noBallRuns'] as int? ?? 1,
      freeHitEnabled: map['freeHitEnabled'] as bool? ?? true,
      maxInnings: map['maxInnings'] as int? ?? 2,
      maxWickets: map['maxWickets'] as int? ?? 10,
      superOverEnabled: map['superOverEnabled'] as bool? ?? false,
      powerplayOvers: map['powerplayOvers'] as int?,
      powerplaySlots: _powerplaySlotsFromMap(map),
      wagonWheelEnabled: map['wagonWheelEnabled'] as bool? ?? false,
      wagonWheelDots: map['wagonWheelDots'] as bool? ??
          (map['wagonWheelEnabled'] as bool? ?? false),
      wagonWheelRuns123: map['wagonWheelRuns123'] as bool? ??
          (map['wagonWheelEnabled'] as bool? ?? false),
      wagonWheelShotSelection: map['wagonWheelShotSelection'] as bool? ??
          (map['wagonWheelEnabled'] as bool? ?? false),
      wideCountsAsLegalDelivery:
          map['wideCountsAsLegalDelivery'] as bool? ?? false,
      noBallCountsAsLegalDelivery:
          map['noBallCountsAsLegalDelivery'] as bool? ?? false,
      impactPlayerEnabled: map['impactPlayerEnabled'] as bool? ?? false,
      pitchType: _pitchFromString(map['pitchType'] as String?),
      matchOfficials: _officialsFromFirestore(map['matchOfficials']),
      pointsPerWin: map['pointsPerWin'] as int? ?? 2,
      pointsPerTie: map['pointsPerTie'] as int? ?? 1,
      pointsPerLoss: map['pointsPerLoss'] as int? ?? 0,
      extrasCountToBowler: map['extrasCountToBowler'] as bool? ?? false,
      lastManStanding: map['lastManStanding'] as bool? ?? false,
      notes: map['notes'] as String?,
    );
  }

  static List<List<int>> _powerplaySlotsFromMap(Map<String, dynamic> map) {
    final slot1 = map['powerplaySlot1'];
    final slot2 = map['powerplaySlot2'];
    final slot3 = map['powerplaySlot3'];
    if (slot1 is List || slot2 is List || slot3 is List) {
      return [
        _oversListFromFirestore(slot1),
        _oversListFromFirestore(slot2),
        _oversListFromFirestore(slot3),
      ];
    }
    // Legacy nested array (not valid in Firestore; only in-memory / old exports).
    final raw = map['powerplaySlots'] as List?;
    if (raw != null) {
      return List.generate(3, (i) {
        if (i >= raw.length) return <int>[];
        final slot = raw[i];
        if (slot is! List) return <int>[];
        return slot.map((e) => (e as num).toInt()).toList()..sort();
      });
    }
    final legacy = map['powerplayOvers'] as int?;
    if (legacy != null && legacy > 0) {
      return [List.generate(legacy, (i) => i + 1), [], []];
    }
    return const [[], [], []];
  }

  static List<int> _oversListFromFirestore(Object? raw) {
    if (raw is! List) return [];
    return raw.map((e) => (e as num).toInt()).toList()..sort();
  }

  static Map<String, List<int>> _powerplaySlotsToMap(List<List<int>> slots) {
    final s0 = slots.isNotEmpty ? slots[0] : <int>[];
    final s1 = slots.length > 1 ? slots[1] : <int>[];
    final s2 = slots.length > 2 ? slots[2] : <int>[];
    return {
      'powerplaySlot1': s0,
      'powerplaySlot2': s1,
      'powerplaySlot3': s2,
    };
  }

  static PitchType? _pitchFromString(String? raw) {
    if (raw == null) return null;
    return PitchType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => PitchType.turf,
    );
  }

  static List<MatchOfficialRole> _officialsFromFirestore(Object? raw) {
    if (raw is! List) return [];
    return raw
        .map(
          (e) => MatchOfficialRole.values.firstWhere(
            (r) => r.name == e.toString(),
            orElse: () => MatchOfficialRole.others,
          ),
        )
        .toList();
  }

  static CricketMatchType _cricketMatchTypeFromString(String? raw) {
    return switch (raw) {
      'boxTurf' => CricketMatchType.indoor,
      'pairCricket' || 'theHundred' => CricketMatchType.limitedOvers,
      _ => CricketMatchType.values.firstWhere(
          (e) => e.name == raw,
          orElse: () => CricketMatchType.limitedOvers,
        ),
    };
  }

  static CricketBallType? _ballTypeFromString(String? raw) {
    if (raw == null) return null;
    return CricketBallType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => CricketBallType.leather,
    );
  }

  Map<String, dynamic> toMap() => {
        'format': formatForMatchType(cricketMatchType).name,
        'cricketMatchType': cricketMatchType.name,
        'ballType': resolvedBallType.name,
        'totalOvers': totalOvers,
        'ballsPerOver': ballsPerOver,
        'oversPerBowler': oversPerBowler,
        'isManualOversPerBowler': isManualOversPerBowler,
        'wideRuns': wideRuns,
        'noBallRuns': noBallRuns,
        'freeHitEnabled': freeHitEnabled,
        'maxInnings': maxInnings,
        'maxWickets': maxWickets,
        'superOverEnabled': superOverEnabled,
        if (powerplayOvers != null) 'powerplayOvers': powerplayOvers,
        ..._powerplaySlotsToMap(powerplaySlots),
        'wagonWheelEnabled': wagonWheelEnabled,
        'wagonWheelDots': wagonWheelDots,
        'wagonWheelRuns123': wagonWheelRuns123,
        'wagonWheelShotSelection': wagonWheelShotSelection,
        'wideCountsAsLegalDelivery': wideCountsAsLegalDelivery,
        'noBallCountsAsLegalDelivery': noBallCountsAsLegalDelivery,
        'impactPlayerEnabled': impactPlayerEnabled,
        if (pitchType != null) 'pitchType': pitchType!.name,
        'matchOfficials': matchOfficials.map((e) => e.name).toList(),
        'pointsPerWin': pointsPerWin,
        'pointsPerTie': pointsPerTie,
        'pointsPerLoss': pointsPerLoss,
        'extrasCountToBowler': extrasCountToBowler,
        'lastManStanding': lastManStanding,
        if (notes != null) 'notes': notes,
      };

  MatchRulesModel copyWith({
    MatchFormat? format,
    CricketMatchType? cricketMatchType,
    CricketBallType? ballType,
    int? totalOvers,
    int? ballsPerOver,
    int? oversPerBowler,
    bool? isManualOversPerBowler,
    int? wideRuns,
    int? noBallRuns,
    bool? freeHitEnabled,
    int? maxInnings,
    int? maxWickets,
    bool? superOverEnabled,
    int? powerplayOvers,
    List<List<int>>? powerplaySlots,
    bool? wagonWheelEnabled,
    bool? wagonWheelDots,
    bool? wagonWheelRuns123,
    bool? wagonWheelShotSelection,
    bool? wideCountsAsLegalDelivery,
    bool? noBallCountsAsLegalDelivery,
    bool? impactPlayerEnabled,
    PitchType? pitchType,
    List<MatchOfficialRole>? matchOfficials,
    int? pointsPerWin,
    int? pointsPerTie,
    int? pointsPerLoss,
    bool? extrasCountToBowler,
    bool? lastManStanding,
    String? notes,
  }) {
    return MatchRulesModel(
      format: format ?? formatForMatchType(cricketMatchType ?? this.cricketMatchType),
      cricketMatchType: cricketMatchType ?? this.cricketMatchType,
      ballType: ballType ?? this.ballType,
      totalOvers: totalOvers ?? this.totalOvers,
      ballsPerOver: ballsPerOver ?? this.ballsPerOver,
      oversPerBowler: oversPerBowler ?? this.oversPerBowler,
      isManualOversPerBowler:
          isManualOversPerBowler ?? this.isManualOversPerBowler,
      wideRuns: wideRuns ?? this.wideRuns,
      noBallRuns: noBallRuns ?? this.noBallRuns,
      freeHitEnabled: freeHitEnabled ?? this.freeHitEnabled,
      maxInnings: maxInnings ?? this.maxInnings,
      maxWickets: maxWickets ?? this.maxWickets,
      superOverEnabled: superOverEnabled ?? this.superOverEnabled,
      powerplayOvers: powerplayOvers ?? this.powerplayOvers,
      powerplaySlots: powerplaySlots ?? this.powerplaySlots,
      wagonWheelEnabled: wagonWheelEnabled ?? this.wagonWheelEnabled,
      wagonWheelDots: wagonWheelDots ?? this.wagonWheelDots,
      wagonWheelRuns123: wagonWheelRuns123 ?? this.wagonWheelRuns123,
      wagonWheelShotSelection:
          wagonWheelShotSelection ?? this.wagonWheelShotSelection,
      wideCountsAsLegalDelivery:
          wideCountsAsLegalDelivery ?? this.wideCountsAsLegalDelivery,
      noBallCountsAsLegalDelivery:
          noBallCountsAsLegalDelivery ?? this.noBallCountsAsLegalDelivery,
      impactPlayerEnabled: impactPlayerEnabled ?? this.impactPlayerEnabled,
      pitchType: pitchType ?? this.pitchType,
      matchOfficials: matchOfficials ?? this.matchOfficials,
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
        cricketMatchType,
        totalOvers,
        ballsPerOver,
        oversPerBowler,
        isManualOversPerBowler,
        ballType,
        powerplaySlots,
        wagonWheelEnabled,
        pitchType,
      ];
}
