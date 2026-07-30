/// Shared foundation for CrickFlow Super Admin and Organization Admin web panels.
///
/// This package does **not** modify the mobile app or existing Firestore schemas.
/// Admin roles live in additive `admin_users` + `admin_roles` collections.
library;

// Config
export 'core/config/admin_app_type.dart';
export 'core/config/firebase_bootstrap.dart';
export 'core/constants/admin_collections.dart';
export 'core/constants/breakpoints.dart';

// Theme
export 'core/theme/admin_colors.dart';
export 'core/theme/admin_theme.dart';
export 'core/theme/theme_mode_provider.dart';
export 'core/extensions/context_extensions.dart';

// Models & permissions
export 'models/admin_role.dart';
export 'models/admin_permission.dart';
export 'models/admin_user.dart';
export 'models/role_definition.dart';
export 'models/nav_models.dart';

// Services
export 'services/auth_service.dart';
export 'services/admin_user_service.dart';
export 'services/admin_role_service.dart';
export 'services/session_preferences.dart';

// Providers
export 'features/auth/providers/auth_providers.dart';
export 'features/shell/providers/shell_providers.dart';

// Router
export 'core/router/auth_redirect.dart';
export 'core/router/go_router_refresh.dart';
export 'core/router/admin_route_paths.dart';
export 'core/router/admin_route_permissions.dart';

// Shell / layout
export 'features/shell/presentation/admin_shell.dart';
export 'features/shell/presentation/widgets/admin_sidebar.dart';

// Auth screens
export 'features/auth/presentation/login_screen.dart';
export 'features/auth/presentation/access_denied_screen.dart';
export 'features/auth/presentation/profile_screens.dart';

// Dashboard
export 'features/dashboard/presentation/dashboard_screen.dart';
export 'features/dashboard/models/dashboard_models.dart';
export 'features/dashboard/providers/dashboard_providers.dart';
export 'features/shell/presentation/module_placeholder_screen.dart';

// User Management
export 'features/users/presentation/users_screen.dart';
export 'features/users/providers/users_providers.dart';
export 'features/users/models/managed_user.dart';
export 'features/users/models/user_account_status.dart';
export 'features/users/models/user_filters.dart';
export 'features/users/models/admin_audit_log.dart';

// Tournament Management
export 'features/tournaments/presentation/tournaments_screen.dart';
export 'features/tournaments/providers/tournaments_providers.dart';
export 'features/tournaments/models/managed_tournament.dart';
export 'features/tournaments/models/tournament_enums.dart';
export 'features/tournaments/models/tournament_filters.dart';

// Match Management
export 'features/matches/presentation/matches_screen.dart';
export 'features/matches/providers/matches_providers.dart';
export 'features/matches/models/managed_match.dart';
export 'features/matches/models/match_enums.dart' hide ManagedBallType;
export 'features/matches/models/match_filters.dart';

// Team Management
export 'features/teams/presentation/teams_screen.dart';
export 'features/teams/providers/teams_providers.dart';
export 'features/teams/models/managed_team.dart';
export 'features/teams/models/team_enums.dart';
export 'features/teams/models/team_filters.dart';

// Organization Management
export 'features/organizations/presentation/organizations_screen.dart';
export 'features/organizations/providers/organizations_providers.dart';
export 'features/organizations/models/managed_organization.dart';
export 'features/organizations/models/organization_enums.dart';
export 'features/organizations/models/organization_filters.dart';

// Ground Management
export 'features/grounds/presentation/grounds_screen.dart';
export 'features/grounds/providers/grounds_providers.dart';
export 'features/grounds/models/managed_ground.dart';
export 'features/grounds/models/ground_enums.dart';
export 'features/grounds/models/ground_filters.dart';

// Broadcast Management
export 'features/broadcasts/presentation/broadcasts_screen.dart';
export 'features/broadcasts/providers/broadcasts_providers.dart';
export 'features/broadcasts/models/managed_broadcast.dart';
export 'features/broadcasts/models/broadcast_enums.dart';
export 'features/broadcasts/models/broadcast_filters.dart';

// Community & Discover Moderation
export 'features/moderation/presentation/moderation_screen.dart';
export 'features/moderation/providers/moderation_providers.dart';
export 'features/moderation/models/managed_moderation.dart';
export 'features/moderation/models/moderation_enums.dart';
export 'features/moderation/models/moderation_filters.dart';

// Notification & Announcement Management
export 'features/notifications/presentation/notifications_screen.dart';
export 'features/notifications/providers/notifications_providers.dart';
export 'features/notifications/models/managed_notification.dart';
export 'features/notifications/models/notification_enums.dart';
export 'features/notifications/models/notification_filters.dart';

// Advertisement Management
export 'features/ads/presentation/ads_screen.dart';
export 'features/ads/providers/ads_providers.dart';
export 'features/ads/models/managed_ads.dart';
export 'features/ads/models/ads_enums.dart';
export 'features/ads/models/ads_filters.dart';

// Analytics & Reports
export 'features/analytics/presentation/analytics_screen.dart';
export 'features/analytics/providers/analytics_providers.dart';
export 'features/analytics/models/analytics_models.dart';
export 'features/analytics/models/analytics_enums.dart';
export 'features/analytics/models/analytics_filters.dart';

// System Monitoring & Platform Health
export 'features/monitoring/presentation/monitoring_screen.dart';
export 'features/monitoring/providers/monitoring_providers.dart';
export 'features/monitoring/models/monitoring_models.dart';
export 'features/monitoring/models/monitoring_enums.dart';
export 'features/monitoring/models/monitoring_filters.dart';

// Support Center & Ticket Management
export 'features/support/presentation/support_screen.dart';
export 'features/support/providers/support_providers.dart';
export 'features/support/models/managed_support.dart';
export 'features/support/models/support_enums.dart';
export 'features/support/models/support_filters.dart';

// AI Operations & Automation Center
export 'features/ai_ops/presentation/ai_ops_screen.dart';
export 'features/ai_ops/providers/ai_ops_providers.dart';
export 'features/ai_ops/models/managed_ai_ops.dart';
export 'features/ai_ops/models/ai_ops_enums.dart';
export 'features/ai_ops/models/ai_ops_filters.dart';
export 'features/ai_ops/data/ai_provider_adapter.dart';

// Security Operations Center (SOC)
export 'features/security/presentation/security_screen.dart';
export 'features/security/providers/security_providers.dart';
export 'features/security/models/managed_security.dart';
export 'features/security/models/security_enums.dart';
export 'features/security/models/security_filters.dart';

// CMS & Platform Settings
export 'features/settings/presentation/settings_screen.dart';
export 'features/settings/providers/settings_providers.dart';
export 'features/settings/models/platform_settings.dart';
export 'features/settings/models/settings_enums.dart';

// Audit Logs & Activity Monitoring
export 'features/audit/presentation/audit_screen.dart';
export 'features/audit/providers/audit_providers.dart';
export 'features/audit/models/audit_log_view.dart';
export 'features/audit/models/audit_enums.dart';
export 'features/audit/models/audit_filters.dart';
export 'features/audit/data/audit_logger.dart';

// Shared widgets
export 'shared/widgets/cf_card.dart';
export 'shared/widgets/cf_button.dart';
export 'shared/widgets/cf_dialog.dart';
export 'shared/widgets/cf_search_bar.dart';
export 'shared/widgets/cf_filter_sheet.dart';
export 'shared/widgets/cf_data_table.dart';
export 'shared/widgets/cf_empty_state.dart';
export 'shared/widgets/cf_loading_state.dart';
export 'shared/widgets/cf_pagination.dart';
export 'shared/widgets/cf_chart_placeholder.dart';
export 'shared/widgets/cf_stat_tile.dart';
export 'core/widgets/permission_gate.dart';
