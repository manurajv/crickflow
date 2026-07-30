/// Hub sections for Platform Settings & CMS.
enum SettingsHubSection {
  dashboard,
  general,
  branding,
  remoteConfig,
  featureFlags,
  appVersions,
  maintenance,
  cms,
  legal,
  contact,
  social,
  apiConfig,
  firebaseConfig,
  backup,
  systemPrefs,
  auditLog;

  String get label => switch (this) {
        SettingsHubSection.dashboard => 'Dashboard',
        SettingsHubSection.general => 'General',
        SettingsHubSection.branding => 'Branding',
        SettingsHubSection.remoteConfig => 'Remote Config',
        SettingsHubSection.featureFlags => 'Feature Flags',
        SettingsHubSection.appVersions => 'App Versions',
        SettingsHubSection.maintenance => 'Maintenance',
        SettingsHubSection.cms => 'CMS',
        SettingsHubSection.legal => 'Legal Pages',
        SettingsHubSection.contact => 'Contact',
        SettingsHubSection.social => 'Social Media',
        SettingsHubSection.apiConfig => 'API Config',
        SettingsHubSection.firebaseConfig => 'Firebase',
        SettingsHubSection.backup => 'Backup',
        SettingsHubSection.systemPrefs => 'System Prefs',
        SettingsHubSection.auditLog => 'Audit Log',
      };

  /// CMS-focused sections for the dedicated `/cms` route.
  static const cmsFocused = [
    SettingsHubSection.cms,
    SettingsHubSection.legal,
    SettingsHubSection.contact,
    SettingsHubSection.social,
  ];
}

enum FeatureFlagKey {
  liveStreaming,
  broadcastOverlay,
  community,
  discover,
  playerRankings,
  groundBooking,
  fantasyCricket,
  subscriptions,
  premiumFeatures,
  advertisements,
  aiFeatures,
  analytics;

  String get label => switch (this) {
        FeatureFlagKey.liveStreaming => 'Live Streaming',
        FeatureFlagKey.broadcastOverlay => 'Broadcast Overlay',
        FeatureFlagKey.community => 'Community',
        FeatureFlagKey.discover => 'Discover',
        FeatureFlagKey.playerRankings => 'Player Rankings',
        FeatureFlagKey.groundBooking => 'Ground Booking',
        FeatureFlagKey.fantasyCricket => 'Fantasy Cricket',
        FeatureFlagKey.subscriptions => 'Subscriptions',
        FeatureFlagKey.premiumFeatures => 'Premium Features',
        FeatureFlagKey.advertisements => 'Advertisements',
        FeatureFlagKey.aiFeatures => 'AI Features',
        FeatureFlagKey.analytics => 'Analytics',
      };

  String get wireValue => name;

  String get description => switch (this) {
        FeatureFlagKey.liveStreaming => 'Enable live match streaming',
        FeatureFlagKey.broadcastOverlay => 'Scorebug / burn-in overlays',
        FeatureFlagKey.community => 'Community social feed',
        FeatureFlagKey.discover => 'Discover marketplace',
        FeatureFlagKey.playerRankings => 'Player ranking boards',
        FeatureFlagKey.groundBooking => 'Ground booking flows',
        FeatureFlagKey.fantasyCricket => 'Fantasy cricket (future)',
        FeatureFlagKey.subscriptions => 'Subscription plans (future)',
        FeatureFlagKey.premiumFeatures => 'Premium gated features',
        FeatureFlagKey.advertisements => 'In-app advertisements',
        FeatureFlagKey.aiFeatures => 'AI-powered insights (future)',
        FeatureFlagKey.analytics => 'In-app analytics surfaces',
      };
}

enum RemoteConfigValueType { string, number, boolean, json }

enum AppPlatform { android, ios, both }

enum VersionUpdateType { soft, force, none }

enum MaintenanceBypassRole { superAdmin, admin, moderator }

enum CmsPageKind {
  home,
  welcome,
  onboarding,
  aboutUs,
  faq,
  helpCenter,
  support,
  updateNotes;

  String get label => switch (this) {
        CmsPageKind.home => 'Home Page Content',
        CmsPageKind.welcome => 'Welcome Messages',
        CmsPageKind.onboarding => 'Onboarding Content',
        CmsPageKind.aboutUs => 'About Us',
        CmsPageKind.faq => 'FAQ',
        CmsPageKind.helpCenter => 'Help Center',
        CmsPageKind.support => 'Support Information',
        CmsPageKind.updateNotes => 'App Update Notes',
      };

  String get wireValue => name;
}

enum LegalPageKind {
  privacyPolicy,
  termsAndConditions,
  cookiePolicy,
  communityGuidelines,
  contentPolicy,
  refundPolicy;

  String get label => switch (this) {
        LegalPageKind.privacyPolicy => 'Privacy Policy',
        LegalPageKind.termsAndConditions => 'Terms & Conditions',
        LegalPageKind.cookiePolicy => 'Cookie Policy',
        LegalPageKind.communityGuidelines => 'Community Guidelines',
        LegalPageKind.contentPolicy => 'Content Policy',
        LegalPageKind.refundPolicy => 'Refund Policy (Future)',
      };

  String get wireValue => name;

  /// Existing public URLs must never be overwritten by this module.
  bool get urlLocked =>
      this == LegalPageKind.privacyPolicy ||
      this == LegalPageKind.termsAndConditions;
}

enum ApiServiceKind {
  googleMaps,
  firebase,
  youtube,
  facebook,
  admob,
  storage,
  cloudFunctions,
  authentication;

  String get label => switch (this) {
        ApiServiceKind.googleMaps => 'Google Maps',
        ApiServiceKind.firebase => 'Firebase',
        ApiServiceKind.youtube => 'YouTube',
        ApiServiceKind.facebook => 'Facebook',
        ApiServiceKind.admob => 'AdMob',
        ApiServiceKind.storage => 'Storage',
        ApiServiceKind.cloudFunctions => 'Cloud Functions',
        ApiServiceKind.authentication => 'Authentication',
      };
}

enum ServiceHealthStatus { enabled, disabled, healthy, error, unknown }

enum FirebaseServiceKind {
  authentication,
  firestore,
  storage,
  functions,
  hosting,
  analytics,
  messaging,
  appCheck,
  remoteConfig,
  performance;

  String get label => switch (this) {
        FirebaseServiceKind.authentication => 'Authentication',
        FirebaseServiceKind.firestore => 'Firestore',
        FirebaseServiceKind.storage => 'Storage',
        FirebaseServiceKind.functions => 'Functions',
        FirebaseServiceKind.hosting => 'Hosting',
        FirebaseServiceKind.analytics => 'Analytics',
        FirebaseServiceKind.messaging => 'Cloud Messaging',
        FirebaseServiceKind.appCheck => 'App Check',
        FirebaseServiceKind.remoteConfig => 'Remote Config',
        FirebaseServiceKind.performance => 'Performance',
      };
}

enum PlatformEnvironment { development, staging, production }

extension PlatformEnvironmentLabel on PlatformEnvironment {
  String get label => switch (this) {
        PlatformEnvironment.development => 'Development',
        PlatformEnvironment.staging => 'Staging',
        PlatformEnvironment.production => 'Production',
      };
}
