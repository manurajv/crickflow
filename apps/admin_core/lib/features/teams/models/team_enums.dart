/// Soft record lifecycle for admin (additive; distinct from operational status).
enum AdminTeamRecordStatus {
  active,
  deleted,
  archived;

  String get label => switch (this) {
        AdminTeamRecordStatus.active => 'Active',
        AdminTeamRecordStatus.deleted => 'Deleted',
        AdminTeamRecordStatus.archived => 'Archived',
      };

  String get wireValue => name;

  bool get isSoftDeleted => this == AdminTeamRecordStatus.deleted;

  static AdminTeamRecordStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return AdminTeamRecordStatus.active;
    for (final s in AdminTeamRecordStatus.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return AdminTeamRecordStatus.active;
  }
}

/// Operational admin status for teams (additive `adminStatus`).
enum ManagedTeamStatus {
  active,
  pendingVerification,
  verified,
  suspended,
  archived,
  deleted;

  String get label => switch (this) {
        ManagedTeamStatus.active => 'Active',
        ManagedTeamStatus.pendingVerification => 'Pending Verification',
        ManagedTeamStatus.verified => 'Verified',
        ManagedTeamStatus.suspended => 'Suspended',
        ManagedTeamStatus.archived => 'Archived',
        ManagedTeamStatus.deleted => 'Deleted',
      };

  String get wireValue => name;

  static ManagedTeamStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedTeamStatus.active;
    for (final s in ManagedTeamStatus.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return ManagedTeamStatus.active;
  }

  /// Derive display status from additive admin fields.
  static ManagedTeamStatus derive({
    required AdminTeamRecordStatus recordStatus,
    required String? adminStatus,
    required bool adminVerified,
  }) {
    if (recordStatus == AdminTeamRecordStatus.deleted) {
      return ManagedTeamStatus.deleted;
    }
    if (recordStatus == AdminTeamRecordStatus.archived) {
      return ManagedTeamStatus.archived;
    }
    final parsed = parse(adminStatus);
    if (parsed == ManagedTeamStatus.suspended) {
      return ManagedTeamStatus.suspended;
    }
    if (parsed == ManagedTeamStatus.pendingVerification) {
      return ManagedTeamStatus.pendingVerification;
    }
    if (adminVerified || parsed == ManagedTeamStatus.verified) {
      return ManagedTeamStatus.verified;
    }
    return ManagedTeamStatus.active;
  }
}

/// Additive admin category — mobile teams have no category field yet.
enum ManagedTeamCategory {
  club,
  academy,
  school,
  university,
  corporate,
  district,
  provincial,
  national,
  custom;

  String get label => switch (this) {
        ManagedTeamCategory.club => 'Club',
        ManagedTeamCategory.academy => 'Academy',
        ManagedTeamCategory.school => 'School',
        ManagedTeamCategory.university => 'University',
        ManagedTeamCategory.corporate => 'Corporate',
        ManagedTeamCategory.district => 'District',
        ManagedTeamCategory.provincial => 'Provincial',
        ManagedTeamCategory.national => 'National',
        ManagedTeamCategory.custom => 'Custom',
      };

  String get wireValue => name;

  static ManagedTeamCategory? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final s in ManagedTeamCategory.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return null;
  }
}

/// Additive admin ball preference for teams (not on mobile team docs).
enum ManagedTeamBallType {
  leather,
  tennis,
  indoor;

  String get label => switch (this) {
        ManagedTeamBallType.leather => 'Leather',
        ManagedTeamBallType.tennis => 'Tennis',
        ManagedTeamBallType.indoor => 'Indoor',
      };

  String get wireValue => name;

  static ManagedTeamBallType? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final s in ManagedTeamBallType.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return null;
  }
}
