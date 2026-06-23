/// Tournament dashboard tab order, labels, and route slugs.
enum TournamentDashboardSection {
  overview,
  matches,
  leaderboard,
  pointsTable,
  stats,
  teams,
  groups,
  fixtures,
  officials,
  sponsors,
  heroes,
  rules,
  settings;

  String get label => switch (this) {
        overview => 'Overview',
        matches => 'Matches',
        leaderboard => 'Leaderboard',
        pointsTable => 'Points Table',
        stats => 'Stats',
        teams => 'Teams',
        groups => 'Groups',
        fixtures => 'Fixtures',
        officials => 'Officials',
        sponsors => 'Sponsors',
        heroes => 'Heroes',
        rules => 'Rules',
        settings => 'Settings',
      };

  /// URL segment under `/tournaments/:id/…`.
  String get slug => switch (this) {
        overview => 'overview',
        matches => 'matches',
        leaderboard => 'leaderboard',
        pointsTable => 'points-table',
        stats => 'stats',
        teams => 'teams',
        groups => 'groups',
        fixtures => 'fixtures',
        officials => 'officials',
        sponsors => 'sponsors',
        heroes => 'heroes',
        rules => 'rules',
        settings => 'settings',
      };

  static const List<TournamentDashboardSection> tabOrder = [
    overview,
    matches,
    leaderboard,
    pointsTable,
    stats,
    teams,
    groups,
    fixtures,
    officials,
    sponsors,
    heroes,
    rules,
    settings,
  ];

  static List<String> get labels =>
      tabOrder.map((section) => section.label).toList();

  static TournamentDashboardSection fromSlug(String? slug) {
    if (slug == null || slug.isEmpty) return overview;
    for (final section in values) {
      if (section.slug == slug) return section;
    }
    return overview;
  }
}
