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
  settings,
  summary;

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
        summary => 'Summary',
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
        summary => 'summary',
      };

  /// Base tab order (without Summary — added dynamically for completed tournaments).
  static const List<TournamentDashboardSection> _baseTabOrder = [
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

  static const List<TournamentDashboardSection> tabOrder = _baseTabOrder;

  /// Tab order including Summary (appended at end for completed tournaments).
  static List<TournamentDashboardSection> tabOrderForStatus(
    bool isCompleted,
  ) {
    if (!isCompleted) return _baseTabOrder;
    return [..._baseTabOrder, summary];
  }

  static List<String> get labels =>
      tabOrder.map((section) => section.label).toList();

  static List<String> labelsForStatus(bool isCompleted) =>
      tabOrderForStatus(isCompleted).map((s) => s.label).toList();

  static TournamentDashboardSection fromSlug(String? slug) {
    if (slug == null || slug.isEmpty) return overview;
    for (final section in values) {
      if (section.slug == slug) return section;
    }
    return overview;
  }
}
