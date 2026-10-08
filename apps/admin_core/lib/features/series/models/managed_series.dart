/// Platform oversight models for mobile Orgs (Associations / Clubs / Series).
///
/// Source of truth is the mobile `series` collection (document `kind`
/// distinguishes associations, clubs and series). The web panel only reads
/// and moderates (suspend / restore / archive); org owners and admins manage
/// their orgs in the CrickFlow mobile app.
library;

/// Product families used by the mobile Orgs feature.
enum OrgFamily {
  associations,
  clubs,
  series;

  String get label => switch (this) {
    OrgFamily.associations => 'Associations',
    OrgFamily.clubs => 'Clubs',
    OrgFamily.series => 'Series',
  };

  /// Mirrors `OrgFamily.forKind` in the mobile app.
  static OrgFamily forKind(String kind) => switch (kind) {
    'association' || 'federation' => OrgFamily.associations,
    'club' || 'company' => OrgFamily.clubs,
    _ => OrgFamily.series,
  };
}

DateTime? _date(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  // Firestore Timestamp without importing cloud_firestore here.
  try {
    final dynamic d = raw;
    final v = d.toDate();
    if (v is DateTime) return v;
  } catch (_) {}
  return DateTime.tryParse(raw.toString());
}

String _titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class ManagedSeries {
  const ManagedSeries({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    required this.status,
    required this.ownerUid,
    required this.clubCount,
    required this.playerCount,
    required this.createdAt,
    this.region = '',
    this.country = '',
    this.logoUrl,
  });

  final String id;
  final String name;
  final String description;

  /// Stored `kind` (series, league, association, federation, club, …).
  final String kind;

  /// draft | active | suspended | archived
  final String status;

  /// `superAdminUserId` (org owner) or `createdBy` when unset.
  final String ownerUid;
  final int clubCount;
  final int playerCount;
  final DateTime? createdAt;
  final String region;
  final String country;
  final String? logoUrl;

  OrgFamily get family => OrgFamily.forKind(kind);
  String get kindLabel => _titleCase(kind);
  bool get isSuspended => status == 'suspended';
  bool get isArchived => status == 'archived';

  factory ManagedSeries.fromFirestore(String id, Map<String, dynamic> map) {
    final superId = (map['superAdminUserId'] as String?)?.trim() ?? '';
    return ManagedSeries(
      id: id,
      name: map['name'] as String? ?? 'Untitled org',
      description: map['description'] as String? ?? '',
      kind: (map['kind'] as String?)?.trim().isNotEmpty == true
          ? map['kind'] as String
          : 'series',
      status: map['status'] as String? ?? 'draft',
      ownerUid: superId.isNotEmpty
          ? superId
          : (map['createdBy'] as String? ?? ''),
      clubCount: (map['clubCount'] as num?)?.toInt() ?? 0,
      playerCount: (map['playerCount'] as num?)?.toInt() ?? 0,
      createdAt: _date(map['createdAt']),
      region: map['region'] as String? ?? '',
      country: map['country'] as String? ?? '',
      logoUrl: map['logoUrl'] as String?,
    );
  }
}

/// A row from `series_admins`, `series_clubs`, approvals or audit logs.
class SeriesRow {
  const SeriesRow(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;

  String str(String key, [String fallback = '']) {
    final v = data[key];
    return v == null ? fallback : v.toString();
  }

  DateTime? date(String key) => _date(data[key]);
}

class SeriesInvestigation {
  const SeriesInvestigation({
    required this.series,
    required this.admins,
    required this.clubs,
    required this.approvals,
    required this.auditLogs,
  });

  final ManagedSeries series;
  final List<SeriesRow> admins;
  final List<SeriesRow> clubs;
  final List<SeriesRow> approvals;

  /// Newest first.
  final List<SeriesRow> auditLogs;

  int get pendingApprovals =>
      approvals.where((a) => a.str('status') == 'pending').length;
}

/// Status changes a platform moderator may apply (rules enforce the same).
abstract final class OrgModeration {
  static const seriesStatuses = {'active', 'suspended', 'archived'};
  static const clubStatuses = {'approved', 'suspended'};

  /// Allowed next statuses for an org from [current].
  static List<String> nextSeriesStatuses(String current) => switch (current) {
    'suspended' => const ['active', 'archived'],
    'archived' => const ['active'],
    _ => const ['suspended', 'archived'],
  };

  static String actionLabel(String next) => switch (next) {
    'active' => 'Restore',
    'suspended' => 'Suspend',
    'archived' => 'Archive',
    'approved' => 'Restore',
    _ => _titleCase(next),
  };

  static String auditAction(String next) => switch (next) {
    'suspended' => 'ENTITY_SUSPENDED',
    'archived' => 'ENTITY_ARCHIVED',
    _ => 'ENTITY_RESTORED',
  };
}
