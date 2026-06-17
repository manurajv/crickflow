import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';
import 'dismissal_fielder.dart';
import 'wagon_wheel_data.dart';

class BallEventModel extends Equatable {
  const BallEventModel({
    required this.id,
    required this.matchId,
    required this.inningsNumber,
    required this.overNumber,
    this.overSegment = 1,
    required this.ballInOver,
    required this.eventType,
    this.runs = 0,
    this.batsmanRuns = 0,
    this.extraRuns = 0,
    this.isLegalDelivery = true,
    this.isFreeHit = false,
    this.tournamentId,
    this.battingTeamId,
    this.bowlingTeamId,
    this.byeRuns = 0,
    this.legByeRuns = 0,
    this.wideRuns = 0,
    this.noBallRuns = 0,
    this.penaltyRuns = 0,
    this.countsAsBallFaced = false,
    this.countsInOver = true,
    this.countsToBowler = true,
    this.isWicket = false,
    this.bowlerGetsWicket = false,
    this.isBoundary = false,
    this.boundaryType,
    this.strikerId,
    this.nonStrikerId,
    this.strikerAfterBall,
    this.nonStrikerAfterBall,
    this.createdBy,
    this.bowlerId,
    this.bowlerName,
    this.wicketType,
    this.dismissedPlayerId,
    this.fielderId,
    this.fielderName,
    this.dismissalText,
    this.fielders = const [],
    this.commentary = '',
    this.timestamp,
    this.sequence = 0,
    this.isHighlight = false,
    this.highlightTag,
    this.noBallRunsMode,
    this.noBallByeRuns = 0,
    this.noBallLegByeRuns = 0,
    this.wagonWheel,
    this.lineupStrikerName,
    this.lineupNonStrikerName,
    this.dismissedPlayerName,
    this.primaryFielderId,
    this.primaryFielderName,
    this.secondaryFielderId,
    this.secondaryFielderName,
    this.teamScoreAtWicket,
    this.overAtWicket,
    this.ballAtWicket,
    this.isMankad = false,
    this.wicketNumber,
    this.dismissalType,
    this.fielderIds = const [],
    this.fielderNames = const [],
    this.wicketKeeperId,
    this.wicketKeeperName,
    this.dismissalSubType,
    this.currentWicketKeeperId,
    this.currentWicketKeeperName,
    this.undoGroupId,
    this.nextStrikerId,
    this.nextStrikerName,
    this.runOutDeliveryKind,
    this.retiredHurt = false,
    this.isEligibleToReturn = false,
    this.isBowlerChange = false,
    this.previousBowlerId,
    this.bowlerChangeReason,
    this.swapReason,
    this.runsCancelled,
    this.swapNote,
  });

  final String id;
  final String matchId;
  final int inningsNumber;
  final int overNumber;
  /// Segment within [overNumber] when bowlers change mid-over (1 = A, 2 = B, …).
  final int overSegment;
  final int ballInOver;
  final BallEventType eventType;
  final int runs;
  /// Runs credited to the striker's bat (alias: runsOffBat).
  final int batsmanRuns;
  final int extraRuns;
  final bool isLegalDelivery;
  final bool isFreeHit;
  final String? tournamentId;
  final String? battingTeamId;
  final String? bowlingTeamId;
  final int byeRuns;
  final int legByeRuns;
  final int wideRuns;
  final int noBallRuns;
  final int penaltyRuns;
  final bool countsAsBallFaced;
  final bool countsInOver;
  final bool countsToBowler;
  final bool isWicket;
  final bool bowlerGetsWicket;
  final bool isBoundary;
  /// `four` or `six` when [isBoundary] is true.
  final String? boundaryType;
  final String? strikerId;
  final String? nonStrikerId;
  /// Striker at end of ball (after rotation / wicket).
  final String? strikerAfterBall;
  final String? nonStrikerAfterBall;
  /// Scorer uid who recorded this delivery.
  final String? createdBy;
  final String? bowlerId;
  final String? bowlerName;
  final WicketType? wicketType;
  final String? dismissedPlayerId;
  final String? fielderId;
  final String? fielderName;
  final String? dismissalText;
  final List<DismissalFielder> fielders;
  final String commentary;
  final DateTime? timestamp;
  final int sequence;
  final bool isHighlight;
  final String? highlightTag;
  final NoBallRunsMode? noBallRunsMode;
  final int noBallByeRuns;
  final int noBallLegByeRuns;
  final WagonWheelData? wagonWheel;
  /// Display names for [BallEventType.lineupChange] upserts.
  final String? lineupStrikerName;
  final String? lineupNonStrikerName;
  final String? dismissedPlayerName;
  final String? primaryFielderId;
  final String? primaryFielderName;
  final String? secondaryFielderId;
  final String? secondaryFielderName;
  final int? teamScoreAtWicket;
  final int? overAtWicket;
  final int? ballAtWicket;
  /// Mankad is stored as [runOut] with this flag; display uses bowler name.
  final bool isMankad;
  final int? wicketNumber;
  /// Persisted dismissal category (`run_out` for mankad).
  final String? dismissalType;
  final List<String> fielderIds;
  final List<String> fielderNames;
  final String? wicketKeeperId;
  final String? wicketKeeperName;
  /// Sub-type when [wicketType] is `caught` (e.g. `caught_behind`).
  final String? dismissalSubType;
  /// Active wicketkeeper at the time this event was recorded.
  final String? currentWicketKeeperId;
  final String? currentWicketKeeperName;
  /// Groups wicket + post-wicket lineup events for single undo.
  final String? undoGroupId;
  /// Striker chosen after run out (lineup change following dismissal).
  final String? nextStrikerId;
  final String? nextStrikerName;
  /// Wide / no-ball / bye / leg-bye context on a run-out delivery.
  final RunOutDeliveryKind? runOutDeliveryKind;
  final bool retiredHurt;
  final bool isEligibleToReturn;
  final bool isBowlerChange;
  final String? previousBowlerId;
  final String? bowlerChangeReason;
  final String? swapReason;
  final int? runsCancelled;
  final String? swapNote;

  /// Alias for [batsmanRuns] per ball-event spec.
  int get runsOffBat => batsmanRuns;

  /// Alias for [runs] per ball-event spec.
  int get totalRuns => runs;

  static WicketType? wicketTypeFromString(String? raw) {
    if (raw == null) return null;
    if (raw == 'retired') return WicketType.retiredHurt;
    return WicketType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => WicketType.other,
    );
  }

  factory BallEventModel.fromMap(String id, Map<String, dynamic> map) {
    return BallEventModel(
      id: id,
      matchId: map['matchId'] as String? ?? '',
      inningsNumber: map['inningsNumber'] as int? ?? 1,
      overNumber: map['overNumber'] as int? ?? 0,
      overSegment: map['overSegment'] as int? ?? 1,
      ballInOver: map['ballInOver'] as int? ?? 0,
      eventType: BallEventType.values.firstWhere(
        (e) => e.name == map['eventType'],
        orElse: () => BallEventType.runs,
      ),
      runs: map['runs'] as int? ?? 0,
      batsmanRuns: map['batsmanRuns'] as int? ?? 0,
      extraRuns: map['extraRuns'] as int? ?? 0,
      isLegalDelivery: map['isLegalDelivery'] as bool? ?? true,
      isFreeHit: map['isFreeHit'] as bool? ?? false,
      tournamentId: map['tournamentId'] as String?,
      battingTeamId: map['battingTeamId'] as String?,
      bowlingTeamId: map['bowlingTeamId'] as String?,
      byeRuns: map['byeRuns'] as int? ?? 0,
      legByeRuns: map['legByeRuns'] as int? ?? 0,
      wideRuns: map['wideRuns'] as int? ?? 0,
      noBallRuns: map['noBallRuns'] as int? ?? 0,
      penaltyRuns: map['penaltyRuns'] as int? ?? 0,
      countsAsBallFaced: map['countsAsBallFaced'] as bool? ?? false,
      countsInOver: map['countsInOver'] as bool? ?? true,
      countsToBowler: map['countsToBowler'] as bool? ?? true,
      isWicket: map['isWicket'] as bool? ?? false,
      bowlerGetsWicket: map['bowlerGetsWicket'] as bool? ?? false,
      isBoundary: map['isBoundary'] as bool? ?? false,
      boundaryType: map['boundaryType'] as String?,
      strikerId: map['strikerId'] as String?,
      nonStrikerId: map['nonStrikerId'] as String?,
      strikerAfterBall: map['strikerAfterBall'] as String?,
      nonStrikerAfterBall: map['nonStrikerAfterBall'] as String?,
      createdBy: map['createdBy'] as String?,
      bowlerId: map['bowlerId'] as String?,
      bowlerName: map['bowlerName'] as String?,
      wicketType: wicketTypeFromString(map['wicketType'] as String?),
      dismissedPlayerId: map['dismissedPlayerId'] as String?,
      fielderId: map['fielderId'] as String?,
      fielderName: map['fielderName'] as String?,
      dismissalText: map['dismissalText'] as String?,
      fielders: _fieldersFromMap(map['fielders']),
      commentary: map['commentary'] as String? ?? '',
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? ''),
      sequence: map['sequence'] as int? ?? 0,
      noBallRunsMode: map['noBallRunsMode'] != null
          ? NoBallRunsMode.values.firstWhere(
              (e) => e.name == map['noBallRunsMode'],
              orElse: () => NoBallRunsMode.bat,
            )
          : null,
      noBallByeRuns: map['noBallByeRuns'] as int? ?? 0,
      noBallLegByeRuns: map['noBallLegByeRuns'] as int? ?? 0,
      wagonWheel: map['wagonWheel'] != null
          ? WagonWheelData.fromMap(
              map['wagonWheel'] as Map<String, dynamic>,
            )
          : null,
      lineupStrikerName: map['lineupStrikerName'] as String?,
      lineupNonStrikerName: map['lineupNonStrikerName'] as String?,
      dismissedPlayerName: map['dismissedPlayerName'] as String?,
      primaryFielderId: map['primaryFielderId'] as String? ??
          map['fielderId'] as String?,
      primaryFielderName: map['primaryFielderName'] as String? ??
          map['fielderName'] as String?,
      secondaryFielderId: map['secondaryFielderId'] as String?,
      secondaryFielderName: map['secondaryFielderName'] as String?,
      teamScoreAtWicket: map['teamScoreAtWicket'] as int? ??
          map['teamScoreAtDismissal'] as int?,
      overAtWicket: map['overAtWicket'] as int? ?? map['overNumber'] as int?,
      ballAtWicket: map['ballAtWicket'] as int? ?? map['ballInOver'] as int?,
      isMankad: map['isMankad'] as bool? ?? false,
      wicketNumber: map['wicketNumber'] as int?,
      dismissalType: map['dismissalType'] as String?,
      fielderIds: _stringListFromMap(map['fielderIds']),
      fielderNames: _stringListFromMap(map['fielderNames']),
      wicketKeeperId: map['wicketKeeperId'] as String?,
      wicketKeeperName: map['wicketKeeperName'] as String?,
      dismissalSubType: map['dismissalSubType'] as String?,
      currentWicketKeeperId: map['currentWicketKeeperId'] as String?,
      currentWicketKeeperName: map['currentWicketKeeperName'] as String?,
      undoGroupId: map['undoGroupId'] as String?,
      nextStrikerId: map['nextStrikerId'] as String?,
      nextStrikerName: map['nextStrikerName'] as String?,
      runOutDeliveryKind: _runOutDeliveryKindFromMap(
        map['runOutDeliveryKind'] as String?,
      ),
      retiredHurt: map['retiredHurt'] as bool? ?? false,
      isEligibleToReturn: map['isEligibleToReturn'] as bool? ?? false,
      isBowlerChange: map['isBowlerChange'] as bool? ??
          map['bowlerChange'] as bool? ??
          false,
      previousBowlerId: map['previousBowlerId'] as String?,
      bowlerChangeReason: map['bowlerChangeReason'] as String? ??
          map['reason'] as String?,
      swapReason: map['swapReason'] as String? ??
          (map['eventType'] == 'batter_swap'
              ? map['reason'] as String?
              : null),
      runsCancelled: map['runsCancelled'] as int?,
      swapNote: map['swapNote'] as String?,
    );
  }

  static List<String> _stringListFromMap(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  static List<DismissalFielder> _fieldersFromMap(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => DismissalFielder.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> toMap() => {
        'matchId': matchId,
        'inningsNumber': inningsNumber,
        'overNumber': overNumber,
        if (overSegment > 1) 'overSegment': overSegment,
        'ballInOver': ballInOver,
        'eventType': eventType.name,
        'runs': runs,
        'batsmanRuns': batsmanRuns,
        'extraRuns': extraRuns,
        'isLegalDelivery': isLegalDelivery,
        'isFreeHit': isFreeHit,
        if (tournamentId != null) 'tournamentId': tournamentId,
        if (battingTeamId != null) 'battingTeamId': battingTeamId,
        if (bowlingTeamId != null) 'bowlingTeamId': bowlingTeamId,
        if (byeRuns > 0) 'byeRuns': byeRuns,
        if (legByeRuns > 0) 'legByeRuns': legByeRuns,
        if (wideRuns > 0) 'wideRuns': wideRuns,
        if (noBallRuns > 0) 'noBallRuns': noBallRuns,
        if (penaltyRuns > 0) 'penaltyRuns': penaltyRuns,
        'countsAsBallFaced': countsAsBallFaced,
        'countsInOver': countsInOver,
        'countsToBowler': countsToBowler,
        'isWicket': isWicket,
        'bowlerGetsWicket': bowlerGetsWicket,
        'isBoundary': isBoundary,
        if (boundaryType != null) 'boundaryType': boundaryType,
        if (strikerId != null) 'strikerId': strikerId,
        if (nonStrikerId != null) 'nonStrikerId': nonStrikerId,
        if (strikerAfterBall != null) 'strikerAfterBall': strikerAfterBall,
        if (nonStrikerAfterBall != null)
          'nonStrikerAfterBall': nonStrikerAfterBall,
        if (createdBy != null) 'createdBy': createdBy,
        if (bowlerId != null) 'bowlerId': bowlerId,
        if (bowlerName != null && bowlerName!.isNotEmpty) 'bowlerName': bowlerName,
        if (wicketType != null) 'wicketType': wicketType!.name,
        if (dismissedPlayerId != null) 'dismissedPlayerId': dismissedPlayerId,
        if (fielderId != null) 'fielderId': fielderId,
        if (fielderName != null && fielderName!.isNotEmpty)
          'fielderName': fielderName,
        if (dismissalText != null && dismissalText!.isNotEmpty)
          'dismissalText': dismissalText,
        if (fielders.isNotEmpty)
          'fielders': fielders.map((f) => f.toMap()).toList(),
        'commentary': commentary,
        'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
        'sequence': sequence,
        'isHighlight': isHighlight,
        if (highlightTag != null) 'highlightTag': highlightTag,
        if (noBallRunsMode != null) 'noBallRunsMode': noBallRunsMode!.name,
        if (noBallByeRuns > 0) 'noBallByeRuns': noBallByeRuns,
        if (noBallLegByeRuns > 0) 'noBallLegByeRuns': noBallLegByeRuns,
        if (wagonWheel != null) 'wagonWheel': wagonWheel!.toMap(),
        if (lineupStrikerName != null) 'lineupStrikerName': lineupStrikerName,
        if (lineupNonStrikerName != null)
          'lineupNonStrikerName': lineupNonStrikerName,
        if (dismissedPlayerName != null && dismissedPlayerName!.isNotEmpty)
          'dismissedPlayerName': dismissedPlayerName,
        if (primaryFielderId != null) 'primaryFielderId': primaryFielderId,
        if (primaryFielderName != null && primaryFielderName!.isNotEmpty)
          'primaryFielderName': primaryFielderName,
        if (secondaryFielderId != null) 'secondaryFielderId': secondaryFielderId,
        if (secondaryFielderName != null && secondaryFielderName!.isNotEmpty)
          'secondaryFielderName': secondaryFielderName,
        if (teamScoreAtWicket != null) ...{
          'teamScoreAtWicket': teamScoreAtWicket,
          'teamScoreAtDismissal': teamScoreAtWicket,
        },
        if (overAtWicket != null) 'overAtWicket': overAtWicket,
        if (ballAtWicket != null) 'ballAtWicket': ballAtWicket,
        if (isMankad) 'isMankad': true,
        if (wicketNumber != null) 'wicketNumber': wicketNumber,
        if (dismissalType != null && dismissalType!.isNotEmpty)
          'dismissalType': dismissalType,
        if (fielderIds.isNotEmpty) 'fielderIds': fielderIds,
        if (fielderNames.isNotEmpty) 'fielderNames': fielderNames,
        if (wicketKeeperId != null) 'wicketKeeperId': wicketKeeperId,
        if (wicketKeeperName != null && wicketKeeperName!.isNotEmpty)
          'wicketKeeperName': wicketKeeperName,
        if (dismissalSubType != null && dismissalSubType!.isNotEmpty)
          'dismissalSubType': dismissalSubType,
        if (currentWicketKeeperId != null)
          'currentWicketKeeperId': currentWicketKeeperId,
        if (currentWicketKeeperName != null &&
            currentWicketKeeperName!.isNotEmpty)
          'currentWicketKeeperName': currentWicketKeeperName,
        if (undoGroupId != null && undoGroupId!.isNotEmpty)
          'undoGroupId': undoGroupId,
        if (nextStrikerId != null) 'nextStrikerId': nextStrikerId,
        if (nextStrikerName != null && nextStrikerName!.isNotEmpty)
          'nextStrikerName': nextStrikerName,
        if (runOutDeliveryKind != null &&
            runOutDeliveryKind != RunOutDeliveryKind.normal)
          'runOutDeliveryKind': runOutDeliveryKind!.name,
        if (retiredHurt) 'retiredHurt': true,
        if (isEligibleToReturn) 'isEligibleToReturn': true,
        if (isBowlerChange) 'bowlerChange': true,
        if (isBowlerChange) 'isBowlerChange': true,
        if (previousBowlerId != null) 'previousBowlerId': previousBowlerId,
        if (bowlerChangeReason != null && bowlerChangeReason!.isNotEmpty)
          'bowlerChangeReason': bowlerChangeReason,
        if (swapReason != null && swapReason!.isNotEmpty) 'swapReason': swapReason,
        if (runsCancelled != null) 'runsCancelled': runsCancelled,
        if (swapNote != null && swapNote!.isNotEmpty) 'swapNote': swapNote,
      };

  /// Flat fielder id/name lists for analytics (from [fielders] when empty).
  List<String> get assistingFielderIds =>
      fielderIds.isNotEmpty
          ? fielderIds
          : fielders.map((f) => f.playerId).where((id) => id.isNotEmpty).toList();

  List<String> get assistingFielderNames =>
      fielderNames.isNotEmpty
          ? fielderNames
          : fielders
              .map((f) => f.playerName)
              .where((name) => name.isNotEmpty)
              .toList();

  static List<String> fielderIdsFromFielders(List<DismissalFielder> fielders) =>
      fielders.map((f) => f.playerId).where((id) => id.isNotEmpty).toList();

  static List<String> fielderNamesFromFielders(
    List<DismissalFielder> fielders,
  ) =>
      fielders
          .map((f) => f.playerName)
          .where((name) => name.isNotEmpty)
          .toList();

  static RunOutDeliveryKind? _runOutDeliveryKindFromMap(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return RunOutDeliveryKind.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => RunOutDeliveryKind.normal,
    );
  }

  static String dismissalTypeForEvent({
    required WicketType? wicketType,
    required bool isMankad,
    String? dismissalSubType,
  }) {
    if (isMankad || wicketType == WicketType.mankad) return 'run_out';
    if (wicketType == null) return '';
    if (wicketType == WicketType.caught ||
        wicketType == WicketType.caughtBehind) {
      return 'caught';
    }
    return wicketType.name;
  }

  BallEventModel copyWith({
    String? id,
    String? matchId,
    int? inningsNumber,
    int? overNumber,
    int? overSegment,
    int? ballInOver,
    BallEventType? eventType,
    int? runs,
    int? batsmanRuns,
    int? extraRuns,
    bool? isLegalDelivery,
    bool? isFreeHit,
    String? tournamentId,
    String? battingTeamId,
    String? bowlingTeamId,
    int? byeRuns,
    int? legByeRuns,
    int? wideRuns,
    int? noBallRuns,
    int? penaltyRuns,
    bool? countsAsBallFaced,
    bool? countsInOver,
    bool? countsToBowler,
    bool? isWicket,
    bool? bowlerGetsWicket,
    bool? isBoundary,
    String? boundaryType,
    String? strikerId,
    String? nonStrikerId,
    String? strikerAfterBall,
    String? nonStrikerAfterBall,
    String? createdBy,
    String? bowlerId,
    String? bowlerName,
    WicketType? wicketType,
    String? dismissedPlayerId,
    String? fielderId,
    String? fielderName,
    String? dismissalText,
    List<DismissalFielder>? fielders,
    String? commentary,
    DateTime? timestamp,
    int? sequence,
    bool? isHighlight,
    String? highlightTag,
    NoBallRunsMode? noBallRunsMode,
    int? noBallByeRuns,
    int? noBallLegByeRuns,
    WagonWheelData? wagonWheel,
    String? lineupStrikerName,
    String? lineupNonStrikerName,
    String? dismissedPlayerName,
    String? primaryFielderId,
    String? primaryFielderName,
    String? secondaryFielderId,
    String? secondaryFielderName,
    int? teamScoreAtWicket,
    int? overAtWicket,
    int? ballAtWicket,
    bool? isMankad,
    int? wicketNumber,
    String? dismissalType,
    List<String>? fielderIds,
    List<String>? fielderNames,
    String? wicketKeeperId,
    String? wicketKeeperName,
    String? dismissalSubType,
    String? currentWicketKeeperId,
    String? currentWicketKeeperName,
    String? undoGroupId,
    String? nextStrikerId,
    String? nextStrikerName,
    RunOutDeliveryKind? runOutDeliveryKind,
    bool? retiredHurt,
    bool? isEligibleToReturn,
    bool? isBowlerChange,
    String? previousBowlerId,
    String? bowlerChangeReason,
    String? swapReason,
    int? runsCancelled,
    String? swapNote,
  }) {
    return BallEventModel(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      inningsNumber: inningsNumber ?? this.inningsNumber,
      overNumber: overNumber ?? this.overNumber,
      overSegment: overSegment ?? this.overSegment,
      ballInOver: ballInOver ?? this.ballInOver,
      eventType: eventType ?? this.eventType,
      runs: runs ?? this.runs,
      batsmanRuns: batsmanRuns ?? this.batsmanRuns,
      extraRuns: extraRuns ?? this.extraRuns,
      isLegalDelivery: isLegalDelivery ?? this.isLegalDelivery,
      isFreeHit: isFreeHit ?? this.isFreeHit,
      tournamentId: tournamentId ?? this.tournamentId,
      battingTeamId: battingTeamId ?? this.battingTeamId,
      bowlingTeamId: bowlingTeamId ?? this.bowlingTeamId,
      byeRuns: byeRuns ?? this.byeRuns,
      legByeRuns: legByeRuns ?? this.legByeRuns,
      wideRuns: wideRuns ?? this.wideRuns,
      noBallRuns: noBallRuns ?? this.noBallRuns,
      penaltyRuns: penaltyRuns ?? this.penaltyRuns,
      countsAsBallFaced: countsAsBallFaced ?? this.countsAsBallFaced,
      countsInOver: countsInOver ?? this.countsInOver,
      countsToBowler: countsToBowler ?? this.countsToBowler,
      isWicket: isWicket ?? this.isWicket,
      bowlerGetsWicket: bowlerGetsWicket ?? this.bowlerGetsWicket,
      isBoundary: isBoundary ?? this.isBoundary,
      boundaryType: boundaryType ?? this.boundaryType,
      strikerId: strikerId ?? this.strikerId,
      nonStrikerId: nonStrikerId ?? this.nonStrikerId,
      strikerAfterBall: strikerAfterBall ?? this.strikerAfterBall,
      nonStrikerAfterBall: nonStrikerAfterBall ?? this.nonStrikerAfterBall,
      createdBy: createdBy ?? this.createdBy,
      bowlerId: bowlerId ?? this.bowlerId,
      bowlerName: bowlerName ?? this.bowlerName,
      wicketType: wicketType ?? this.wicketType,
      dismissedPlayerId: dismissedPlayerId ?? this.dismissedPlayerId,
      fielderId: fielderId ?? this.fielderId,
      fielderName: fielderName ?? this.fielderName,
      dismissalText: dismissalText ?? this.dismissalText,
      fielders: fielders ?? this.fielders,
      commentary: commentary ?? this.commentary,
      timestamp: timestamp ?? this.timestamp,
      sequence: sequence ?? this.sequence,
      isHighlight: isHighlight ?? this.isHighlight,
      highlightTag: highlightTag ?? this.highlightTag,
      noBallRunsMode: noBallRunsMode ?? this.noBallRunsMode,
      noBallByeRuns: noBallByeRuns ?? this.noBallByeRuns,
      noBallLegByeRuns: noBallLegByeRuns ?? this.noBallLegByeRuns,
      wagonWheel: wagonWheel ?? this.wagonWheel,
      lineupStrikerName: lineupStrikerName ?? this.lineupStrikerName,
      lineupNonStrikerName: lineupNonStrikerName ?? this.lineupNonStrikerName,
      dismissedPlayerName: dismissedPlayerName ?? this.dismissedPlayerName,
      primaryFielderId: primaryFielderId ?? this.primaryFielderId,
      primaryFielderName: primaryFielderName ?? this.primaryFielderName,
      secondaryFielderId: secondaryFielderId ?? this.secondaryFielderId,
      secondaryFielderName: secondaryFielderName ?? this.secondaryFielderName,
      teamScoreAtWicket: teamScoreAtWicket ?? this.teamScoreAtWicket,
      overAtWicket: overAtWicket ?? this.overAtWicket,
      ballAtWicket: ballAtWicket ?? this.ballAtWicket,
      isMankad: isMankad ?? this.isMankad,
      wicketNumber: wicketNumber ?? this.wicketNumber,
      dismissalType: dismissalType ?? this.dismissalType,
      fielderIds: fielderIds ?? this.fielderIds,
      fielderNames: fielderNames ?? this.fielderNames,
      wicketKeeperId: wicketKeeperId ?? this.wicketKeeperId,
      wicketKeeperName: wicketKeeperName ?? this.wicketKeeperName,
      dismissalSubType: dismissalSubType ?? this.dismissalSubType,
      currentWicketKeeperId:
          currentWicketKeeperId ?? this.currentWicketKeeperId,
      currentWicketKeeperName:
          currentWicketKeeperName ?? this.currentWicketKeeperName,
      undoGroupId: undoGroupId ?? this.undoGroupId,
      nextStrikerId: nextStrikerId ?? this.nextStrikerId,
      nextStrikerName: nextStrikerName ?? this.nextStrikerName,
      runOutDeliveryKind: runOutDeliveryKind ?? this.runOutDeliveryKind,
      retiredHurt: retiredHurt ?? this.retiredHurt,
      isEligibleToReturn: isEligibleToReturn ?? this.isEligibleToReturn,
      isBowlerChange: isBowlerChange ?? this.isBowlerChange,
      previousBowlerId: previousBowlerId ?? this.previousBowlerId,
      bowlerChangeReason: bowlerChangeReason ?? this.bowlerChangeReason,
      swapReason: swapReason ?? this.swapReason,
      runsCancelled: runsCancelled ?? this.runsCancelled,
      swapNote: swapNote ?? this.swapNote,
    );
  }

  @override
  List<Object?> get props => [id, matchId, sequence];
}
