class ManagedSeries {
  const ManagedSeries({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.superAdminUserId,
    required this.clubCount,
    required this.playerCount,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String status;
  final String superAdminUserId;
  final int clubCount;
  final int playerCount;
  final DateTime? createdAt;

  factory ManagedSeries.fromFirestore(String id, Map<String, dynamic> map) =>
      ManagedSeries(
        id: id,
        name: map['name'] as String? ?? 'Series',
        description: map['description'] as String? ?? '',
        status: map['status'] as String? ?? 'draft',
        superAdminUserId: map['superAdminUserId'] as String? ?? '',
        clubCount: (map['clubCount'] as num?)?.toInt() ?? 0,
        playerCount: (map['playerCount'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      );
}

class SeriesInvestigation {
  const SeriesInvestigation({
    required this.series,
    required this.clubs,
    required this.admins,
    required this.auditLogs,
  });

  final ManagedSeries series;
  final List<Map<String, dynamic>> clubs;
  final List<Map<String, dynamic>> admins;
  final List<Map<String, dynamic>> auditLogs;
}
