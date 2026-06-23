import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';
import 'innings_model.dart';
import 'location_model.dart';
import 'match_rules_model.dart';
import 'match_break_model.dart';
import 'match_setup_draft_models.dart';
import 'match_target_state_model.dart';
import 'over_metadata_model.dart';
import 'over_note_model.dart';
import 'scorer_transfer_models.dart';

class MatchHeroModel extends Equatable {
  const MatchHeroModel({
    this.playerId,
    this.playerName = '',
    this.reason = '',
    this.badgeId,
  });

  final String? playerId;
  final String playerName;
  final String reason;
  final String? badgeId;

  factory MatchHeroModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MatchHeroModel();
    return MatchHeroModel(
      playerId: map['playerId'] as String?,
      playerName: map['playerName'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      badgeId: map['badgeId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        if (playerId != null) 'playerId': playerId,
        'playerName': playerName,
        'reason': reason,
        if (badgeId != null) 'badgeId': badgeId,
      };

  @override
  List<Object?> get props => [playerId, playerName];
}

class StreamMetadataModel extends Equatable {
  const StreamMetadataModel({
    this.status = StreamStatus.idle,
    this.destination = StreamDestination.youtube,
    this.rtmpUrl,
    this.streamKey,
    this.viewerCount = 0,
    this.startedAt,
    this.lastHeartbeatAt,
    this.youtubeWatchUrl,
    this.secondaryYoutubeWatchUrl,
    this.cameraALabel = 'Main camera',
    this.cameraBLabel = 'Camera 2',
    this.webrtcEnabled = false,
  });

  final StreamStatus status;
  final StreamDestination destination;
  final String? rtmpUrl;
  final String? streamKey;
  final int viewerCount;
  final DateTime? startedAt;
  final DateTime? lastHeartbeatAt;
  /// Public YouTube watch URL for in-app embed (from Studio after going live).
  final String? youtubeWatchUrl;
  /// Second angle (drone / stump cam) — separate YouTube live link.
  final String? secondaryYoutubeWatchUrl;
  final String cameraALabel;
  final String cameraBLabel;
  /// Experimental low-latency WebRTC room (Phase 3.3).
  final bool webrtcEnabled;

  factory StreamMetadataModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const StreamMetadataModel();
    return StreamMetadataModel(
      status: StreamStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => StreamStatus.idle,
      ),
      destination: StreamDestination.values.firstWhere(
        (e) => e.name == map['destination'],
        orElse: () => StreamDestination.youtube,
      ),
      rtmpUrl: map['rtmpUrl'] as String?,
      streamKey: map['streamKey'] as String?,
      viewerCount: map['viewerCount'] as int? ?? 0,
      startedAt: DateTime.tryParse(map['startedAt']?.toString() ?? ''),
      lastHeartbeatAt:
          DateTime.tryParse(map['lastHeartbeatAt']?.toString() ?? ''),
      youtubeWatchUrl: map['youtubeWatchUrl'] as String?,
      secondaryYoutubeWatchUrl: map['secondaryYoutubeWatchUrl'] as String?,
      cameraALabel: map['cameraALabel'] as String? ?? 'Main camera',
      cameraBLabel: map['cameraBLabel'] as String? ?? 'Camera 2',
      webrtcEnabled: map['webrtcEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'destination': destination.name,
        if (rtmpUrl != null) 'rtmpUrl': rtmpUrl,
        if (streamKey != null) 'streamKey': streamKey,
        'viewerCount': viewerCount,
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
        if (lastHeartbeatAt != null)
          'lastHeartbeatAt': lastHeartbeatAt!.toIso8601String(),
        if (youtubeWatchUrl != null) 'youtubeWatchUrl': youtubeWatchUrl,
        if (secondaryYoutubeWatchUrl != null)
          'secondaryYoutubeWatchUrl': secondaryYoutubeWatchUrl,
        'cameraALabel': cameraALabel,
        'cameraBLabel': cameraBLabel,
        'webrtcEnabled': webrtcEnabled,
      };

  StreamMetadataModel copyWith({
    StreamStatus? status,
    StreamDestination? destination,
    String? rtmpUrl,
    String? streamKey,
    int? viewerCount,
    DateTime? startedAt,
    DateTime? lastHeartbeatAt,
    String? youtubeWatchUrl,
    String? secondaryYoutubeWatchUrl,
    String? cameraALabel,
    String? cameraBLabel,
    bool? webrtcEnabled,
  }) {
    return StreamMetadataModel(
      status: status ?? this.status,
      destination: destination ?? this.destination,
      rtmpUrl: rtmpUrl ?? this.rtmpUrl,
      streamKey: streamKey ?? this.streamKey,
      viewerCount: viewerCount ?? this.viewerCount,
      startedAt: startedAt ?? this.startedAt,
      lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
      youtubeWatchUrl: youtubeWatchUrl ?? this.youtubeWatchUrl,
      secondaryYoutubeWatchUrl:
          secondaryYoutubeWatchUrl ?? this.secondaryYoutubeWatchUrl,
      cameraALabel: cameraALabel ?? this.cameraALabel,
      cameraBLabel: cameraBLabel ?? this.cameraBLabel,
      webrtcEnabled: webrtcEnabled ?? this.webrtcEnabled,
    );
  }

  @override
  List<Object?> get props => [status, rtmpUrl, lastHeartbeatAt, webrtcEnabled];
}

class MatchModel extends Equatable {
  const MatchModel({
    required this.id,
    required this.title,
    this.matchType = MatchType.single,
    this.status = MatchStatus.draft,
    this.teamAId,
    this.teamBId,
    this.teamAName = '',
    this.teamBName = '',
    this.tournamentId,
    this.roundId,
    this.groupId,
    this.roundName,
    this.bracketRound,
    this.bracketSlot,
    this.rules = const MatchRulesModel(),
    this.innings = const [],
    this.currentInningsIndex = 0,
    this.location = const LocationModel(),
    this.venue = '',
    this.scheduledAt,
    this.startedAt,
    this.completedAt,
    this.createdBy,
    this.scorerIds = const [],
    this.scorer1UserId,
    this.scorer2UserId,
    this.currentScorerId,
    this.currentScorerName = '',
    this.currentScorerPhoto,
    this.scorerOwnershipToken,
    this.lastScorerTransferAt,
    this.scorerTransferHistory = const [],
    this.winnerTeamId,
    this.resultSummary = '',
    this.matchHero,
    this.playerOfMatchId,
    this.badgeIds = const [],
    this.stream = const StreamMetadataModel(),
    this.overlayVersion = 0,
    this.mediaByCode = const {},
    this.createdAt,
    this.setup,
    this.overNotes = const [],
    this.overMetadata = const [],
    this.targetState = const MatchTargetStateModel(),
    this.activeMatchBreak,
    this.matchBreakHistory = const [],
    this.publicMatchId,
  });

  final String id;
  final String title;
  final MatchType matchType;
  final MatchStatus status;
  final String? teamAId;
  final String? teamBId;
  final String teamAName;
  final String teamBName;
  final String? tournamentId;
  final String? roundId;
  final String? groupId;
  final String? roundName;
  final int? bracketRound;
  final int? bracketSlot;
  final MatchRulesModel rules;
  final List<InningsModel> innings;
  final int currentInningsIndex;
  final LocationModel location;
  final String venue;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? createdBy;
  final List<String> scorerIds;
  final String? scorer1UserId;
  final String? scorer2UserId;
  final String? currentScorerId;
  final String currentScorerName;
  final String? currentScorerPhoto;
  final String? scorerOwnershipToken;
  final DateTime? lastScorerTransferAt;
  final List<ScorerTransferRecord> scorerTransferHistory;
  final String? winnerTeamId;
  final String resultSummary;
  final MatchHeroModel? matchHero;
  final String? playerOfMatchId;
  final List<String> badgeIds;
  final StreamMetadataModel stream;
  final int overlayVersion;
  /// Match photos/videos keyed by code (CM1, CM2, …).
  final Map<String, String> mediaByCode;
  final DateTime? createdAt;
  /// Squad, roles, officials, and toss captured at match start.
  final MatchSetupData? setup;
  final List<OverNoteModel> overNotes;
  final List<OverMetadataModel> overMetadata;
  final MatchTargetStateModel targetState;
  final ActiveMatchBreakModel? activeMatchBreak;
  final List<MatchBreakHistoryEntry> matchBreakHistory;
  /// Short numeric id assigned when scoring starts (shown in Info tab).
  final String? publicMatchId;

  bool get isMatchBreakActive =>
      activeMatchBreak != null && activeMatchBreak!.isActive;

  InningsModel? get currentInnings =>
      innings.isNotEmpty && currentInningsIndex < innings.length
          ? innings[currentInningsIndex]
          : null;

  factory MatchModel.fromMap(String id, Map<String, dynamic> map) {
    return MatchModel(
      id: id,
      title: map['title'] as String? ?? 'Match',
      matchType: MatchType.values.firstWhere(
        (e) => e.name == map['matchType'],
        orElse: () => MatchType.single,
      ),
      status: MatchStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MatchStatus.draft,
      ),
      teamAId: map['teamAId'] as String?,
      teamBId: map['teamBId'] as String?,
      teamAName: map['teamAName'] as String? ?? '',
      teamBName: map['teamBName'] as String? ?? '',
      tournamentId: map['tournamentId'] as String?,
      roundId: map['roundId'] as String?,
      groupId: map['groupId'] as String?,
      roundName: map['roundName'] as String?,
      bracketRound: map['bracketRound'] as int?,
      bracketSlot: map['bracketSlot'] as int?,
      rules: MatchRulesModel.fromMap(_asStringMap(map['rules'])),
      innings: (map['innings'] as List? ?? [])
          .map((e) => InningsModel.fromMap(_asStringMap(e)!))
          .toList(),
      currentInningsIndex: map['currentInningsIndex'] as int? ?? 0,
      location: LocationModel.fromMap(_asStringMap(map['location'])),
      venue: map['venue'] as String? ?? '',
      scheduledAt: DateTime.tryParse(map['scheduledAt']?.toString() ?? ''),
      startedAt: DateTime.tryParse(map['startedAt']?.toString() ?? ''),
      completedAt: DateTime.tryParse(map['completedAt']?.toString() ?? ''),
      createdBy: map['createdBy'] as String?,
      scorerIds: List<String>.from(map['scorerIds'] as List? ?? []),
      scorer1UserId: map['scorer1UserId'] as String?,
      scorer2UserId: map['scorer2UserId'] as String?,
      currentScorerId: map['currentScorerId'] as String?,
      currentScorerName: map['currentScorerName'] as String? ?? '',
      currentScorerPhoto: map['currentScorerPhoto'] as String?,
      scorerOwnershipToken: map['scorerOwnershipToken'] as String?,
      lastScorerTransferAt:
          DateTime.tryParse(map['lastScorerTransferAt']?.toString() ?? ''),
      scorerTransferHistory: (map['scorerTransferHistory'] as List? ?? [])
          .map((e) => ScorerTransferRecord.fromMap(
                _asStringMap(e) ?? const {},
              ))
          .toList(),
      winnerTeamId: map['winnerTeamId'] as String?,
      resultSummary: map['resultSummary'] as String? ?? '',
      matchHero: _asStringMap(map['matchHero']) != null
          ? MatchHeroModel.fromMap(_asStringMap(map['matchHero']))
          : null,
      playerOfMatchId: map['playerOfMatchId'] as String?,
      badgeIds: List<String>.from(map['badgeIds'] as List? ?? []),
      stream: StreamMetadataModel.fromMap(_asStringMap(map['stream'])),
      overlayVersion: map['overlayVersion'] as int? ?? 0,
      mediaByCode: _mediaByCodeFromMap(_asStringMap(map['mediaByCode'])),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      setup: MatchSetupData.fromMap(map),
      overNotes: (map['overNotes'] as List? ?? [])
          .map((e) => OverNoteModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      overMetadata: (map['overMetadata'] as List? ?? [])
          .map((e) => OverMetadataModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      targetState: MatchTargetStateModel.fromMap(_asStringMap(map['targetState'])),
      activeMatchBreak: map['activeMatchBreak'] != null
          ? ActiveMatchBreakModel.fromMap(
              _asStringMap(map['activeMatchBreak']),
            )
          : null,
      matchBreakHistory: (map['matchBreakHistory'] as List? ?? [])
          .map(
            (e) => MatchBreakHistoryEntry.fromMap(
              _asStringMap(e) ?? const {},
            ),
          )
          .toList(),
      publicMatchId: map['publicMatchId'] as String?,
    );
  }

  static Map<String, dynamic>? _asStringMap(Object? value) {
    if (value is! Map) return null;
    return value.map((k, v) => MapEntry(k.toString(), v));
  }

  static Map<String, String> _mediaByCodeFromMap(Map<String, dynamic>? map) {
    if (map == null) return {};
    return map.map((k, v) => MapEntry(k, v.toString()));
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'matchType': matchType.name,
        'status': status.name,
        if (teamAId != null) 'teamAId': teamAId,
        if (teamBId != null) 'teamBId': teamBId,
        'teamAName': teamAName,
        'teamBName': teamBName,
        if (tournamentId != null) 'tournamentId': tournamentId,
        if (roundId != null) 'roundId': roundId,
        if (groupId != null) 'groupId': groupId,
        if (roundName != null && roundName!.isNotEmpty) 'roundName': roundName,
        if (bracketRound != null) 'bracketRound': bracketRound,
        if (bracketSlot != null) 'bracketSlot': bracketSlot,
        'rules': rules.toMap(),
        'innings': innings.map((i) => i.toMap()).toList(),
        'currentInningsIndex': currentInningsIndex,
        'location': location.toMap(),
        'venue': venue,
        if (scheduledAt != null) 'scheduledAt': scheduledAt!.toIso8601String(),
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (createdBy != null) 'createdBy': createdBy,
        'scorerIds': scorerIds,
        if (currentScorerId != null) 'currentScorerId': currentScorerId,
        if (currentScorerName.isNotEmpty) 'currentScorerName': currentScorerName,
        if (currentScorerPhoto != null) 'currentScorerPhoto': currentScorerPhoto,
        if (scorerOwnershipToken != null)
          'scorerOwnershipToken': scorerOwnershipToken,
        if (lastScorerTransferAt != null)
          'lastScorerTransferAt': lastScorerTransferAt!.toIso8601String(),
        if (scorerTransferHistory.isNotEmpty)
          'scorerTransferHistory':
              scorerTransferHistory.map((e) => e.toMap()).toList(),
        if (winnerTeamId != null) 'winnerTeamId': winnerTeamId,
        'resultSummary': resultSummary,
        if (matchHero != null) 'matchHero': matchHero!.toMap(),
        if (playerOfMatchId != null) 'playerOfMatchId': playerOfMatchId,
        'badgeIds': badgeIds,
        'stream': stream.toMap(),
        'overlayVersion': overlayVersion,
        if (mediaByCode.isNotEmpty) 'mediaByCode': mediaByCode,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        if (setup != null) ...setup!.toMap(),
        if (overNotes.isNotEmpty)
          'overNotes': overNotes.map((n) => n.toMap()).toList(),
        if (overMetadata.isNotEmpty)
          'overMetadata': overMetadata.map((m) => m.toMap()).toList(),
        if (targetState != const MatchTargetStateModel())
          'targetState': targetState.toMap(),
        if (activeMatchBreak != null)
          'activeMatchBreak': activeMatchBreak!.toMap(),
        if (matchBreakHistory.isNotEmpty)
          'matchBreakHistory':
              matchBreakHistory.map((e) => e.toMap()).toList(),
        if (publicMatchId != null && publicMatchId!.isNotEmpty)
          'publicMatchId': publicMatchId,
      };

  MatchModel copyWith({
    String? title,
    MatchStatus? status,
    String? teamAId,
    String? teamBId,
    String? teamAName,
    String? teamBName,
    MatchRulesModel? rules,
    List<InningsModel>? innings,
    int? currentInningsIndex,
    LocationModel? location,
    String? venue,
    DateTime? startedAt,
    DateTime? completedAt,
    String? winnerTeamId,
    String? resultSummary,
    MatchHeroModel? matchHero,
    String? playerOfMatchId,
    List<String>? badgeIds,
    StreamMetadataModel? stream,
    int? overlayVersion,
    Map<String, String>? mediaByCode,
    String? currentScorerId,
    String? currentScorerName,
    String? currentScorerPhoto,
    String? scorerOwnershipToken,
    DateTime? lastScorerTransferAt,
    List<ScorerTransferRecord>? scorerTransferHistory,
    MatchSetupData? setup,
    List<OverNoteModel>? overNotes,
    List<OverMetadataModel>? overMetadata,
    MatchTargetStateModel? targetState,
    ActiveMatchBreakModel? activeMatchBreak,
    bool clearActiveMatchBreak = false,
    List<MatchBreakHistoryEntry>? matchBreakHistory,
    String? publicMatchId,
  }) {
    return MatchModel(
      id: id,
      title: title ?? this.title,
      matchType: matchType,
      status: status ?? this.status,
      teamAId: teamAId ?? this.teamAId,
      teamBId: teamBId ?? this.teamBId,
      teamAName: teamAName ?? this.teamAName,
      teamBName: teamBName ?? this.teamBName,
      tournamentId: tournamentId,
      roundId: roundId,
      groupId: groupId,
      roundName: roundName,
      bracketRound: bracketRound,
      bracketSlot: bracketSlot,
      rules: rules ?? this.rules,
      innings: innings ?? this.innings,
      currentInningsIndex: currentInningsIndex ?? this.currentInningsIndex,
      location: location ?? this.location,
      venue: venue ?? this.venue,
      scheduledAt: scheduledAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdBy: createdBy,
      scorerIds: scorerIds,
      currentScorerId: currentScorerId ?? this.currentScorerId,
      currentScorerName: currentScorerName ?? this.currentScorerName,
      currentScorerPhoto: currentScorerPhoto ?? this.currentScorerPhoto,
      scorerOwnershipToken: scorerOwnershipToken ?? this.scorerOwnershipToken,
      lastScorerTransferAt: lastScorerTransferAt ?? this.lastScorerTransferAt,
      scorerTransferHistory:
          scorerTransferHistory ?? this.scorerTransferHistory,
      winnerTeamId: winnerTeamId ?? this.winnerTeamId,
      resultSummary: resultSummary ?? this.resultSummary,
      matchHero: matchHero ?? this.matchHero,
      playerOfMatchId: playerOfMatchId ?? this.playerOfMatchId,
      badgeIds: badgeIds ?? this.badgeIds,
      stream: stream ?? this.stream,
      overlayVersion: overlayVersion ?? this.overlayVersion,
      mediaByCode: mediaByCode ?? this.mediaByCode,
      createdAt: createdAt,
      setup: setup ?? this.setup,
      overNotes: overNotes ?? this.overNotes,
      overMetadata: overMetadata ?? this.overMetadata,
      targetState: targetState ?? this.targetState,
      activeMatchBreak: clearActiveMatchBreak
          ? null
          : (activeMatchBreak ?? this.activeMatchBreak),
      matchBreakHistory: matchBreakHistory ?? this.matchBreakHistory,
      publicMatchId: publicMatchId ?? this.publicMatchId,
    );
  }

  @override
  List<Object?> get props => [id, status, title];
}
