import '../core/config/admin_app_type.dart';

/// Platform roles for CrickFlow admin web panels.
///
/// Distinct from mobile `users.role` (player/scorer/organizer/…).
/// Documented as `admin_users/{uid}.roleId` → `admin_roles/{roleId}`.
enum AdminRole {
  superAdmin,
  admin,
  moderator,
  tournamentAdmin,
  support,
  viewer;

  String get label => switch (this) {
        AdminRole.superAdmin => 'Super Admin',
        AdminRole.admin => 'Admin',
        AdminRole.moderator => 'Moderator',
        AdminRole.tournamentAdmin => 'Tournament Admin',
        AdminRole.support => 'Support',
        AdminRole.viewer => 'Viewer',
      };

  /// Firestore / API wire value (stable camelCase). Used as default [roleId].
  String get wireValue => name;

  /// Which admin panel this role may enter (none → Access Denied).
  AdminAppType? get allowedPanel => switch (this) {
        AdminRole.superAdmin => AdminAppType.superAdmin,
        AdminRole.admin => AdminAppType.organizationAdmin,
        AdminRole.moderator ||
        AdminRole.tournamentAdmin ||
        AdminRole.support ||
        AdminRole.viewer =>
          null,
      };

  bool canAccessPanel(AdminAppType panel) => allowedPanel == panel;

  static AdminRole? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.trim();
    for (final role in AdminRole.values) {
      if (role.name.toLowerCase() == normalized.toLowerCase()) return role;
      if (role.label.toLowerCase() == normalized.toLowerCase()) return role;
    }
    switch (normalized.toLowerCase()) {
      case 'superadmin':
      case 'super_admin':
        return AdminRole.superAdmin;
      case 'tournamentadmin':
      case 'tournament_admin':
        return AdminRole.tournamentAdmin;
      default:
        return null;
    }
  }
}
