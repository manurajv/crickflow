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
