/// Additive Firestore collections used only by admin web panels.
///
/// These do **not** replace or alter mobile collections (`users`, `matches`, …).
abstract final class AdminCollections {
  /// Platform / org admin accounts keyed by Firebase Auth uid.
  static const adminUsers = 'admin_users';

  /// Role definitions with permission maps. Change once → all assignees update.
  static const adminRoles = 'admin_roles';

  /// Canonical org entities (boards, clubs, academies, …) — Super Admin CRUD.
  static const organizations = 'organizations';

  /// Immutable admin action audit trail.
  static const adminAuditLogs = 'admin_audit_logs';

  /// Mobile cricket profiles (read / limited admin updates of additive fields).
  static const users = 'users';

  /// Mobile tournaments (read / limited admin updates of additive fields).
  static const tournaments = 'tournaments';

  /// Mobile matches (read / limited admin updates of additive fields).
  static const matches = 'matches';

  /// Mobile teams (read / limited admin updates of additive fields).
  static const teams = 'teams';

  /// Optional grounds registry (admin materializes on first write).
  static const grounds = 'grounds';

  /// Mobile community social feed.
  static const communityPosts = 'community_posts';

  /// Mobile discover / opportunity marketplace.
  static const opportunityPosts = 'opportunity_posts';

  /// Community post / profile reports.
  static const communityPostReports = 'community_post_reports';

  /// Discover post reports.
  static const opportunityPostReports = 'opportunity_post_reports';

  /// Chat thread metadata only (never message bodies in admin).
  static const chats = 'chats';

  /// Mobile per-user inbox (admin monitors only — never FCM tokens).
  static const notifications = 'notifications';

  /// Home carousel ads + announcements (mobile reads; admin CRUD).
  static const homePromotions = 'home_promotions';

  /// Admin-created push / in-app notification campaigns (additive).
  static const adminNotificationCampaigns = 'admin_notification_campaigns';

  /// Reusable notification copy templates (additive).
  static const adminNotificationTemplates = 'admin_notification_templates';

  /// Saved audience segment definitions (additive, future fan-out).
  static const adminNotificationSegments = 'admin_notification_segments';

  /// Ad campaign / creative records (additive admin ads manager).
  static const adminAdCampaigns = 'admin_ad_campaigns';

  /// Advertiser company profiles (additive).
  static const adminAdvertisers = 'admin_advertisers';

  /// AdMob unit / placement config mirror (admin only — mobile AdMob unchanged).
  static const adminAdmobConfig = 'admin_admob_config';

  /// Sponsored entity promotions (tournament/team/post links).
  static const adminSponsoredContent = 'admin_sponsored_content';

  /// Platform settings singleton (`global` doc) — Super Admin writes.
  static const adminPlatformSettings = 'admin_platform_settings';

  /// Feature flag documents keyed by flag name.
  static const adminFeatureFlags = 'admin_feature_flags';

  /// Admin mirror of remote configuration keys (Firebase RC integration later).
  static const adminRemoteConfig = 'admin_remote_config';

  /// App version / force-update history.
  static const adminAppVersions = 'admin_app_versions';

  /// Maintenance mode config (`current` doc).
  static const adminMaintenance = 'admin_maintenance';

  /// CMS content pages (home, FAQ, onboarding, …).
  static const adminCmsPages = 'admin_cms_pages';

  /// Legal page *content* only — never stores or overwrites public policy URLs.
  static const adminLegalPages = 'admin_legal_pages';

  /// Support tickets (help desk) — additive; never community/private chats.
  static const adminSupportTickets = 'admin_support_tickets';

  /// Support knowledge-base articles.
  static const adminSupportKb = 'admin_support_kb';

  /// Support FAQ entries (separate from CMS FAQ page content).
  static const adminSupportFaqs = 'admin_support_faqs';

  /// Support announcements (known issues, maintenance, disruptions).
  static const adminSupportAnnouncements = 'admin_support_announcements';

  /// Support meta (ticket counters, SLA defaults).
  static const adminSupportMeta = 'admin_support_meta';

  /// AI recommendations queue (approve/reject — never auto-mutate).
  static const adminAiRecommendations = 'admin_ai_recommendations';

  /// AI automation rules (workflow-graph ready).
  static const adminAiRules = 'admin_ai_rules';

  /// AI batch / scheduled jobs (Cloud Function worker later).
  static const adminAiJobs = 'admin_ai_jobs';

  /// AI operations activity logs.
  static const adminAiLogs = 'admin_ai_logs';

  /// AI ops settings singleton (`global` doc) + feature-flag mirrors.
  static const adminAiSettings = 'admin_ai_settings';

  /// Security Center — alerts (failed logins, escalations, etc.).
  static const adminSecurityAlerts = 'admin_security_alerts';

  /// Block lists (users, devices, emails, IPs, domains).
  static const adminSecurityBlocks = 'admin_security_blocks';

  /// IP whitelist / blacklist / geo rules (metadata only).
  static const adminSecurityIps = 'admin_security_ips';

  /// Device registry (trusted / re-verify architecture).
  static const adminSecurityDevices = 'admin_security_devices';

  /// Temporary / emergency / read-only access grants.
  static const adminSecurityAccess = 'admin_security_access';

  /// Backup schedule metadata (never triggers Firebase backups from client).
  static const adminSecurityBackups = 'admin_security_backups';

  /// Restore points / history (preview only — no destructive restore).
  static const adminSecurityRestores = 'admin_security_restores';

  /// Optional session registry (terminate marks docs; Auth revoke later).
  static const adminSecuritySessions = 'admin_security_sessions';

  /// Security policies singleton (`global` doc).
  static const adminSecurityPolicies = 'admin_security_policies';
}
