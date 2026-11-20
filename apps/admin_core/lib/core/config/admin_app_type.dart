/// Which web panel is running.
///
/// The Organization Admin panel was retired (organization / series
/// administration lives in the mobile app), so the Super Admin panel is the
/// only web admin app.
enum AdminAppType {
  /// Platform panel for CrickFlow staff — crickflow-superadmin.web.app
  superAdmin;

  String get displayName => switch (this) {
        AdminAppType.superAdmin => 'Super Admin',
      };

  String get hostHint => switch (this) {
        AdminAppType.superAdmin => 'crickflow-superadmin.web.app',
      };
}
