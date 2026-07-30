import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'player_enums.dart';

/// Admin view of Firestore `players/{id}` — mobile fields + additive admin meta.
class ManagedPlayer extends Equatable {
  const ManagedPlayer({
    required this.id,
    required this.name,
    this.fullName = '',
    this.userId,
    this.publicPlayerId,
    this.photoUrl,
    this.role = '',
    this.battingStyle = '',
    this.bowlingStyle = '',
    this.jerseyNumber,
    this.teamIds = const [],
    this.legacyTeamId,
    this.country = '',
    this.stateProvince = '',
    this.city = '',
    this.matchesPlayed = 0,
    this.runs = 0,
    this.wickets = 0,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.adminFeatured = false,
    this.adminVerified = false,
    this.adminStatus = ManagedPlayerStatus.active,
    this.recordStatus = AdminPlayerRecordStatus.active,
    this.organizationId,
    this.deletedAt,
    this.deletedBy,
  });

  final String id;
  final String name;
  final String fullName;
  final String? userId;
  final String? publicPlayerId;
  final String? photoUrl;
  final String role;
  final String battingStyle;
  final String bowlingStyle;
  final int? jerseyNumber;
  final List<String> teamIds;
  final String? legacyTeamId;
  final String country;
  final String stateProvince;
  final String city;
  final int matchesPlayed;
  final int runs;
  final int wickets;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final bool adminFeatured;
  final bool adminVerified;
  final ManagedPlayerStatus adminStatus;
  final AdminPlayerRecordStatus recordStatus;
  final String? organizationId;
  final DateTime? deletedAt;
  final String? deletedBy;

  bool get isSoftDeleted => recordStatus.isSoftDeleted;

  bool get isRegistered => userId != null && userId!.isNotEmpty;

  bool get isWalkIn => !isRegistered;

  String get displayName =>
      name.trim().isNotEmpty ? name : (fullName.trim().isNotEmpty ? fullName : id);

  String get cfIdLabel =>
      (publicPlayerId != null && publicPlayerId!.isNotEmpty)
          ? publicPlayerId!
          : '—';

  List<String> get effectiveTeamIds {
    final ids = <String>{...teamIds};
    final legacy = legacyTeamId;
    if (legacy != null && legacy.isNotEmpty) ids.add(legacy);
    return ids.toList();
  }

  String get locationLabel {
    final parts = [
      if (city.isNotEmpty) city,
      if (stateProvince.isNotEmpty) stateProvince,
      if (country.isNotEmpty) country,
    ];
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  ManagedPlayerStatus get displayStatus => ManagedPlayerStatus.derive(
        recordStatus: recordStatus,
        adminStatus: adminStatus.wireValue,
        adminVerified: adminVerified,
      );

  factory ManagedPlayer.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final location = map['location'];
    final loc =
        location is Map ? Map<String, dynamic>.from(location) : const {};
    final stats = map['stats'];
    final statsMap = stats is Map ? Map<String, dynamic>.from(stats) : const {};
    final teamIds = List<String>.from(map['teamIds'] as List? ?? const []);

    return ManagedPlayer(
      id: id,
      name: map['name'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      userId: map['userId'] as String?,
      publicPlayerId:
          map['playerId'] as String? ?? map['cfPlayerId'] as String?,
      photoUrl: map['photoUrl'] as String?,
      role: map['role'] as String? ?? '',
      battingStyle: map['battingStyle'] as String? ?? '',
      bowlingStyle: map['bowlingStyle'] as String? ?? '',
      jerseyNumber: (map['jerseyNumber'] as num?)?.toInt(),
      teamIds: teamIds,
      legacyTeamId: map['teamId'] as String?,
      country: loc['country'] as String? ?? '',
      stateProvince: (loc['stateProvince'] as String?) ??
          (loc['state'] as String?) ??
          '',
      city: loc['city'] as String? ?? '',
      matchesPlayed: (statsMap['matchesPlayed'] as num?)?.toInt() ?? 0,
      runs: (statsMap['runs'] as num?)?.toInt() ?? 0,
      wickets: (statsMap['wickets'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      createdBy: map['createdBy'] as String?,
      adminFeatured: map['adminFeatured'] as bool? ?? false,
      adminVerified: map['adminVerified'] as bool? ?? false,
      adminStatus: ManagedPlayerStatus.parse(map['adminStatus'] as String?),
      recordStatus:
          AdminPlayerRecordStatus.parse(map['adminRecordStatus'] as String?),
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
      ];
}

class PlayerSummaryStats {
  const PlayerSummaryStats({
    this.total = 0,
    this.registered = 0,
    this.walkIn = 0,
    this.verified = 0,
    this.active = 0,
    this.suspended = 0,
  });

  final int total;
  final int registered;
  final int walkIn;
  final int verified;
  final int active;
  final int suspended;
}

class PlayerPageResult {
  const PlayerPageResult({
    required this.players,
    required this.hasMore,
    this.cursor,
  });

  final List<ManagedPlayer> players;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
}
