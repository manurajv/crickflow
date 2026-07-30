import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'team_enums.dart';

/// Admin view of Firestore `teams/{id}` — mobile fields + additive admin meta.
class ManagedTeam extends Equatable {
  const ManagedTeam({
    required this.id,
    required this.name,
    this.teamCode,
    this.logoUrl,
    this.coverUrl,
    this.captainId,
    this.viceCaptainId,
    this.coachName = '',
    this.contactNumber = '',
    this.createdBy,
    this.playerIds = const [],
    this.memberCount = 0,
    this.followersCount = 0,
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.matchesLost = 0,
    this.matchesTied = 0,
    this.totalRunsScored = 0,
    this.totalWicketsTaken = 0,
    this.country = '',
    this.stateProvince = '',
    this.city = '',
    this.placeName = '',
    this.badgeIds = const [],
    this.createdAt,
    this.updatedAt,
    this.profileViewsCount = 0,
    this.adminFeatured = false,
    this.adminVerified = false,
    this.adminStatus = ManagedTeamStatus.active,
    this.recordStatus = AdminTeamRecordStatus.active,
    this.category,
    this.ballType,
    this.organizationId,
    this.deletedAt,
    this.deletedBy,
  });

  final String id;
  final String name;
  final String? teamCode;
  final String? logoUrl;
  final String? coverUrl;
  final String? captainId;
  final String? viceCaptainId;
  final String coachName;
  final String contactNumber;
  final String? createdBy;
  final List<String> playerIds;
  final int memberCount;
  final int followersCount;
  final int matchesPlayed;
  final int matchesWon;
  final int matchesLost;
  final int matchesTied;
  final int totalRunsScored;
  final int totalWicketsTaken;
  final String country;
  final String stateProvince;
  final String city;
  final String placeName;
  final List<String> badgeIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int profileViewsCount;
  final bool adminFeatured;
  final bool adminVerified;
  final ManagedTeamStatus adminStatus;
  final AdminTeamRecordStatus recordStatus;
  final ManagedTeamCategory? category;
  final ManagedTeamBallType? ballType;
  final String? organizationId;
  final DateTime? deletedAt;
  final String? deletedBy;

  bool get isSoftDeleted => recordStatus.isSoftDeleted;

  bool get isVerified =>
      adminVerified ||
      adminStatus == ManagedTeamStatus.verified ||
      badgeIds.isNotEmpty;

  ManagedTeamStatus get displayStatus => ManagedTeamStatus.derive(
        recordStatus: recordStatus,
        adminStatus: adminStatus.wireValue,
        adminVerified: adminVerified || badgeIds.isNotEmpty,
      );

  double get winPercentage {
    if (matchesPlayed <= 0) return 0;
    return (matchesWon / matchesPlayed) * 100;
  }

  String get winPctLabel =>
      matchesPlayed <= 0 ? '—' : '${winPercentage.toStringAsFixed(0)}%';

  String get locationLabel {
    final parts = [
      if (placeName.isNotEmpty) placeName,
      if (city.isNotEmpty) city,
      if (stateProvince.isNotEmpty) stateProvince,
      if (country.isNotEmpty) country,
    ];
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  String get shortLabel =>
      (teamCode != null && teamCode!.isNotEmpty) ? teamCode! : id;

  factory ManagedTeam.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
    int followersCount = 0,
  }) {
    final location = map['location'];
    final loc =
        location is Map ? Map<String, dynamic>.from(location) : const {};
    final stats = map['stats'];
    final statsMap = stats is Map ? Map<String, dynamic>.from(stats) : const {};
    final playerIds = List<String>.from(map['playerIds'] as List? ?? const []);
    final profile = (map['teamProfileImageUrl'] as String?)?.trim().isNotEmpty ==
            true
        ? map['teamProfileImageUrl'] as String
        : map['logoUrl'] as String?;
    final recordStatus =
        AdminTeamRecordStatus.parse(map['adminRecordStatus'] as String?);
    final adminVerified = map['adminVerified'] as bool? ?? false;
    final badgeIds = List<String>.from(map['badgeIds'] as List? ?? const []);

    return ManagedTeam(
      id: id,
      name: map['name'] as String? ?? '',
      teamCode: map['teamCode'] as String?,
      logoUrl: profile,
      coverUrl: map['teamCoverImageUrl'] as String?,
      captainId: map['captainId'] as String?,
      viceCaptainId: map['viceCaptainId'] as String?,
      coachName: map['coachName'] as String? ?? '',
      contactNumber: map['contactNumber'] as String? ?? '',
      createdBy: map['createdBy'] as String?,
      playerIds: playerIds,
      memberCount: (map['memberCount'] as num?)?.toInt() ?? playerIds.length,
      followersCount: followersCount,
      matchesPlayed: (statsMap['matchesPlayed'] as num?)?.toInt() ?? 0,
      matchesWon: (statsMap['matchesWon'] as num?)?.toInt() ?? 0,
      matchesLost: (statsMap['matchesLost'] as num?)?.toInt() ?? 0,
      matchesTied: (statsMap['matchesTied'] as num?)?.toInt() ?? 0,
      totalRunsScored: (statsMap['totalRunsScored'] as num?)?.toInt() ?? 0,
      totalWicketsTaken: (statsMap['totalWicketsTaken'] as num?)?.toInt() ?? 0,
      country: loc['country'] as String? ?? '',
      stateProvince: (loc['stateProvince'] as String?) ??
          (loc['state'] as String?) ??
          '',
      city: loc['city'] as String? ?? '',
      placeName: loc['placeName'] as String? ?? '',
      badgeIds: badgeIds,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      profileViewsCount: (map['profileViewsCount'] as num?)?.toInt() ?? 0,
      adminFeatured: map['adminFeatured'] as bool? ?? false,
      adminVerified: adminVerified,
      adminStatus: ManagedTeamStatus.parse(map['adminStatus'] as String?),
      recordStatus: recordStatus,
      category: ManagedTeamCategory.tryParse(map['adminCategory'] as String?),
      ballType: ManagedTeamBallType.tryParse(map['adminBallType'] as String?),
      organizationId: map['organizationId'] as String?,
      deletedAt: _parseDate(map['adminDeletedAt']),
      deletedBy: map['adminDeletedBy'] as String?,
    );
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
  List<Object?> get props => [
        id,
        name,
        adminFeatured,
        adminVerified,
        adminStatus,
        recordStatus,
        updatedAt,
      ];
}

class TeamPageResult {
  const TeamPageResult({
    required this.teams,
    required this.hasMore,
    this.cursor,
  });

  final List<ManagedTeam> teams;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
}

class TeamSummaryStats {
  const TeamSummaryStats({
    this.total = 0,
    this.verified = 0,
    this.active = 0,
    this.newTeams = 0,
    this.tournamentTeams = 0,
    this.clubTeams = 0,
    this.schoolTeams = 0,
    this.universityTeams = 0,
    this.nationalTeams = 0,
  });

  final int total;
  final int verified;
  final int active;
  final int newTeams;
  final int tournamentTeams;
  final int clubTeams;
  final int schoolTeams;
  final int universityTeams;
  final int nationalTeams;
}
