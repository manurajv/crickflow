/// Support Center hub sections and ticket domain enums.
enum SupportHubSection {
  dashboard,
  tickets,
  conversations,
  feedback,
  bugReports,
  featureRequests,
  contactRequests,
  knowledgeBase,
  faq,
  announcements,
  csat,
  reports;

  String get label => switch (this) {
        SupportHubSection.dashboard => 'Dashboard',
        SupportHubSection.tickets => 'Support Tickets',
        SupportHubSection.conversations => 'Live Conversations',
        SupportHubSection.feedback => 'Feedback',
        SupportHubSection.bugReports => 'Bug Reports',
        SupportHubSection.featureRequests => 'Feature Requests',
        SupportHubSection.contactRequests => 'Contact Requests',
        SupportHubSection.knowledgeBase => 'Knowledge Base',
        SupportHubSection.faq => 'FAQ Management',
        SupportHubSection.announcements => 'Announcements',
        SupportHubSection.csat => 'Customer Satisfaction',
        SupportHubSection.reports => 'Reports',
      };
}

enum SupportTicketCategory {
  support,
  bugReport,
  featureRequest,
  billing,
  advertisement,
  broadcast,
  streaming,
  tournament,
  match,
  scoring,
  community,
  discover,
  team,
  player,
  ground,
  account,
  authentication,
  notifications,
  contact,
  feedback,
  other;

  String get label => switch (this) {
        SupportTicketCategory.support => 'Support',
        SupportTicketCategory.bugReport => 'Bug Report',
        SupportTicketCategory.featureRequest => 'Feature Request',
        SupportTicketCategory.billing => 'Billing',
        SupportTicketCategory.advertisement => 'Advertisement',
        SupportTicketCategory.broadcast => 'Broadcast',
        SupportTicketCategory.streaming => 'Streaming',
        SupportTicketCategory.tournament => 'Tournament',
        SupportTicketCategory.match => 'Match',
        SupportTicketCategory.scoring => 'Scoring',
        SupportTicketCategory.community => 'Community',
        SupportTicketCategory.discover => 'Discover',
        SupportTicketCategory.team => 'Team',
        SupportTicketCategory.player => 'Player',
        SupportTicketCategory.ground => 'Ground',
        SupportTicketCategory.account => 'Account',
        SupportTicketCategory.authentication => 'Authentication',
        SupportTicketCategory.notifications => 'Notifications',
        SupportTicketCategory.contact => 'Contact',
        SupportTicketCategory.feedback => 'Feedback',
        SupportTicketCategory.other => 'Other',
      };

  String get wireValue => name;

  static SupportTicketCategory parse(String? raw) {
    if (raw == null || raw.isEmpty) return SupportTicketCategory.other;
    for (final v in values) {
      if (v.name == raw || v.wireValue == raw) return v;
    }
    return SupportTicketCategory.other;
  }
}

enum SupportTicketPriority {
  low,
  medium,
  high,
  critical;

  String get label => switch (this) {
        SupportTicketPriority.low => 'Low',
        SupportTicketPriority.medium => 'Medium',
        SupportTicketPriority.high => 'High',
        SupportTicketPriority.critical => 'Critical',
      };

  String get wireValue => name;

  static SupportTicketPriority parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return SupportTicketPriority.medium;
  }
}

enum SupportTicketStatus {
  open,
  assigned,
  inProgress,
  waitingForUser,
  waitingForInternal,
  resolved,
  closed,
  rejected,
  duplicate;

  String get label => switch (this) {
        SupportTicketStatus.open => 'Open',
        SupportTicketStatus.assigned => 'Assigned',
        SupportTicketStatus.inProgress => 'In Progress',
        SupportTicketStatus.waitingForUser => 'Waiting for User',
        SupportTicketStatus.waitingForInternal => 'Waiting for Internal Team',
        SupportTicketStatus.resolved => 'Resolved',
        SupportTicketStatus.closed => 'Closed',
        SupportTicketStatus.rejected => 'Rejected',
        SupportTicketStatus.duplicate => 'Duplicate',
      };

  String get wireValue => name;

  static SupportTicketStatus parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return SupportTicketStatus.open;
  }

  bool get isTerminal =>
      this == SupportTicketStatus.closed ||
      this == SupportTicketStatus.rejected ||
      this == SupportTicketStatus.duplicate ||
      this == SupportTicketStatus.resolved;
}

enum SupportTicketKind {
  support,
  bug,
  feature,
  feedback,
  contact;

  String get label => switch (this) {
        SupportTicketKind.support => 'Support',
        SupportTicketKind.bug => 'Bug Report',
        SupportTicketKind.feature => 'Feature Request',
        SupportTicketKind.feedback => 'Feedback',
        SupportTicketKind.contact => 'Contact',
      };

  String get wireValue => name;

  static SupportTicketKind parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return SupportTicketKind.support;
  }
}

enum SupportMessageVisibility {
  public,
  internal;

  String get wireValue => name;

  static SupportMessageVisibility parse(String? raw) {
    if (raw == 'internal') return SupportMessageVisibility.internal;
    return SupportMessageVisibility.public;
  }
}

enum SupportMessageAuthorType {
  user,
  agent,
  system;

  String get wireValue => name;

  static SupportMessageAuthorType parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return SupportMessageAuthorType.agent;
  }
}

enum FeatureRequestStatus {
  submitted,
  planned,
  inProgress,
  completed,
  rejected;

  String get label => switch (this) {
        FeatureRequestStatus.submitted => 'Submitted',
        FeatureRequestStatus.planned => 'Planned',
        FeatureRequestStatus.inProgress => 'In Progress',
        FeatureRequestStatus.completed => 'Completed',
        FeatureRequestStatus.rejected => 'Rejected',
      };

  String get wireValue => name;

  static FeatureRequestStatus parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return FeatureRequestStatus.submitted;
  }
}

enum SupportContentStatus {
  draft,
  published,
  archived;

  String get label => switch (this) {
        SupportContentStatus.draft => 'Draft',
        SupportContentStatus.published => 'Published',
        SupportContentStatus.archived => 'Archived',
      };

  String get wireValue => name;

  static SupportContentStatus parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return SupportContentStatus.draft;
  }
}

enum SupportAnnouncementType {
  knownIssue,
  scheduledMaintenance,
  serviceDisruption,
  resolvedIncident,
  general;

  String get label => switch (this) {
        SupportAnnouncementType.knownIssue => 'Known Issues',
        SupportAnnouncementType.scheduledMaintenance => 'Scheduled Maintenance',
        SupportAnnouncementType.serviceDisruption => 'Service Disruption',
        SupportAnnouncementType.resolvedIncident => 'Resolved Incidents',
        SupportAnnouncementType.general => 'General',
      };

  String get wireValue => name;

  static SupportAnnouncementType parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return SupportAnnouncementType.general;
  }
}

enum SupportSortField {
  createdAt,
  updatedAt,
  priority,
  status,
  subject;

  String get label => switch (this) {
        SupportSortField.createdAt => 'Created',
        SupportSortField.updatedAt => 'Updated',
        SupportSortField.priority => 'Priority',
        SupportSortField.status => 'Status',
        SupportSortField.subject => 'Subject',
      };
}

class SupportSort {
  const SupportSort({
    this.field = SupportSortField.updatedAt,
    this.descending = true,
  });

  final SupportSortField field;
  final bool descending;

  SupportSort toggle(SupportSortField next) {
    if (field == next) return SupportSort(field: next, descending: !descending);
    return SupportSort(field: next);
  }
}

enum SupportExportFormat { csv, excel, pdf }
