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

  /// Fixed tab order. Length never changes when a tournament is finished.
  /// Summary sits next to Overview so completed events open on the result.
  static const List<TournamentDashboardSection> tabOrder = [
    overview,
    summary,
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

  /// Tabs visible in the dashboard. Summary is included only after completion.
  static List<TournamentDashboardSection> tabOrderForStatus(bool isCompleted) =>
      isCompleted
          ? tabOrder
          : tabOrder.where((s) => s != summary).toList(growable: false);

  static List<String> get labels =>
      tabOrder.map((section) => section.label).toList();

  static List<String> labelsForStatus(bool isCompleted) =>
      tabOrderForStatus(isCompleted).map((section) => section.label).toList();

  static int indexOfSection(
    TournamentDashboardSection section, {
    bool isCompleted = true,
  }) {
    final order = tabOrderForStatus(isCompleted);
    final index = order.indexOf(section);
    return index < 0 ? 0 : index;
  }

  /// Default landing: completed tournaments open on Summary unless another tab
  /// was requested (`?tab=` or `/tournaments/:id/{section}`).
  static TournamentDashboardSection landingSection({
    required bool isCompleted,
    required TournamentDashboardSection requested,
  }) {
    if (!isCompleted && requested == summary) return overview;
    if (isCompleted && requested == overview) return summary;
    return requested;
  }

  static TournamentDashboardSection fromSlug(String? slug) {
    if (slug == null || slug.isEmpty) return overview;
    for (final section in values) {
      if (section.slug == slug) return section;
    }
    return overview;
  }
}
