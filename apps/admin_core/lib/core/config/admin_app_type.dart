/// Which web panel is running.
enum AdminAppType {
  /// Platform owner panel — superadmin.crickflow.app
  superAdmin,

  /// Organization panel — admin.crickflow.app
  organizationAdmin;

  String get displayName => switch (this) {
        AdminAppType.superAdmin => 'Super Admin',
        AdminAppType.organizationAdmin => 'Admin',
      };

  String get hostHint => switch (this) {
        AdminAppType.superAdmin => 'superadmin.crickflow.app',
        AdminAppType.organizationAdmin => 'admin.crickflow.app',
      };
}
