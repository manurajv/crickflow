/// Soft record lifecycle for admin (additive; distinct from mobile `status`).
enum AdminTournamentRecordStatus {
  active,
  deleted,
  archived;

  String get label => switch (this) {
        AdminTournamentRecordStatus.active => 'Active',
        AdminTournamentRecordStatus.deleted => 'Deleted',
        AdminTournamentRecordStatus.archived => 'Archived',
      };

  String get wireValue => name;

  bool get isSoftDeleted => this == AdminTournamentRecordStatus.deleted;

  static AdminTournamentRecordStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return AdminTournamentRecordStatus.active;
    for (final s in AdminTournamentRecordStatus.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return AdminTournamentRecordStatus.active;
  }
}

/// Platform approval workflow (additive).
enum AdminTournamentApproval {
  pending,
  approved,
  rejected;

  String get label => switch (this) {
        AdminTournamentApproval.pending => 'Pending',
        AdminTournamentApproval.approved => 'Approved',
        AdminTournamentApproval.rejected => 'Rejected',
      };

  String get wireValue => name;

  static AdminTournamentApproval parse(String? raw) {
    if (raw == null || raw.isEmpty) return AdminTournamentApproval.approved;
    for (final s in AdminTournamentApproval.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return AdminTournamentApproval.approved;
  }
}

/// Mirrors mobile [TournamentStatus] wire values — do not rename.
enum ManagedTournamentStatus {
  draft,
  upcoming,
  live,
  completed,
  cancelled;

  String get label => switch (this) {
        ManagedTournamentStatus.draft => 'Draft',
        ManagedTournamentStatus.upcoming => 'Upcoming',
        ManagedTournamentStatus.live => 'Ongoing',
        ManagedTournamentStatus.completed => 'Completed',
        ManagedTournamentStatus.cancelled => 'Cancelled',
      };

  String get wireValue => name;

  static ManagedTournamentStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedTournamentStatus.draft;
    for (final s in ManagedTournamentStatus.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return ManagedTournamentStatus.draft;
  }
}

/// Mirrors mobile [TournamentFormat] wire values.
enum ManagedTournamentFormat {
  league,
  knockout,
  leagueKnockout,
  custom;

  String get label => switch (this) {
        ManagedTournamentFormat.league => 'League',
        ManagedTournamentFormat.knockout => 'Knockout',
        ManagedTournamentFormat.leagueKnockout => 'League + Knockout',
        ManagedTournamentFormat.custom => 'Custom / Friendly',
      };

  String get wireValue => name;

  static ManagedTournamentFormat parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedTournamentFormat.league;
    for (final s in ManagedTournamentFormat.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return ManagedTournamentFormat.league;
  }
}

enum ManagedBallType {
  leather,
  tennis,
  indoor;

  String get label => switch (this) {
        ManagedBallType.leather => 'Leather',
        ManagedBallType.tennis => 'Tennis',
        ManagedBallType.indoor => 'Indoor',
      };

  String get wireValue => name;

  static ManagedBallType? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final s in ManagedBallType.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return null;
  }
}
