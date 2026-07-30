/// Moderation content source.
enum ModerationSource {
  community,
  discover,
  report,
  chat,
}

enum ManagedPostAdminStatus {
  published,
  pending,
  hidden,
  removed,
  reported,
  archived;

  String get label => switch (this) {
        ManagedPostAdminStatus.published => 'Published',
        ManagedPostAdminStatus.pending => 'Pending',
        ManagedPostAdminStatus.hidden => 'Hidden',
        ManagedPostAdminStatus.removed => 'Removed',
        ManagedPostAdminStatus.reported => 'Reported',
        ManagedPostAdminStatus.archived => 'Archived',
      };

  String get wireValue => name;

  static ManagedPostAdminStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedPostAdminStatus.published;
    for (final v in ManagedPostAdminStatus.values) {
      if (v.name == raw || v.wireValue == raw) return v;
    }
    // Discover mobile statuses
    switch (raw) {
      case 'active':
        return ManagedPostAdminStatus.published;
      case 'expired':
        return ManagedPostAdminStatus.archived;
      case 'removed':
        return ManagedPostAdminStatus.removed;
      default:
        return ManagedPostAdminStatus.published;
    }
  }
}

enum ManagedReportStatus {
  pending,
  reviewing,
  resolved,
  dismissed;

  String get label => switch (this) {
        ManagedReportStatus.pending => 'Pending',
        ManagedReportStatus.reviewing => 'Reviewing',
        ManagedReportStatus.resolved => 'Resolved',
        ManagedReportStatus.dismissed => 'Dismissed',
      };

  String get wireValue => name;

  static ManagedReportStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedReportStatus.pending;
    for (final v in ManagedReportStatus.values) {
      if (v.name == raw) return v;
    }
    return ManagedReportStatus.pending;
  }
}

enum ManagedReportTargetType {
  post,
  comment,
  user,
  chatMessage,
  team,
  tournament,
  ground,
  match,
  other;

  String get label => switch (this) {
        ManagedReportTargetType.post => 'Post',
        ManagedReportTargetType.comment => 'Comment',
        ManagedReportTargetType.user => 'User',
        ManagedReportTargetType.chatMessage => 'Chat message',
        ManagedReportTargetType.team => 'Team',
        ManagedReportTargetType.tournament => 'Tournament',
        ManagedReportTargetType.ground => 'Ground',
        ManagedReportTargetType.match => 'Match',
        ManagedReportTargetType.other => 'Other',
      };
}

enum ModerationHubSection {
  overview,
  community,
  discover,
  reports,
  reportedUsers,
  tournamentPosts,
  chats,
  media,
  queue,
  trending;

  String get label => switch (this) {
        ModerationHubSection.overview => 'Overview',
        ModerationHubSection.community => 'Posts',
        ModerationHubSection.discover => 'Posts',
        ModerationHubSection.reports => 'Reported Content',
        ModerationHubSection.reportedUsers => 'Reported Users',
        ModerationHubSection.tournamentPosts => 'Tournament Posts',
        ModerationHubSection.chats => 'Chats',
        ModerationHubSection.media => 'Media Library',
        ModerationHubSection.queue => 'Queue',
        ModerationHubSection.trending => 'Trending',
      };
}

/// Which admin product surface this screen belongs to.
///
/// Keeps Community / Discover / shared Moderation visually separate while
/// reusing the same repository and actions.
enum ModerationSurface {
  community,
  discover,
  queue;

  String get title => switch (this) {
        ModerationSurface.community => 'Community',
        ModerationSurface.discover => 'Discover',
        ModerationSurface.queue => 'Moderation',
      };

  String get subtitle => switch (this) {
        ModerationSurface.community =>
          'Moderate community feed posts, tournament promos, and media',
        ModerationSurface.discover =>
          'Moderate opportunity / looking-for posts from Discover',
        ModerationSurface.queue =>
          'Shared reports queue, chat metadata, and trending content',
      };

  String get breadcrumbRoot => title;

  ModerationHubSection get defaultSection => switch (this) {
        ModerationSurface.community => ModerationHubSection.community,
        ModerationSurface.discover => ModerationHubSection.discover,
        ModerationSurface.queue => ModerationHubSection.overview,
      };

  List<ModerationHubSection> get sections => switch (this) {
        ModerationSurface.community => const [
            ModerationHubSection.community,
            ModerationHubSection.tournamentPosts,
            ModerationHubSection.media,
            ModerationHubSection.queue,
            ModerationHubSection.reports,
          ],
        ModerationSurface.discover => const [
            ModerationHubSection.discover,
            ModerationHubSection.reports,
            ModerationHubSection.queue,
          ],
        ModerationSurface.queue => const [
            ModerationHubSection.overview,
            ModerationHubSection.reports,
            ModerationHubSection.reportedUsers,
            ModerationHubSection.chats,
            ModerationHubSection.trending,
            ModerationHubSection.queue,
          ],
      };

  /// Community-only report lists on Community; Discover-only on Discover;
  /// both on the shared queue.
  ModerationSource? get reportSourceFilter => switch (this) {
        ModerationSurface.community => ModerationSource.community,
        ModerationSurface.discover => ModerationSource.discover,
        ModerationSurface.queue => null,
      };
}

enum ModerationSortField {
  createdAt,
  likes,
  comments,
  reports,
  author,
}

class ModerationSort {
  const ModerationSort({
    this.field = ModerationSortField.createdAt,
    this.descending = true,
  });

  final ModerationSortField field;
  final bool descending;

  ModerationSort toggle(ModerationSortField next) {
    if (field == next) {
      return ModerationSort(field: field, descending: !descending);
    }
    return ModerationSort(field: next, descending: true);
  }
}
