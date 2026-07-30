/// Soft record lifecycle for admin `organizations` docs.
enum AdminOrganizationRecordStatus {
  active,
  archived,
  softDeleted;

  String get label => switch (this) {
        AdminOrganizationRecordStatus.active => 'Active',
        AdminOrganizationRecordStatus.archived => 'Archived',
        AdminOrganizationRecordStatus.softDeleted => 'Deleted',
      };

  String get wireValue => switch (this) {
        AdminOrganizationRecordStatus.active => 'active',
        AdminOrganizationRecordStatus.archived => 'archived',
        AdminOrganizationRecordStatus.softDeleted => 'soft_deleted',
      };

  bool get isSoftDeleted => this == AdminOrganizationRecordStatus.softDeleted;
  bool get isArchived => this == AdminOrganizationRecordStatus.archived;

  static AdminOrganizationRecordStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return AdminOrganizationRecordStatus.active;
    }
    final n = raw.toLowerCase();
    if (n == 'soft_deleted' || n == 'softdeleted' || n == 'deleted') {
      return AdminOrganizationRecordStatus.softDeleted;
    }
    if (n == 'archived') return AdminOrganizationRecordStatus.archived;
    return AdminOrganizationRecordStatus.active;
  }
}

/// Operational status for organizations.
enum ManagedOrganizationStatus {
  active,
  pending,
  verified,
  inactive,
  suspended,
  archived,
  deleted;

  String get label => switch (this) {
        ManagedOrganizationStatus.active => 'Active',
        ManagedOrganizationStatus.pending => 'Pending Approval',
        ManagedOrganizationStatus.verified => 'Verified',
        ManagedOrganizationStatus.inactive => 'Inactive',
        ManagedOrganizationStatus.suspended => 'Suspended',
        ManagedOrganizationStatus.archived => 'Archived',
        ManagedOrganizationStatus.deleted => 'Deleted',
      };

  String get wireValue => name;

  bool get isApproved =>
      this == ManagedOrganizationStatus.active ||
      this == ManagedOrganizationStatus.verified;

  static ManagedOrganizationStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedOrganizationStatus.active;
    for (final s in ManagedOrganizationStatus.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return ManagedOrganizationStatus.active;
  }

  static ManagedOrganizationStatus derive({
    required AdminOrganizationRecordStatus recordStatus,
    required String? status,
  }) {
    if (recordStatus.isSoftDeleted) return ManagedOrganizationStatus.deleted;
    if (recordStatus.isArchived) return ManagedOrganizationStatus.archived;
    return parse(status);
  }
}

/// Cricket org types.
enum ManagedOrganizationType {
  nationalBoard,
  provincialBoard,
  districtAssociation,
  club,
  academy,
  school,
  university,
  corporate,
  league,
  tournamentOrganizer,
  privateGroup,
  other;

  String get label => switch (this) {
        ManagedOrganizationType.nationalBoard => 'National Cricket Board',
        ManagedOrganizationType.provincialBoard => 'Provincial Cricket Board',
        ManagedOrganizationType.districtAssociation =>
          'District Cricket Association',
        ManagedOrganizationType.club => 'Cricket Club',
        ManagedOrganizationType.academy => 'Cricket Academy',
        ManagedOrganizationType.school => 'School',
        ManagedOrganizationType.university => 'University',
        ManagedOrganizationType.corporate => 'Corporate Organization',
        ManagedOrganizationType.league => 'League',
        ManagedOrganizationType.tournamentOrganizer => 'Tournament Organizer',
        ManagedOrganizationType.privateGroup => 'Private Cricket Group',
        ManagedOrganizationType.other => 'Other',
      };

  String get wireValue => name;

  /// Short display label for table chips.
  String get shortLabel => switch (this) {
        ManagedOrganizationType.nationalBoard => 'Nat. Board',
        ManagedOrganizationType.provincialBoard => 'Prov. Board',
        ManagedOrganizationType.districtAssociation => 'District',
        ManagedOrganizationType.club => 'Club',
        ManagedOrganizationType.academy => 'Academy',
        ManagedOrganizationType.school => 'School',
        ManagedOrganizationType.university => 'University',
        ManagedOrganizationType.corporate => 'Corporate',
        ManagedOrganizationType.league => 'League',
        ManagedOrganizationType.tournamentOrganizer => 'Tournament Org.',
        ManagedOrganizationType.privateGroup => 'Private',
        ManagedOrganizationType.other => 'Other',
      };

  static ManagedOrganizationType parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedOrganizationType.other;
    // Legacy map: 'board' → nationalBoard
    if (raw.toLowerCase() == 'board') {
      return ManagedOrganizationType.nationalBoard;
    }
    for (final s in ManagedOrganizationType.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return ManagedOrganizationType.other;
  }
}

/// Detail panel tab index.
enum OrgDetailTab {
  overview,
  administrators,
  teams,
  players,
  tournaments,
  grounds,
  matches,
  broadcasts,
  community,
  analytics,
  documents,
  reports,
  auditLog;

  String get label => switch (this) {
        OrgDetailTab.overview => 'Overview',
        OrgDetailTab.administrators => 'Administrators',
        OrgDetailTab.teams => 'Teams',
        OrgDetailTab.players => 'Players',
        OrgDetailTab.tournaments => 'Tournaments',
        OrgDetailTab.grounds => 'Grounds',
        OrgDetailTab.matches => 'Matches',
        OrgDetailTab.broadcasts => 'Broadcasts',
        OrgDetailTab.community => 'Community',
        OrgDetailTab.analytics => 'Analytics',
        OrgDetailTab.documents => 'Documents',
        OrgDetailTab.reports => 'Reports',
        OrgDetailTab.auditLog => 'Audit Log',
      };
}
