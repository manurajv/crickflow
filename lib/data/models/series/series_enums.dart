/// Series / Competition Organization enums.
library;

enum SeriesKind {
  series,
  league,
  association,
  federation,
  club,
  company,
  cup,
  other;

  /// UI label (Title Case). Stored value remains [name] (lowercase).
  String get label => switch (this) {
        SeriesKind.series => 'Series',
        SeriesKind.league => 'League',
        SeriesKind.association => 'Association',
        SeriesKind.federation => 'Federation',
        SeriesKind.club => 'Club',
        SeriesKind.company => 'Company',
        SeriesKind.cup => 'Cup',
        SeriesKind.other => 'Other',
      };

  static SeriesKind parse(String? raw) {
    if (raw == null || raw.isEmpty) return SeriesKind.series;
    return SeriesKind.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SeriesKind.series,
    );
  }
}

/// Product surfaces for the Orgs feature (Associations / Clubs / Series).
enum OrgFamily {
  associations,
  clubs,
  series;

  String get title => switch (this) {
        OrgFamily.associations => 'Associations',
        OrgFamily.clubs => 'Clubs',
        OrgFamily.series => 'Series',
      };

  String get singular => switch (this) {
        OrgFamily.associations => 'Association',
        OrgFamily.clubs => 'Club',
        OrgFamily.series => 'Series',
      };

  String get routePath => switch (this) {
        OrgFamily.associations => '/associations',
        OrgFamily.clubs => '/clubs',
        OrgFamily.series => '/series',
      };

  List<SeriesKind> get kinds => switch (this) {
        OrgFamily.associations => const [
          SeriesKind.association,
          SeriesKind.federation,
        ],
        OrgFamily.clubs => const [
          SeriesKind.club,
          SeriesKind.company,
        ],
        OrgFamily.series => const [
          SeriesKind.series,
          SeriesKind.league,
          SeriesKind.cup,
          SeriesKind.other,
        ],
      };

  SeriesKind get defaultKind => kinds.first;

  static OrgFamily? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final key = raw.startsWith('/') ? raw.substring(1) : raw;
    for (final family in OrgFamily.values) {
      if (family.name == key || family.routePath == '/$key') return family;
    }
    return null;
  }

  static OrgFamily forKind(SeriesKind kind) {
    for (final family in OrgFamily.values) {
      if (family.kinds.contains(kind)) return family;
    }
    return OrgFamily.series;
  }
}

enum SeriesStatus {
  draft,
  active,
  suspended,
  archived;

  static SeriesStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return SeriesStatus.draft;
    return SeriesStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SeriesStatus.draft,
    );
  }
}

enum SeriesClubStatus {
  pending,
  approved,
  rejected,
  suspended;

  /// User-facing label (not the backend enum name).
  String get label => switch (this) {
        SeriesClubStatus.pending => 'Pending approval',
        SeriesClubStatus.approved => 'Approved',
        SeriesClubStatus.rejected => 'Rejected',
        SeriesClubStatus.suspended => 'Suspended',
      };

  static SeriesClubStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return SeriesClubStatus.pending;
    return SeriesClubStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SeriesClubStatus.pending,
    );
  }
}

enum SeriesApprovalStatus {
  pending,
  approved,
  rejected,
  cancelled;

  String get label => switch (this) {
        SeriesApprovalStatus.pending => 'Pending',
        SeriesApprovalStatus.approved => 'Approved',
        SeriesApprovalStatus.rejected => 'Rejected',
        SeriesApprovalStatus.cancelled => 'Cancelled',
      };

  static SeriesApprovalStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return SeriesApprovalStatus.pending;
    return SeriesApprovalStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SeriesApprovalStatus.pending,
    );
  }
}

enum SeriesApprovalTargetType {
  clubRegistration,
  playerRegistration,
  playerJoin,
  playerAdd,
  playerRemoval,
  match,
  tournament,
  squadChange,
  other;

  String get label => switch (this) {
        SeriesApprovalTargetType.clubRegistration => 'Club registration',
        SeriesApprovalTargetType.playerRegistration => 'Player registration',
        SeriesApprovalTargetType.playerJoin => 'Join request',
        SeriesApprovalTargetType.playerAdd => 'Add player',
        SeriesApprovalTargetType.playerRemoval => 'Remove player',
        SeriesApprovalTargetType.match => 'Match proposal',
        SeriesApprovalTargetType.tournament => 'Tournament proposal',
        SeriesApprovalTargetType.squadChange => 'Squad change',
        SeriesApprovalTargetType.other => 'Request',
      };

  static SeriesApprovalTargetType parse(String? raw) {
    if (raw == null || raw.isEmpty) return SeriesApprovalTargetType.other;
    return SeriesApprovalTargetType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SeriesApprovalTargetType.other,
    );
  }
}

enum SeriesCompetitionType {
  singleMatch,
  tournament;

  String get label => switch (this) {
        SeriesCompetitionType.singleMatch => 'Match',
        SeriesCompetitionType.tournament => 'Tournament',
      };

  static SeriesCompetitionType parse(String? raw) {
    if (raw == null || raw.isEmpty) return SeriesCompetitionType.singleMatch;
    return SeriesCompetitionType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SeriesCompetitionType.singleMatch,
    );
  }
}

enum SeriesMembershipStatus {
  active,
  pendingRemoval,
  removed,
  suspended;

  String get label => switch (this) {
        SeriesMembershipStatus.active => 'Active',
        SeriesMembershipStatus.pendingRemoval => 'Removal pending',
        SeriesMembershipStatus.removed => 'Removed',
        SeriesMembershipStatus.suspended => 'Suspended',
      };

  static SeriesMembershipStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return SeriesMembershipStatus.active;
    return SeriesMembershipStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SeriesMembershipStatus.active,
    );
  }
}

enum SeriesRole {
  superAdmin,
  seriesAdmin,
  clubAdmin,
  seriesPlayer,
  viewer;

  String get label => switch (this) {
        SeriesRole.superAdmin => 'Owner',
        SeriesRole.seriesAdmin => 'Admin',
        SeriesRole.clubAdmin => 'Club admin',
        SeriesRole.seriesPlayer => 'Player',
        SeriesRole.viewer => 'Viewer',
      };

  static SeriesRole parse(String? raw) {
    if (raw == null || raw.isEmpty) return SeriesRole.viewer;
    return SeriesRole.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SeriesRole.viewer,
    );
  }
}

/// Match/tournament Series approval lifecycle on linked cricket docs.
enum SeriesOfficialStatus {
  none,
  draft,
  pendingApproval,
  approved,
  rejected,
  cancelled;

  String get label => switch (this) {
        SeriesOfficialStatus.none => 'Not linked',
        SeriesOfficialStatus.draft => 'Draft',
        SeriesOfficialStatus.pendingApproval => 'Pending approval',
        SeriesOfficialStatus.approved => 'Approved',
        SeriesOfficialStatus.rejected => 'Rejected',
        SeriesOfficialStatus.cancelled => 'Cancelled',
      };

  static SeriesOfficialStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return SeriesOfficialStatus.none;
    return SeriesOfficialStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SeriesOfficialStatus.none,
    );
  }
}
