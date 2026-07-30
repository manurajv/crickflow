/// Notification & announcement admin enums.
enum NotificationHubSection {
  dashboard,
  notifications,
  announcements,
  campaigns,
  scheduled,
  templates,
  deliveryReports,
  segments,
  history,
  autoNotifications;

  String get label => switch (this) {
        NotificationHubSection.dashboard => 'Dashboard',
        NotificationHubSection.notifications => 'Notifications',
        NotificationHubSection.announcements => 'Announcements',
        NotificationHubSection.campaigns => 'Campaigns',
        NotificationHubSection.scheduled => 'Scheduled',
        NotificationHubSection.templates => 'Templates',
        NotificationHubSection.deliveryReports => 'Delivery Reports',
        NotificationHubSection.segments => 'User Segments',
        NotificationHubSection.history => 'History',
        NotificationHubSection.autoNotifications => 'Auto Notifications',
      };
}

enum ManagedNotificationType {
  announcement,
  match,
  tournament,
  system,
  community,
  discover,
  promotion,
  reminder,
  campaign;

  String get label => switch (this) {
        ManagedNotificationType.announcement => 'Announcement',
        ManagedNotificationType.match => 'Match',
        ManagedNotificationType.tournament => 'Tournament',
        ManagedNotificationType.system => 'System',
        ManagedNotificationType.community => 'Community',
        ManagedNotificationType.discover => 'Discover',
        ManagedNotificationType.promotion => 'Promotion',
        ManagedNotificationType.reminder => 'Reminder',
        ManagedNotificationType.campaign => 'Campaign',
      };

  String get wireValue => name;

  static ManagedNotificationType parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedNotificationType.system;
    for (final v in ManagedNotificationType.values) {
      if (v.name == raw) return v;
    }
    return ManagedNotificationType.system;
  }
}

enum ManagedNotificationStatus {
  draft,
  scheduled,
  sending,
  queued,
  sent,
  failed,
  cancelled,
  archived;

  String get label => switch (this) {
        ManagedNotificationStatus.draft => 'Draft',
        ManagedNotificationStatus.scheduled => 'Scheduled',
        ManagedNotificationStatus.sending => 'Sending',
        ManagedNotificationStatus.queued => 'Queued',
        ManagedNotificationStatus.sent => 'Sent',
        ManagedNotificationStatus.failed => 'Failed',
        ManagedNotificationStatus.cancelled => 'Cancelled',
        ManagedNotificationStatus.archived => 'Archived',
      };

  String get wireValue => name;

  static ManagedNotificationStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedNotificationStatus.draft;
    for (final v in ManagedNotificationStatus.values) {
      if (v.name == raw) return v;
    }
    return ManagedNotificationStatus.draft;
  }
}

enum ManagedNotificationAudience {
  everyone,
  country,
  state,
  city,
  followers,
  tournamentFollowers,
  teamFollowers,
  matchFollowers,
  playerFollowers,
  groundFollowers,
  players,
  scorers,
  communityMembers,
  admins,
  moderators,
  specificUsers,
  specificTeams,
  customList;

  String get label => switch (this) {
        ManagedNotificationAudience.everyone => 'Everyone',
        ManagedNotificationAudience.country => 'Country',
        ManagedNotificationAudience.state => 'State',
        ManagedNotificationAudience.city => 'City',
        ManagedNotificationAudience.followers => 'Followers',
        ManagedNotificationAudience.tournamentFollowers => 'Tournament Followers',
        ManagedNotificationAudience.teamFollowers => 'Team Followers',
        ManagedNotificationAudience.matchFollowers => 'Match Followers',
        ManagedNotificationAudience.playerFollowers => 'Player Followers',
        ManagedNotificationAudience.groundFollowers => 'Ground Followers',
        ManagedNotificationAudience.players => 'Players',
        ManagedNotificationAudience.scorers => 'Scorers',
        ManagedNotificationAudience.communityMembers => 'Community Members',
        ManagedNotificationAudience.admins => 'Admins',
        ManagedNotificationAudience.moderators => 'Moderators',
        ManagedNotificationAudience.specificUsers => 'Specific Users',
        ManagedNotificationAudience.specificTeams => 'Specific Teams',
        ManagedNotificationAudience.customList => 'Custom User List',
      };

  String get wireValue => name;

  static ManagedNotificationAudience parse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return ManagedNotificationAudience.everyone;
    }
    for (final v in ManagedNotificationAudience.values) {
      if (v.name == raw) return v;
    }
    return ManagedNotificationAudience.everyone;
  }
}

enum ManagedNotificationPriority {
  normal,
  high,
  critical;

  String get label => switch (this) {
        ManagedNotificationPriority.normal => 'Normal',
        ManagedNotificationPriority.high => 'High',
        ManagedNotificationPriority.critical => 'Critical',
      };

  String get wireValue => name;

  static ManagedNotificationPriority parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedNotificationPriority.normal;
    for (final v in ManagedNotificationPriority.values) {
      if (v.name == raw) return v;
    }
    return ManagedNotificationPriority.normal;
  }
}

enum ManagedNotificationSound {
  defaultSound,
  silent,
  custom;

  String get label => switch (this) {
        ManagedNotificationSound.defaultSound => 'Default',
        ManagedNotificationSound.silent => 'Silent',
        ManagedNotificationSound.custom => 'Custom',
      };

  String get wireValue => switch (this) {
        ManagedNotificationSound.defaultSound => 'default',
        ManagedNotificationSound.silent => 'silent',
        ManagedNotificationSound.custom => 'custom',
      };

  static ManagedNotificationSound parse(String? raw) {
    switch (raw) {
      case 'silent':
        return ManagedNotificationSound.silent;
      case 'custom':
        return ManagedNotificationSound.custom;
      default:
        return ManagedNotificationSound.defaultSound;
    }
  }
}

enum ManagedScheduleMode {
  immediate,
  later,
  recurring;

  String get label => switch (this) {
        ManagedScheduleMode.immediate => 'Send Immediately',
        ManagedScheduleMode.later => 'Schedule Later',
        ManagedScheduleMode.recurring => 'Recurring',
      };

  String get wireValue => name;

  static ManagedScheduleMode parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedScheduleMode.immediate;
    for (final v in ManagedScheduleMode.values) {
      if (v.name == raw) return v;
    }
    return ManagedScheduleMode.immediate;
  }
}

enum ManagedRecurrence {
  none,
  daily,
  weekly,
  monthly,
  yearly;

  String get label => switch (this) {
        ManagedRecurrence.none => 'None',
        ManagedRecurrence.daily => 'Daily',
        ManagedRecurrence.weekly => 'Weekly',
        ManagedRecurrence.monthly => 'Monthly',
        ManagedRecurrence.yearly => 'Yearly',
      };

  String get wireValue => name;

  static ManagedRecurrence parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedRecurrence.none;
    for (final v in ManagedRecurrence.values) {
      if (v.name == raw) return v;
    }
    return ManagedRecurrence.none;
  }
}

enum ManagedPlatformTarget {
  android,
  ios,
  web;

  String get label => switch (this) {
        ManagedPlatformTarget.android => 'Android',
        ManagedPlatformTarget.ios => 'iOS',
        ManagedPlatformTarget.web => 'Web',
      };

  String get wireValue => name;
}

enum NotificationSortField {
  createdAt,
  title,
  status,
  scheduledAt,
}

class NotificationSort {
  const NotificationSort({
    this.field = NotificationSortField.createdAt,
    this.descending = true,
  });

  final NotificationSortField field;
  final bool descending;

  NotificationSort toggle(NotificationSortField next) {
    if (field == next) {
      return NotificationSort(field: field, descending: !descending);
    }
    return NotificationSort(field: next, descending: true);
  }
}
