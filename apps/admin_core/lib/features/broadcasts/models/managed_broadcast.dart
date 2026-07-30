import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../matches/models/match_enums.dart';
import '../../matches/models/managed_match.dart';
import 'broadcast_enums.dart';

/// Admin broadcast monitor row — derived from `matches/{id}.stream`.
///
/// Never exposes [streamKey], OAuth tokens, or raw ingest credentials.
class ManagedBroadcast extends Equatable {
  const ManagedBroadcast({
    required this.id,
    required this.matchTitle,
    this.matchStatus = ManagedMatchStatus.draft,
    this.teamAName = '',
    this.teamBName = '',
    this.tournamentId,
    this.tournamentName,
    this.organizerId,
    this.organizerName = '',
    this.scorerId,
    this.scorerName = '',
    this.platform = ManagedStreamPlatform.none,
    this.streamStatus = ManagedStreamStatus.idle,
    this.watchUrl,
    this.secondaryWatchUrl,
    this.hasStreamKey = false,
    this.hasRtmpUrl = false,
    this.maskedStreamKey = '••••••••',
    this.rtmpHostMasked = '',
    this.viewerCount = 0,
    this.orientation = '',
    this.webrtcEnabled = false,
    this.cameraALabel = '',
    this.cameraBLabel = '',
    this.streamStartedAt,
    this.lastHeartbeatAt,
    this.endedAt,
    this.matchStartedAt,
    this.scheduledAt,
    this.createdAt,
    this.updatedAt,
    this.country = '',
    this.stateProvince = '',
    this.city = '',
    this.venue = '',
    this.live = const MatchScoreSnapshot(),
    this.currentInningsLabel = '?',
    this.adminFeatured = false,
    this.recordStatus = AdminMatchRecordStatus.active,
    this.organizationId,
    this.deletedAt,
    this.deletedBy,
    this.playbackCount = 0,
    this.youtubeVideoId,
  });

  final String id;
  final String matchTitle;
  final ManagedMatchStatus matchStatus;
  final String teamAName;
  final String teamBName;
  final String? tournamentId;
  final String? tournamentName;
  final String? organizerId;
  final String organizerName;
  final String? scorerId;
  final String scorerName;
  final ManagedStreamPlatform platform;
  final ManagedStreamStatus streamStatus;
  final String? watchUrl;
  final String? secondaryWatchUrl;
  final bool hasStreamKey;
  final bool hasRtmpUrl;
  final String maskedStreamKey;
  final String rtmpHostMasked;
  final int viewerCount;
  final String orientation;
  final bool webrtcEnabled;
  final String cameraALabel;
  final String cameraBLabel;
  final DateTime? streamStartedAt;
  final DateTime? lastHeartbeatAt;
  final DateTime? endedAt;
  final DateTime? matchStartedAt;
  final DateTime? scheduledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String country;
  final String stateProvince;
  final String city;
  final String venue;
  final MatchScoreSnapshot live;
  final String currentInningsLabel;
  final bool adminFeatured;
  final AdminMatchRecordStatus recordStatus;
  final String? organizationId;
  final DateTime? deletedAt;
  final String? deletedBy;
  final int playbackCount;
  final String? youtubeVideoId;

  bool get isSoftDeleted => recordStatus.isSoftDeleted;
  bool get isLive =>
      streamStatus == ManagedStreamStatus.live ||
      streamStatus == ManagedStreamStatus.connecting;

  String get teamsLabel =>
      '${teamAName.isEmpty ? 'Team A' : teamAName} vs ${teamBName.isEmpty ? 'Team B' : teamBName}';

  String get locationLabel {
    final parts = [
      if (city.isNotEmpty) city,
      if (stateProvince.isNotEmpty) stateProvince,
      if (country.isNotEmpty) country,
    ];
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  Duration? get duration {
    final start = streamStartedAt;
    if (start == null) return null;
    final end = endedAt ??
        (streamStatus == ManagedStreamStatus.live ||
                streamStatus == ManagedStreamStatus.connecting
            ? DateTime.now()
            : lastHeartbeatAt);
    if (end == null) return null;
    if (end.isBefore(start)) return Duration.zero;
    return end.difference(start);
  }

  String get durationLabel {
    final d = duration;
    if (d == null) return '—';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  ManagedBroadcastStatus get displayStatus {
    if (matchStatus == ManagedMatchStatus.cancelled) {
      return ManagedBroadcastStatus.cancelled;
    }
    switch (streamStatus) {
      case ManagedStreamStatus.connecting:
        return ManagedBroadcastStatus.connecting;
      case ManagedStreamStatus.live:
        if (_heartbeatStale) return ManagedBroadcastStatus.reconnecting;
        return ManagedBroadcastStatus.live;
      case ManagedStreamStatus.ended:
        return ManagedBroadcastStatus.completed;
      case ManagedStreamStatus.error:
        return ManagedBroadcastStatus.failed;
      case ManagedStreamStatus.idle:
        if (streamStartedAt != null || hasStreamKey || watchUrl != null) {
          return ManagedBroadcastStatus.waiting;
        }
        if (scheduledAt != null && scheduledAt!.isAfter(DateTime.now())) {
          return ManagedBroadcastStatus.scheduled;
        }
        return ManagedBroadcastStatus.idle;
    }
  }

  ManagedBroadcastHealth get health {
    switch (streamStatus) {
      case ManagedStreamStatus.live:
        if (_heartbeatStale) return ManagedBroadcastHealth.poor;
        return ManagedBroadcastHealth.healthy;
      case ManagedStreamStatus.connecting:
        return ManagedBroadcastHealth.poor;
      case ManagedStreamStatus.error:
        return ManagedBroadcastHealth.offline;
      case ManagedStreamStatus.ended:
        return ManagedBroadcastHealth.unknown;
      case ManagedStreamStatus.idle:
        return ManagedBroadcastHealth.unknown;
    }
  }

  ManagedBroadcastVisibility get visibility =>
      ManagedBroadcastVisibility.unknown;

  bool get _heartbeatStale {
    final hb = lastHeartbeatAt;
    if (hb == null) return true;
    return DateTime.now().difference(hb) > const Duration(seconds: 90);
  }

  bool get hasBroadcastActivity {
    if (streamStatus != ManagedStreamStatus.idle) return true;
    if (streamStartedAt != null) return true;
    if (watchUrl != null && watchUrl!.isNotEmpty) return true;
    if (hasStreamKey || hasRtmpUrl) return true;
    if (playbackCount > 0) return true;
    return false;
  }

  factory ManagedBroadcast.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final location = map['location'];
    final loc =
        location is Map ? Map<String, dynamic>.from(location) : const {};
    final stream = map['stream'];
    final streamMap =
        stream is Map ? Map<String, dynamic>.from(stream) : const {};

    final watch = (streamMap['youtubeWatchUrl'] as String?)?.trim();
    final secondary =
        (streamMap['secondaryYoutubeWatchUrl'] as String?)?.trim();
    final keyRaw = (streamMap['streamKey'] as String?)?.trim() ?? '';
    final rtmpRaw = (streamMap['rtmpUrl'] as String?)?.trim() ?? '';
    final playback =
        List<dynamic>.from(streamMap['playbackEntries'] as List? ?? const []);

    final title = (map['title'] as String?)?.trim().isNotEmpty == true
        ? (map['title'] as String).trim()
        : '${map['teamAName'] ?? 'Team A'} vs ${map['teamBName'] ?? 'Team B'}';

    final inningsList = List<Map<String, dynamic>>.from(
      (map['innings'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e)),
    );
    final currentIndex = (map['currentInningsIndex'] as num?)?.toInt() ?? 0;
    final currentInningsMap = inningsList.isNotEmpty &&
            currentIndex >= 0 &&
            currentIndex < inningsList.length
        ? inningsList[currentIndex]
        : (inningsList.isNotEmpty
            ? inningsList.last
            : const <String, dynamic>{});
    final batsmen = List<Map<String, dynamic>>.from(
      (currentInningsMap['batsmen'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e)),
    );
    final bowlers = List<Map<String, dynamic>>.from(
      (currentInningsMap['bowlers'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e)),
    );
    Map<String, dynamic>? striker;
    Map<String, dynamic>? nonStriker;
    Map<String, dynamic>? currentBowler;
    if (currentInningsMap['strikerId'] != null) {
      for (final b in batsmen) {
        if (b['playerId'] == currentInningsMap['strikerId']) {
          striker = b;
          break;
        }
      }
    }
    if (currentInningsMap['nonStrikerId'] != null) {
      for (final b in batsmen) {
        if (b['playerId'] == currentInningsMap['nonStrikerId']) {
          nonStriker = b;
          break;
        }
      }
    }
    if (currentInningsMap['currentBowlerId'] != null) {
      for (final b in bowlers) {
        if (b['playerId'] == currentInningsMap['currentBowlerId']) {
          currentBowler = b;
          break;
        }
      }
    }

    return ManagedBroadcast(
      id: id,
      matchTitle: title,
      matchStatus: ManagedMatchStatus.parse(
        (map['adminStatus'] as String?) ?? (map['status'] as String?),
      ),
      teamAName: map['teamAName'] as String? ?? '',
      teamBName: map['teamBName'] as String? ?? '',
      tournamentId: map['tournamentId'] as String?,
      tournamentName: map['tournamentName'] as String?,
      organizerId: map['createdBy'] as String?,
      organizerName: map['createdByName'] as String? ?? '',
      scorerId: map['currentScorerId'] as String?,
      scorerName: map['currentScorerName'] as String? ?? '',
      platform: ManagedStreamPlatform.parse(
        streamMap['destination'] as String?,
      ),
      streamStatus: ManagedStreamStatus.parse(streamMap['status'] as String?),
      watchUrl: (watch != null && watch.isNotEmpty) ? watch : null,
      secondaryWatchUrl:
          (secondary != null && secondary.isNotEmpty) ? secondary : null,
      hasStreamKey: keyRaw.isNotEmpty,
      hasRtmpUrl: rtmpRaw.isNotEmpty,
      maskedStreamKey: keyRaw.isEmpty ? '—' : '••••••••',
      rtmpHostMasked: _maskRtmpHost(rtmpRaw),
      viewerCount: (streamMap['viewerCount'] as num?)?.toInt() ?? 0,
      orientation: streamMap['broadcastOrientation'] as String? ?? '',
      webrtcEnabled: streamMap['webrtcEnabled'] as bool? ?? false,
      cameraALabel: streamMap['cameraALabel'] as String? ?? '',
      cameraBLabel: streamMap['cameraBLabel'] as String? ?? '',
      streamStartedAt: _parseDate(streamMap['startedAt']),
      lastHeartbeatAt: _parseDate(streamMap['lastHeartbeatAt']),
      endedAt: _parseDate(streamMap['endedAt']),
      matchStartedAt: _parseDate(map['startedAt']),
      scheduledAt: _parseDate(map['scheduledAt']),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      country: loc['country'] as String? ?? '',
      stateProvince: (loc['stateProvince'] as String?) ??
          (loc['state'] as String?) ??
          '',
      city: loc['city'] as String? ?? '',
      venue: map['venue'] as String? ?? '',
      live: MatchScoreSnapshot(
        battingTeamId: currentInningsMap['battingTeamId'] as String?,
        bowlingTeamId: currentInningsMap['bowlingTeamId'] as String?,
        runs: (currentInningsMap['totalRuns'] as num?)?.toInt() ?? 0,
        wickets: (currentInningsMap['totalWickets'] as num?)?.toInt() ?? 0,
        legalBalls: (currentInningsMap['legalBalls'] as num?)?.toInt() ?? 0,
        currentOverNumber:
            (currentInningsMap['currentOverNumber'] as num?)?.toInt() ?? 0,
        strikerName: striker?['name'] as String?,
        nonStrikerName: nonStriker?['name'] as String?,
        currentBowlerName: currentBowler?['name'] as String?,
      ),
      currentInningsLabel:
          inningsList.isEmpty ? '?' : 'Innings ${currentIndex + 1}',
      adminFeatured: map['adminFeatured'] as bool? ?? false,
      recordStatus: AdminMatchRecordStatus.parse(
        map['adminRecordStatus'] as String?,
      ),
      organizationId: map['organizationId'] as String?,
      deletedAt: _parseDate(map['adminDeletedAt']),
      deletedBy: map['adminDeletedBy'] as String?,
      playbackCount: playback.length,
      youtubeVideoId: _extractYoutubeId(watch ?? secondary),
    );
  }

  static String _maskRtmpHost(String rtmpUrl) {
    if (rtmpUrl.isEmpty) return '';
    try {
      final uri = Uri.parse(rtmpUrl);
      final host = uri.host;
      if (host.isEmpty) return 'rtmp://••••';
      return '${uri.scheme}://$host/••••';
    } catch (_) {
      return 'rtmp://••••';
    }
  }

  static String? _extractYoutubeId(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    return uri.queryParameters['v'];
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        raw > 9999999999 ? raw : raw * 1000,
      );
    }
    return null;
  }

  @override
  List<Object?> get props =>
      [id, streamStatus, lastHeartbeatAt, adminFeatured, recordStatus];
}

class BroadcastPageResult {
  const BroadcastPageResult({
    required this.broadcasts,
    required this.hasMore,
    this.cursor,
  });

  final List<ManagedBroadcast> broadcasts;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
}

class BroadcastSummaryStats {
  const BroadcastSummaryStats({
    this.total = 0,
    this.live = 0,
    this.scheduled = 0,
    this.completed = 0,
    this.failed = 0,
    this.youtube = 0,
    this.facebook = 0,
    this.externalRtmp = 0,
  });

  final int total;
  final int live;
  final int scheduled;
  final int completed;
  final int failed;
  final int youtube;
  final int facebook;
  final int externalRtmp;
}

class BroadcastTimelineItem extends Equatable {
  const BroadcastTimelineItem({
    required this.id,
    required this.title,
    required this.occurredAt,
    this.subtitle = '',
  });

  final String id;
  final String title;
  final DateTime occurredAt;
  final String subtitle;

  @override
  List<Object?> get props => [id, occurredAt];
}
