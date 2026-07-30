import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'match_enums.dart';

class MatchScoreSnapshot extends Equatable {
  const MatchScoreSnapshot({
    this.battingTeamId,
    this.bowlingTeamId,
    this.runs = 0,
    this.wickets = 0,
    this.legalBalls = 0,
    this.currentOverNumber = 0,
    this.currentOverSegment = 1,
    this.targetRuns,
    this.partnershipRuns = 0,
    this.partnershipBalls = 0,
    this.strikerName,
    this.nonStrikerName,
    this.currentBowlerName,
    this.extras = 0,
    this.fours = 0,
    this.sixes = 0,
  });

  final String? battingTeamId;
  final String? bowlingTeamId;
  final int runs;
  final int wickets;
  final int legalBalls;
  final int currentOverNumber;
  final int currentOverSegment;
  final int? targetRuns;
  final int partnershipRuns;
  final int partnershipBalls;
  final String? strikerName;
  final String? nonStrikerName;
  final String? currentBowlerName;
  final int extras;
  final int fours;
  final int sixes;

  String get oversText => '${legalBalls ~/ 6}.${legalBalls % 6}';
  double get currentRunRate => legalBalls == 0 ? 0 : runs / (legalBalls / 6);
  int? get requiredRuns => targetRuns == null ? null : (targetRuns! - runs).clamp(0, 1000000);
  double? get requiredRunRate {
    if (targetRuns == null || legalBalls == 0) return null;
    return requiredRuns == null ? null : requiredRuns! / (legalBalls > 0 ? (legalBalls / 6) : 1);
  }

  @override
  List<Object?> get props => [runs, wickets, legalBalls, targetRuns];
}

class MatchCommentaryItem extends Equatable {
  const MatchCommentaryItem({required this.id, required this.text, required this.sequence, this.timestamp, this.overLabel});
  final String id;
  final String text;
  final int sequence;
  final DateTime? timestamp;
  final String? overLabel;
  @override
  List<Object?> get props => [id, sequence];
}

class MatchTimelineItem extends Equatable {
  const MatchTimelineItem({required this.id, required this.title, required this.occurredAt, this.subtitle = ''});
  final String id;
  final String title;
  final DateTime occurredAt;
  final String subtitle;
  @override
  List<Object?> get props => [id, occurredAt];
}

class ManagedMatch extends Equatable {
  const ManagedMatch({
    required this.id,
    required this.title,
    this.status = ManagedMatchStatus.draft,
    this.matchType = ManagedMatchType.friendly,
    this.cricketType,
    this.ballType,
    this.teamAId,
    this.teamBId,
    this.teamAName = '',
    this.teamBName = '',
    this.tournamentId,
    this.tournamentName,
    this.roundName,
    this.venue = '',
    this.country = '',
    this.stateProvince = '',
    this.city = '',
    this.placeName = '',
    this.scheduledAt,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.currentScorerId,
    this.currentScorerName = '',
    this.currentScorerPhoto,
    this.scorerIds = const [],
    this.streamingStatus = ManagedStreamStatus.idle,
    this.streamingPlatform = ManagedStreamPlatform.none,
    this.watchUrl,
    this.broadcastUrl,
    this.viewerCount = 0,
    this.lastHeartbeatAt,
    this.currentInnings = 0,
    this.currentInningsLabel = '?',
    this.live = const MatchScoreSnapshot(),
    this.resultSummary = '',
    this.tossWinner,
    this.tossDecision,
    this.organizationId,
    this.adminFeatured = false,
    this.adminPaused = false,
    this.recordStatus = AdminMatchRecordStatus.active,
    this.deletedAt,
    this.deletedBy,
  });

  final String id;
  final String title;
  final ManagedMatchStatus status;
  final ManagedMatchType matchType;
  final ManagedCricketType? cricketType;
  final ManagedBallType? ballType;
  final String? teamAId;
  final String? teamBId;
  final String teamAName;
  final String teamBName;
  final String? tournamentId;
  final String? tournamentName;
  final String? roundName;
  final String venue;
  final String country;
  final String stateProvince;
  final String city;
  final String placeName;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? currentScorerId;
  final String currentScorerName;
  final String? currentScorerPhoto;
  final List<String> scorerIds;
  final ManagedStreamStatus streamingStatus;
  final ManagedStreamPlatform streamingPlatform;
  final String? watchUrl;
  final String? broadcastUrl;
  final int viewerCount;
  final DateTime? lastHeartbeatAt;
  final int currentInnings;
  final String currentInningsLabel;
  final MatchScoreSnapshot live;
  final String resultSummary;
  final String? tossWinner;
  final String? tossDecision;
  final String? organizationId;
  final bool adminFeatured;
  final bool adminPaused;
  final AdminMatchRecordStatus recordStatus;
  final DateTime? deletedAt;
  final String? deletedBy;

  bool get isStreaming => streamingStatus == ManagedStreamStatus.live || streamingStatus == ManagedStreamStatus.connecting;
  bool get isSoftDeleted => recordStatus.isSoftDeleted;
  String get venueLabel {
    final parts = [if (venue.isNotEmpty) venue, if (placeName.isNotEmpty) placeName, if (city.isNotEmpty) city, if (stateProvince.isNotEmpty) stateProvince, if (country.isNotEmpty) country];
    return parts.isEmpty ? '?' : parts.join(', ');
  }

  String get scoreLine => '${live.runs}/${live.wickets}';
  String get teamsLabel => '${teamAName.isEmpty ? 'Team A' : teamAName} vs ${teamBName.isEmpty ? 'Team B' : teamBName}';

  factory ManagedMatch.fromFirestore({required String id, required Map<String, dynamic> map}) {
    final location = map['location'];
    final loc = location is Map ? Map<String, dynamic>.from(location) : const {};
    final rules = map['rules'];
    final rulesMap = rules is Map ? Map<String, dynamic>.from(rules) : const {};
    final setup = map['setup'];
    final setupMap = setup is Map ? Map<String, dynamic>.from(setup) : const {};
    final inningsList = List<Map<String, dynamic>>.from((map['innings'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
    final currentIndex = (map['currentInningsIndex'] as num?)?.toInt() ?? 0;
    final currentInningsMap = inningsList.isNotEmpty && currentIndex >= 0 && currentIndex < inningsList.length ? inningsList[currentIndex] : (inningsList.isNotEmpty ? inningsList.last : const <String, dynamic>{});
    final batsmen = List<Map<String, dynamic>>.from((currentInningsMap['batsmen'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
    final bowlers = List<Map<String, dynamic>>.from((currentInningsMap['bowlers'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
    Map<String, dynamic>? striker;
    Map<String, dynamic>? nonStriker;
    if (currentInningsMap['strikerId'] != null) {
      for (final b in batsmen) { if (b['playerId'] == currentInningsMap['strikerId']) { striker = b; break; } }
    }
    if (currentInningsMap['nonStrikerId'] != null) {
      for (final b in batsmen) { if (b['playerId'] == currentInningsMap['nonStrikerId']) { nonStriker = b; break; } }
    }
    Map<String, dynamic>? currentBowler;
    if (currentInningsMap['currentBowlerId'] != null) {
      for (final b in bowlers) { if (b['playerId'] == currentInningsMap['currentBowlerId']) { currentBowler = b; break; } }
    }
    var fours = 0; var sixes = 0;
    for (final b in batsmen) { fours += (b['fours'] as num?)?.toInt() ?? 0; sixes += (b['sixes'] as num?)?.toInt() ?? 0; }
    final stream = map['stream'];
    final streamMap = stream is Map ? Map<String, dynamic>.from(stream) : const {};
    final watchUrl = (streamMap['youtubeWatchUrl'] as String?)?.trim().isNotEmpty == true ? streamMap['youtubeWatchUrl'] as String : (streamMap['secondaryYoutubeWatchUrl'] as String?);
    final destination = streamMap['destination'] as String?;
    final title = (map['title'] as String?)?.trim().isNotEmpty == true ? (map['title'] as String).trim() : '${map['teamAName'] ?? 'Team A'} vs ${map['teamBName'] ?? 'Team B'}';
    final tossWinnerIsTeamA = setupMap['tossWinnerIsTeamA'] as bool?;
    final tossWinnerBatsFirst = setupMap['tossWinnerBatsFirst'] as bool?;
    return ManagedMatch(
      id: id,
      title: title,
      status: ManagedMatchStatus.parse((map['adminStatus'] as String?) ?? (map['status'] as String?)),
      matchType: ManagedMatchType.derive(matchType: (map['matchType'] as String?), roundName: map['roundName'] as String?),
      cricketType: ManagedCricketType.tryParse(rulesMap['cricketMatchType'] as String?),
      ballType: ManagedBallType.tryParse(rulesMap['ballType'] as String?),
      teamAId: map['teamAId'] as String?,
      teamBId: map['teamBId'] as String?,
      teamAName: map['teamAName'] as String? ?? '',
      teamBName: map['teamBName'] as String? ?? '',
      tournamentId: map['tournamentId'] as String?,
      tournamentName: map['tournamentName'] as String?,
      roundName: map['roundName'] as String?,
      venue: map['venue'] as String? ?? '',
      country: loc['country'] as String? ?? '',
      stateProvince: (loc['stateProvince'] as String?) ?? (loc['state'] as String?) ?? '',
      city: loc['city'] as String? ?? '',
      placeName: loc['placeName'] as String? ?? '',
      scheduledAt: _parseDate(map['scheduledAt']),
      startedAt: _parseDate(map['startedAt']),
      completedAt: _parseDate(map['completedAt']),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      createdBy: map['createdBy'] as String?,
      currentScorerId: map['currentScorerId'] as String?,
      currentScorerName: map['currentScorerName'] as String? ?? '',
      currentScorerPhoto: map['currentScorerPhoto'] as String?,
      scorerIds: List<String>.from(map['scorerIds'] as List? ?? const []),
      streamingStatus: ManagedStreamStatus.parse(streamMap['status'] as String?),
      streamingPlatform: ManagedStreamPlatform.parse(destination),
      watchUrl: watchUrl,
      broadcastUrl: streamMap['rtmpUrl'] as String?,
      viewerCount: (streamMap['viewerCount'] as num?)?.toInt() ?? 0,
      lastHeartbeatAt: _parseDate(streamMap['lastHeartbeatAt']),
      currentInnings: currentIndex + 1,
      currentInningsLabel: inningsList.isEmpty ? '?' : 'Innings ${currentIndex + 1}',
      live: MatchScoreSnapshot(
        battingTeamId: currentInningsMap['battingTeamId'] as String?,
        bowlingTeamId: currentInningsMap['bowlingTeamId'] as String?,
        runs: (currentInningsMap['totalRuns'] as num?)?.toInt() ?? 0,
        wickets: (currentInningsMap['totalWickets'] as num?)?.toInt() ?? 0,
        legalBalls: (currentInningsMap['legalBalls'] as num?)?.toInt() ?? 0,
        currentOverNumber: (currentInningsMap['currentOverNumber'] as num?)?.toInt() ?? 0,
        currentOverSegment: (currentInningsMap['currentOverSegment'] as num?)?.toInt() ?? 1,
        targetRuns: (currentInningsMap['targetRuns'] as num?)?.toInt(),
        partnershipRuns: (currentInningsMap['partnershipRuns'] as num?)?.toInt() ?? 0,
        partnershipBalls: (currentInningsMap['partnershipBalls'] as num?)?.toInt() ?? 0,
        strikerName: striker?['playerName'] as String?,
        nonStrikerName: nonStriker?['playerName'] as String?,
        currentBowlerName: currentBowler?['playerName'] as String?,
        extras: (currentInningsMap['extras'] as num?)?.toInt() ?? 0,
        fours: fours,
        sixes: sixes,
      ),
      resultSummary: map['resultSummary'] as String? ?? '',
      tossWinner: tossWinnerIsTeamA == null ? null : (tossWinnerIsTeamA ? (map['teamAName'] as String? ?? 'Team A') : (map['teamBName'] as String? ?? 'Team B')),
      tossDecision: tossWinnerBatsFirst == null ? null : (tossWinnerBatsFirst ? 'Bat first' : 'Bowl first'),
      organizationId: map['organizationId'] as String?,
      adminFeatured: map['adminFeatured'] as bool? ?? false,
      adminPaused: map['adminPaused'] as bool? ?? false,
      recordStatus: AdminMatchRecordStatus.parse(map['adminRecordStatus'] as String?),
      deletedAt: _parseDate(map['adminDeletedAt']),
      deletedBy: map['adminDeletedBy'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw > 9999999999 ? raw : raw * 1000);
    return null;
  }

  @override
  List<Object?> get props => [id, title, status, adminFeatured, adminPaused, recordStatus, updatedAt];
}

class MatchPageResult {
  const MatchPageResult({required this.matches, required this.hasMore, this.cursor});
  final List<ManagedMatch> matches;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
}

class MatchSummaryStats {
  const MatchSummaryStats({this.total = 0, this.live = 0, this.upcoming = 0, this.completed = 0, this.abandoned = 0, this.cancelled = 0, this.streamsRunning = 0});
  final int total;
  final int live;
  final int upcoming;
  final int completed;
  final int abandoned;
  final int cancelled;
  final int streamsRunning;
}
