import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';
import 'innings_model.dart';
import 'location_model.dart';
import 'match_rules_model.dart';

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
    this.winnerTeamId,
    this.resultSummary = '',
    this.matchHero,
    this.playerOfMatchId,
    this.badgeIds = const [],
    this.stream = const StreamMetadataModel(),
    this.overlayVersion = 0,
    this.createdAt,
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
  final String? winnerTeamId;
  final String resultSummary;
  final MatchHeroModel? matchHero;
  final String? playerOfMatchId;
  final List<String> badgeIds;
  final StreamMetadataModel stream;
  final int overlayVersion;
  final DateTime? createdAt;

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
      bracketRound: map['bracketRound'] as int?,
      bracketSlot: map['bracketSlot'] as int?,
      rules: MatchRulesModel.fromMap(map['rules'] as Map<String, dynamic>?),
      innings: (map['innings'] as List? ?? [])
          .map((e) => InningsModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      currentInningsIndex: map['currentInningsIndex'] as int? ?? 0,
      location: LocationModel.fromMap(map['location'] as Map<String, dynamic>?),
      venue: map['venue'] as String? ?? '',
      scheduledAt: DateTime.tryParse(map['scheduledAt']?.toString() ?? ''),
      startedAt: DateTime.tryParse(map['startedAt']?.toString() ?? ''),
      completedAt: DateTime.tryParse(map['completedAt']?.toString() ?? ''),
      createdBy: map['createdBy'] as String?,
      scorerIds: List<String>.from(map['scorerIds'] as List? ?? []),
      winnerTeamId: map['winnerTeamId'] as String?,
      resultSummary: map['resultSummary'] as String? ?? '',
      matchHero: map['matchHero'] != null
          ? MatchHeroModel.fromMap(map['matchHero'] as Map<String, dynamic>)
          : null,
      playerOfMatchId: map['playerOfMatchId'] as String?,
      badgeIds: List<String>.from(map['badgeIds'] as List? ?? []),
      stream: StreamMetadataModel.fromMap(
        map['stream'] as Map<String, dynamic>?,
      ),
      overlayVersion: map['overlayVersion'] as int? ?? 0,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
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
        if (winnerTeamId != null) 'winnerTeamId': winnerTeamId,
        'resultSummary': resultSummary,
        if (matchHero != null) 'matchHero': matchHero!.toMap(),
        if (playerOfMatchId != null) 'playerOfMatchId': playerOfMatchId,
        'badgeIds': badgeIds,
        'stream': stream.toMap(),
        'overlayVersion': overlayVersion,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
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
      winnerTeamId: winnerTeamId ?? this.winnerTeamId,
      resultSummary: resultSummary ?? this.resultSummary,
      matchHero: matchHero ?? this.matchHero,
      playerOfMatchId: playerOfMatchId ?? this.playerOfMatchId,
      badgeIds: badgeIds ?? this.badgeIds,
      stream: stream ?? this.stream,
      overlayVersion: overlayVersion ?? this.overlayVersion,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, status, title];
}
