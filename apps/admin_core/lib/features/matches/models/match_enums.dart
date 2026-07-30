enum AdminMatchRecordStatus {
  active,
  deleted,
  archived;

  String get label => switch (this) {
        AdminMatchRecordStatus.active => 'Active',
        AdminMatchRecordStatus.deleted => 'Deleted',
        AdminMatchRecordStatus.archived => 'Archived',
      };

  String get wireValue => name;

  bool get isSoftDeleted => this == AdminMatchRecordStatus.deleted;

  static AdminMatchRecordStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return AdminMatchRecordStatus.active;
    for (final s in AdminMatchRecordStatus.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return AdminMatchRecordStatus.active;
  }
}

enum ManagedMatchStatus {
  draft,
  scheduled,
  tossCompleted,
  live,
  inningsBreak,
  completed,
  abandoned,
  cancelled,
  delayed;

  String get label => switch (this) {
        ManagedMatchStatus.draft => 'Draft',
        ManagedMatchStatus.scheduled => 'Upcoming',
        ManagedMatchStatus.tossCompleted => 'Toss',
        ManagedMatchStatus.live => 'Live',
        ManagedMatchStatus.inningsBreak => 'Innings Break',
        ManagedMatchStatus.completed => 'Completed',
        ManagedMatchStatus.abandoned => 'Abandoned',
        ManagedMatchStatus.cancelled => 'Cancelled',
        ManagedMatchStatus.delayed => 'Delayed',
      };

  String get wireValue => this == ManagedMatchStatus.cancelled ? 'cancelled' : name;

  static ManagedMatchStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedMatchStatus.draft;
    if (raw == 'cancelled') return ManagedMatchStatus.cancelled;
    if (raw == 'delayed') return ManagedMatchStatus.delayed;
    for (final s in ManagedMatchStatus.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return ManagedMatchStatus.draft;
  }
}

enum ManagedMatchType { single, tournament, league, knockout, series, friendly;
  String get label => switch (this) {
    ManagedMatchType.single => 'Friendly',
    ManagedMatchType.tournament => 'Tournament',
    ManagedMatchType.league => 'League',
    ManagedMatchType.knockout => 'Knockout',
    ManagedMatchType.series => 'Series',
    ManagedMatchType.friendly => 'Friendly',
  };

  static ManagedMatchType derive({String? matchType, String? roundName}) {
    final mt = (matchType ?? '').toLowerCase();
    final round = (roundName ?? '').toLowerCase();
    if (round.contains('knockout') || round.contains('quarter') || round.contains('semi') || round.contains('final')) {
      return ManagedMatchType.knockout;
    }
    if (round.contains('league') || round.contains('group')) return ManagedMatchType.league;
    if (round.contains('series')) return ManagedMatchType.series;
    if (mt == 'tournament') return ManagedMatchType.tournament;
    if (mt == 'single') return ManagedMatchType.friendly;
    return ManagedMatchType.friendly;
  }
}

enum ManagedCricketType { limitedOvers, indoor, testMatch;
  String get label => switch (this) {
    ManagedCricketType.limitedOvers => 'Limited Overs',
    ManagedCricketType.indoor => 'Indoor',
    ManagedCricketType.testMatch => 'Test Match',
  };

  static ManagedCricketType? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final s in ManagedCricketType.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return null;
  }
}

enum ManagedBallType { leather, tennis, indoor;
  String get label => switch (this) {
    ManagedBallType.leather => 'Leather',
    ManagedBallType.tennis => 'Tennis',
    ManagedBallType.indoor => 'Indoor',
  };

  static ManagedBallType? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final s in ManagedBallType.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return null;
  }
}

enum ManagedStreamStatus { idle, connecting, live, ended, error;
  String get label => switch (this) {
    ManagedStreamStatus.idle => 'Not Streaming',
    ManagedStreamStatus.connecting => 'Connecting',
    ManagedStreamStatus.live => 'Streaming',
    ManagedStreamStatus.ended => 'Ended',
    ManagedStreamStatus.error => 'Issue',
  };

  static ManagedStreamStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedStreamStatus.idle;
    for (final s in ManagedStreamStatus.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return ManagedStreamStatus.idle;
  }
}

enum ManagedStreamPlatform { youtube, facebook, externalRtmp, none, other;
  String get label => switch (this) {
    ManagedStreamPlatform.youtube => 'YouTube',
    ManagedStreamPlatform.facebook => 'Facebook',
    ManagedStreamPlatform.externalRtmp => 'External RTMP',
    ManagedStreamPlatform.none => 'No Stream',
    ManagedStreamPlatform.other => 'Other',
  };

  static ManagedStreamPlatform parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedStreamPlatform.none;
    switch (raw.toLowerCase()) {
      case 'youtube': return ManagedStreamPlatform.youtube;
      case 'facebook': return ManagedStreamPlatform.facebook;
      case 'externalrtmp':
      case 'external_rtmp':
      case 'customrtmp':
      case 'custom_rtmp':
      case 'rtmp': return ManagedStreamPlatform.externalRtmp;
      case 'none': return ManagedStreamPlatform.none;
      default: return ManagedStreamPlatform.other;
    }
  }
}
