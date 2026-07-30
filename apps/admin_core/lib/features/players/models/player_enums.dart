/// Soft record lifecycle for admin (additive).
enum AdminPlayerRecordStatus {
  active,
  deleted,
  archived;

  String get label => switch (this) {
        AdminPlayerRecordStatus.active => 'Active',
        AdminPlayerRecordStatus.deleted => 'Deleted',
        AdminPlayerRecordStatus.archived => 'Archived',
      };

  String get wireValue => name;

  bool get isSoftDeleted => this == AdminPlayerRecordStatus.deleted;

  static AdminPlayerRecordStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return AdminPlayerRecordStatus.active;
    for (final s in AdminPlayerRecordStatus.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return AdminPlayerRecordStatus.active;
  }
}

/// Operational admin status for players (additive `adminStatus`).
enum ManagedPlayerStatus {
  active,
  pendingVerification,
  verified,
  suspended,
  archived,
  deleted;

  String get label => switch (this) {
        ManagedPlayerStatus.active => 'Active',
        ManagedPlayerStatus.pendingVerification => 'Pending Verification',
        ManagedPlayerStatus.verified => 'Verified',
        ManagedPlayerStatus.suspended => 'Suspended',
        ManagedPlayerStatus.archived => 'Archived',
        ManagedPlayerStatus.deleted => 'Deleted',
      };

  String get wireValue => name;

  static ManagedPlayerStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedPlayerStatus.active;
    for (final s in ManagedPlayerStatus.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return ManagedPlayerStatus.active;
  }

  static ManagedPlayerStatus derive({
    required AdminPlayerRecordStatus recordStatus,
    required String? adminStatus,
    required bool adminVerified,
  }) {
    if (recordStatus == AdminPlayerRecordStatus.deleted) {
      return ManagedPlayerStatus.deleted;
    }
    if (recordStatus == AdminPlayerRecordStatus.archived) {
      return ManagedPlayerStatus.archived;
    }
    final parsed = parse(adminStatus);
    if (parsed == ManagedPlayerStatus.suspended) {
      return ManagedPlayerStatus.suspended;
    }
    if (parsed == ManagedPlayerStatus.pendingVerification) {
      return ManagedPlayerStatus.pendingVerification;
    }
    if (adminVerified || parsed == ManagedPlayerStatus.verified) {
      return ManagedPlayerStatus.verified;
    }
    return ManagedPlayerStatus.active;
  }
}

enum PlayerSortField {
  name,
  createdAt,
  matches,
  runs,
  wickets;

  String get label => switch (this) {
        PlayerSortField.name => 'Name',
        PlayerSortField.createdAt => 'Created',
        PlayerSortField.matches => 'Matches',
        PlayerSortField.runs => 'Runs',
        PlayerSortField.wickets => 'Wickets',
      };
}

class PlayerSort {
  const PlayerSort({
    this.field = PlayerSortField.createdAt,
    this.descending = true,
  });

  final PlayerSortField field;
  final bool descending;

  PlayerSort copyWith({PlayerSortField? field, bool? descending}) =>
      PlayerSort(
        field: field ?? this.field,
        descending: descending ?? this.descending,
      );
}
