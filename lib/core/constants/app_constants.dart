class AppConstants {
  AppConstants._();

  static const String appName = 'CrickFlow';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';
  static const String defaultCountry = 'Sri Lanka';

  /// Brand logo for landscape stream overlay header.
  static const String crickflowLogoUrl =
      'https://crickflow-b06bc.web.app/assets/crickflow-logo.png';

  // Firestore collections
  static const String usersCollection = 'users';
  static const String teamsCollection = 'teams';
  static const String teamJoinRequestsSubcollection = 'join_requests';
  static const String playersCollection = 'players';
  static const String matchesCollection = 'matches';
  static const String tournamentsCollection = 'tournaments';
  static const String tournamentGroupsCollection = 'tournament_groups';
  static const String tournamentRoundsCollection = 'tournament_rounds';
  static const String tournamentPointsTablesCollection = 'tournament_points_tables';
  static const String tournamentOfficialsCollection = 'tournament_officials';
  static const String tournamentSponsorsCollection = 'tournament_sponsors';
  static const String tournamentRulesCollection = 'tournament_rules';
  static const String tournamentMembersCollection = 'tournament_members';
  static const String tournamentTeamRequestsCollection = 'tournament_team_requests';
  static const String ballEventsCollection = 'ball_events';
  static const String notificationsCollection = 'notifications';
  static const String badgesCollection = 'badges';
  static const String fantasyLeaguesCollection = 'fantasy_leagues';
  static const String fantasyEntriesCollection = 'entries';
  static const String communityPostsCollection = 'community_posts';
  static const String teamRosterReportsCollection = 'team_roster_reports';

  // Match defaults (standard cricket)
  static const int defaultOvers = 20;
  static const int defaultBallsPerOver = 6;
  static const int defaultWideRuns = 1;
  static const int defaultNoBallRuns = 1;
}
