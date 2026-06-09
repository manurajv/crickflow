import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';
import 'wagon_wheel_data.dart';

class BallEventModel extends Equatable {
  const BallEventModel({
    required this.id,
    required this.matchId,
    required this.inningsNumber,
    required this.overNumber,
    required this.ballInOver,
    required this.eventType,
    this.runs = 0,
    this.batsmanRuns = 0,
    this.extraRuns = 0,
    this.isLegalDelivery = true,
    this.isFreeHit = false,
    this.strikerId,
    this.nonStrikerId,
    this.bowlerId,
    this.wicketType,
    this.dismissedPlayerId,
    this.fielderId,
    this.commentary = '',
    this.timestamp,
    this.sequence = 0,
    this.isHighlight = false,
    this.highlightTag,
    this.noBallRunsMode,
    this.noBallByeRuns = 0,
    this.noBallLegByeRuns = 0,
    this.wagonWheel,
  });

  final String id;
  final String matchId;
  final int inningsNumber;
  final int overNumber;
  final int ballInOver;
  final BallEventType eventType;
  final int runs;
  final int batsmanRuns;
  final int extraRuns;
  final bool isLegalDelivery;
  final bool isFreeHit;
  final String? strikerId;
  final String? nonStrikerId;
  final String? bowlerId;
  final WicketType? wicketType;
  final String? dismissedPlayerId;
  final String? fielderId;
  final String commentary;
  final DateTime? timestamp;
  final int sequence;
  final bool isHighlight;
  final String? highlightTag;
  final NoBallRunsMode? noBallRunsMode;
  /// Additional runs on a no-ball scored as byes (excludes NB penalty).
  final int noBallByeRuns;
  /// Additional runs on a no-ball scored as leg byes (excludes NB penalty).
  final int noBallLegByeRuns;
  final WagonWheelData? wagonWheel;

  factory BallEventModel.fromMap(String id, Map<String, dynamic> map) {
    return BallEventModel(
      id: id,
      matchId: map['matchId'] as String? ?? '',
      inningsNumber: map['inningsNumber'] as int? ?? 1,
      overNumber: map['overNumber'] as int? ?? 0,
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
      strikerId: map['strikerId'] as String?,
      nonStrikerId: map['nonStrikerId'] as String?,
      bowlerId: map['bowlerId'] as String?,
      wicketType: map['wicketType'] != null
          ? WicketType.values.firstWhere(
              (e) => e.name == map['wicketType'],
              orElse: () => WicketType.other,
            )
          : null,
      dismissedPlayerId: map['dismissedPlayerId'] as String?,
      fielderId: map['fielderId'] as String?,
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
    );
  }

  Map<String, dynamic> toMap() => {
        'matchId': matchId,
        'inningsNumber': inningsNumber,
        'overNumber': overNumber,
        'ballInOver': ballInOver,
        'eventType': eventType.name,
        'runs': runs,
        'batsmanRuns': batsmanRuns,
        'extraRuns': extraRuns,
        'isLegalDelivery': isLegalDelivery,
        'isFreeHit': isFreeHit,
        if (strikerId != null) 'strikerId': strikerId,
        if (nonStrikerId != null) 'nonStrikerId': nonStrikerId,
        if (bowlerId != null) 'bowlerId': bowlerId,
        if (wicketType != null) 'wicketType': wicketType!.name,
        if (dismissedPlayerId != null) 'dismissedPlayerId': dismissedPlayerId,
        if (fielderId != null) 'fielderId': fielderId,
        'commentary': commentary,
        'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
        'sequence': sequence,
        'isHighlight': isHighlight,
        if (highlightTag != null) 'highlightTag': highlightTag,
        if (noBallRunsMode != null) 'noBallRunsMode': noBallRunsMode!.name,
        if (noBallByeRuns > 0) 'noBallByeRuns': noBallByeRuns,
        if (noBallLegByeRuns > 0) 'noBallLegByeRuns': noBallLegByeRuns,
        if (wagonWheel != null) 'wagonWheel': wagonWheel!.toMap(),
      };

  @override
  List<Object?> get props => [id, matchId, sequence];
}
