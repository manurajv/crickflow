class AppConstants {
  AppConstants._();

  static const String appName = 'CrickFlow';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';
  static const String defaultCountry = 'Sri Lanka';

  // Firestore collections
  static const String usersCollection = 'users';
  static const String teamsCollection = 'teams';
  static const String playersCollection = 'players';
  static const String matchesCollection = 'matches';
  static const String tournamentsCollection = 'tournaments';
  static const String ballEventsCollection = 'ball_events';
  static const String notificationsCollection = 'notifications';
  static const String badgesCollection = 'badges';
  static const String fantasyLeaguesCollection = 'fantasy_leagues';
  static const String fantasyEntriesCollection = 'entries';
  static const String communityPostsCollection = 'community_posts';

  // Match defaults (standard cricket)
  static const int defaultOvers = 20;
  static const int defaultBallsPerOver = 6;
  static const int defaultWideRuns = 1;
  static const int defaultNoBallRuns = 1;
}
