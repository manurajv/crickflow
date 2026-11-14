class PrefsKeys {
  PrefsKeys._();

  static const String onboardingComplete = 'onboarding_complete';
  static const String cachedUserProfile = 'cached_user_profile';
  static const String cachedPlayerId = 'cached_player_id';
  static const String cachedPlayerIdUid = 'cached_player_id_uid';
  static const String themeMode = 'theme_mode';
  static const String pendingProfileUpdate = 'pending_profile_update';
  static const String activeLiveStreamMatchId = 'active_live_stream_match_id';
  static const String communityLocationFilter = 'community_location_filter_v1';
  static const String communityHiddenPosts = 'community_hidden_posts_v1';

  /// User opted out of the org-admin welcome / permissions tip entirely.
  static String orgWelcomeNeverAsk(String uid) => 'org_welcome_never_$uid';

  /// Welcome tip already shown for this org (per user).
  static String orgWelcomeSeen(String uid, String seriesId) =>
      'org_welcome_seen_${uid}_$seriesId';
}
