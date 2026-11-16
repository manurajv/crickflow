class RelatedRecord {
  const RelatedRecord({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.occurredAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime? occurredAt;
}

class RelatedSection {
  const RelatedSection({this.items = const [], this.error});

  final List<RelatedRecord> items;
  final String? error;

  static const empty = RelatedSection();

  bool get hasError => error != null && error!.isNotEmpty;
  bool get isEmpty => !hasError && items.isEmpty;
}

class UserRelatedSnapshot {
  const UserRelatedSnapshot({
    this.teams = RelatedSection.empty,
    this.matches = RelatedSection.empty,
    this.tournaments = RelatedSection.empty,
    this.reports = RelatedSection.empty,
    this.communityPosts = RelatedSection.empty,
    this.opportunityPosts = RelatedSection.empty,
    this.notifications = RelatedSection.empty,
    this.lastLoginAt,
  });

  final RelatedSection teams;
  final RelatedSection matches;
  final RelatedSection tournaments;
  final RelatedSection reports;
  final RelatedSection communityPosts;
  final RelatedSection opportunityPosts;
  final RelatedSection notifications;
  final DateTime? lastLoginAt;
}

class TeamRelatedSnapshot {
  const TeamRelatedSnapshot({
    this.squad = RelatedSection.empty,
    this.matches = RelatedSection.empty,
    this.tournaments = RelatedSection.empty,
    this.reports = RelatedSection.empty,
    this.followersCount = 0,
  });

  final RelatedSection squad;
  final RelatedSection matches;
  final RelatedSection tournaments;
  final RelatedSection reports;
  final int followersCount;
}

class MatchRelatedSnapshot {
  const MatchRelatedSnapshot({
    this.teamAXi = const [],
    this.teamBXi = const [],
    this.teamAName = '',
    this.teamBName = '',
    this.officials = RelatedSection.empty,
    this.scorecard = RelatedSection.empty,
    this.stream = RelatedSection.empty,
    this.reports = RelatedSection.empty,
  });

  final List<String> teamAXi;
  final List<String> teamBXi;
  final String teamAName;
  final String teamBName;
  final RelatedSection officials;
  final RelatedSection scorecard;
  final RelatedSection stream;
  final RelatedSection reports;
}

class TournamentRelatedSnapshot {
  const TournamentRelatedSnapshot({
    this.teams = RelatedSection.empty,
    this.fixtures = RelatedSection.empty,
    this.reports = RelatedSection.empty,
    this.organizer = '',
  });

  final RelatedSection teams;
  final RelatedSection fixtures;
  final RelatedSection reports;
  final String organizer;
}

class GroundRelatedSnapshot {
  const GroundRelatedSnapshot({
    this.matches = RelatedSection.empty,
    this.tournaments = RelatedSection.empty,
    this.photoUrls = const [],
    this.matchesHosted = 0,
  });

  final RelatedSection matches;
  final RelatedSection tournaments;
  final List<String> photoUrls;
  final int matchesHosted;
}
