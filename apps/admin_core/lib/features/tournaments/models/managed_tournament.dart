import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'tournament_enums.dart';

class PointsTableRow extends Equatable {
  const PointsTableRow({
    required this.teamId,
    this.teamName = '',
    this.played = 0,
    this.won = 0,
    this.lost = 0,
    this.tied = 0,
    this.noResult = 0,
    this.points = 0,
    this.netRunRate = 0,
    this.position = 0,
  });

  final String teamId;
  final String teamName;
  final int played;
  final int won;
  final int lost;
  final int tied;
  final int noResult;
  final int points;
  final double netRunRate;
  final int position;

  factory PointsTableRow.fromMap(Map<String, dynamic> map) {
    return PointsTableRow(
      teamId: map['teamId'] as String? ?? '',
      teamName: map['teamName'] as String? ?? '',
      played: (map['played'] as num?)?.toInt() ?? 0,
      won: (map['won'] as num?)?.toInt() ?? 0,
      lost: (map['lost'] as num?)?.toInt() ?? 0,
      tied: (map['tied'] as num?)?.toInt() ?? 0,
      noResult: (map['noResult'] as num?)?.toInt() ?? 0,
      points: (map['points'] as num?)?.toInt() ?? 0,
      netRunRate: (map['netRunRate'] as num?)?.toDouble() ?? 0,
      position: (map['position'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [teamId, points, netRunRate];
}

/// Admin view of Firestore `tournaments/{id}` — maps mobile fields + additive admin meta.
class ManagedTournament extends Equatable {
  const ManagedTournament({
    required this.id,
    required this.name,
    this.format = ManagedTournamentFormat.league,
    this.status = ManagedTournamentStatus.draft,
    this.teamIds = const [],
    this.matchIds = const [],
    this.pointsTable = const [],
    this.bannerUrl,
    this.logoUrl,
    this.thumbnailUrl,
    this.grounds = const [],
    this.startDate,
    this.endDate,
    this.createdBy,
    this.organizerId,
    this.organizerName = '',
    this.organizerPhone = '',
    this.organizerEmail = '',
    this.description = '',
    this.tournamentCode,
    this.entryFee,
    this.winningPrize,
    this.ballType,
    this.country = '',
    this.stateProvince = '',
    this.city = '',
    this.placeName = '',
    this.createdAt,
    this.updatedAt,
    this.isLocked = false,
    this.adminFeatured = false,
    this.adminApproval = AdminTournamentApproval.approved,
    this.recordStatus = AdminTournamentRecordStatus.active,
    this.organizationId,
    this.deletedAt,
    this.deletedBy,
    this.registrationDeadline,
    this.teamsRequired,
  });

  final String id;
  final String name;
  final ManagedTournamentFormat format;
  final ManagedTournamentStatus status;
  final List<String> teamIds;
  final List<String> matchIds;
  final List<PointsTableRow> pointsTable;
  final String? bannerUrl;
  final String? logoUrl;
  final String? thumbnailUrl;
  final List<String> grounds;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? createdBy;
  final String? organizerId;
  final String organizerName;
  final String organizerPhone;
  final String organizerEmail;
  final String description;
  final String? tournamentCode;
  final double? entryFee;
  final String? winningPrize;
  final ManagedBallType? ballType;
  final String country;
  final String stateProvince;
  final String city;
  final String placeName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isLocked;

  final bool adminFeatured;
  final AdminTournamentApproval adminApproval;
  final AdminTournamentRecordStatus recordStatus;
  final String? organizationId;
  final DateTime? deletedAt;
  final String? deletedBy;
  final DateTime? registrationDeadline;
  final int? teamsRequired;

  String get effectiveOrganizerId => organizerId ?? createdBy ?? '';

  String get posterUrl => thumbnailUrl ?? logoUrl ?? bannerUrl ?? '';

  int get teamCount => teamIds.length;

  int get matchCount => matchIds.length;

  bool get isSoftDeleted => recordStatus.isSoftDeleted;

  bool get isFree => entryFee == null || entryFee! <= 0;

  String get locationLabel {
    final parts = [
      if (placeName.isNotEmpty) placeName,
      if (city.isNotEmpty) city,
      if (stateProvince.isNotEmpty) stateProvince,
      if (country.isNotEmpty) country,
    ];
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  String get currentStageLabel {
    if (status == ManagedTournamentStatus.completed) return 'Finished';
    if (status == ManagedTournamentStatus.live) return 'In progress';
    if (status == ManagedTournamentStatus.upcoming) return 'Pre-start';
    if (status == ManagedTournamentStatus.cancelled) return 'Cancelled';
    return 'Setup';
  }

  factory ManagedTournament.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final location = map['location'];
    final loc = location is Map ? Map<String, dynamic>.from(location) : const {};
    final setup = map['setupMeta'];
    final setupMeta = setup is Map ? Map<String, dynamic>.from(setup) : const {};

    final points = (map['pointsTable'] as List? ?? [])
        .whereType<Map>()
        .map((e) => PointsTableRow.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    return ManagedTournament(
      id: id,
      name: map['name'] as String? ?? '',
      format: ManagedTournamentFormat.parse(map['format'] as String?),
      status: ManagedTournamentStatus.parse(map['status'] as String?),
      teamIds: List<String>.from(map['teamIds'] as List? ?? const []),
      matchIds: List<String>.from(map['matchIds'] as List? ?? const []),
      pointsTable: points,
      bannerUrl: map['bannerUrl'] as String?,
      logoUrl: map['logoUrl'] as String?,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      grounds: List<String>.from(map['grounds'] as List? ?? const []),
      startDate: _parseDate(map['startDate']),
      endDate: _parseDate(map['endDate']),
      createdBy: map['createdBy'] as String?,
      organizerId: map['organizerId'] as String? ?? map['createdBy'] as String?,
      organizerName: setupMeta['organizerName'] as String? ?? '',
      organizerPhone: setupMeta['organizerPhone'] as String? ?? '',
      organizerEmail: setupMeta['organizerEmail'] as String? ?? '',
      description: map['description'] as String? ?? '',
      tournamentCode: map['tournamentCode'] as String?,
      entryFee: (map['entryFee'] as num?)?.toDouble(),
      winningPrize: map['winningPrize'] as String?,
      ballType: ManagedBallType.tryParse(map['ballType'] as String?),
      country: (loc['country'] as String?) ?? '',
      stateProvince: (loc['stateProvince'] as String?) ??
          (loc['state'] as String?) ??
          '',
      city: (loc['city'] as String?) ?? '',
      placeName: (loc['placeName'] as String?) ?? '',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      isLocked: map['isLocked'] as bool? ?? false,
      adminFeatured: map['adminFeatured'] as bool? ?? false,
      adminApproval:
          AdminTournamentApproval.parse(map['adminApprovalStatus'] as String?),
      recordStatus: AdminTournamentRecordStatus.parse(
        map['adminRecordStatus'] as String?,
      ),
      organizationId: map['organizationId'] as String?,
      deletedAt: _parseDate(map['adminDeletedAt'] ?? map['deletedAt']),
      deletedBy: (map['adminDeletedBy'] as String?) ?? (map['deletedBy'] as String?),
      registrationDeadline: _parseDate(
        setupMeta['registrationDeadline'] ?? map['registrationDeadline'],
      ),
      teamsRequired: (setupMeta['teamsRequired'] as num?)?.toInt() ??
          (setupMeta['totalTeams'] as num?)?.toInt(),
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
  List<Object?> get props =>
      [id, name, status, recordStatus, adminFeatured, updatedAt];
}

class TournamentPageResult {
  const TournamentPageResult({
    required this.tournaments,
    required this.hasMore,
    this.cursor,
  });

  final List<ManagedTournament> tournaments;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
}

class TournamentSummaryStats {
  const TournamentSummaryStats({
    this.total = 0,
    this.upcoming = 0,
    this.ongoing = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.live = 0,
    this.featured = 0,
  });

  final int total;
  final int upcoming;
  final int ongoing;
  final int completed;
  final int cancelled;
  final int live;
  final int featured;
}
