/// Additive Firestore collections used only by admin web panels.
///
/// These do **not** replace or alter mobile collections (`users`, `matches`, …).
abstract final class AdminCollections {
  /// Platform / org admin accounts keyed by Firebase Auth uid.
  static const adminUsers = 'admin_users';

  /// Future: organizations managed by org admins.
  static const organizations = 'organizations';
}
