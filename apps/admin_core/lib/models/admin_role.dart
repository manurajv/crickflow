/// Platform roles for CrickFlow admin web panels.
///
/// Distinct from mobile `users.role` (player/scorer/organizer/…).
/// Stored on `admin_users/{uid}.platformRole`.
enum AdminRole {
  superAdmin,
  admin,
  moderator,
  tournamentAdmin,
  support;

  String get label => switch (this) {
        AdminRole.superAdmin => 'Super Admin',
        AdminRole.admin => 'Admin',
        AdminRole.moderator => 'Moderator',
        AdminRole.tournamentAdmin => 'Tournament Admin',
        AdminRole.support => 'Support',
      };

  /// Firestore / API wire value (stable camelCase).
  String get wireValue => name;

  static AdminRole? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.trim();
    for (final role in AdminRole.values) {
      if (role.name.toLowerCase() == normalized.toLowerCase()) return role;
      if (role.label.toLowerCase() == normalized.toLowerCase()) return role;
    }
    // Aliases
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
