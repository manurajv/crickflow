import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_permission.dart';
import '../../../models/admin_role.dart';
import '../../../models/admin_user.dart';
import '../../../models/role_definition.dart';
import '../../../services/admin_role_service.dart';
import '../../../services/admin_user_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/session_preferences.dart';

final adminAppTypeProvider = Provider<AdminAppType>((ref) {
  throw UnimplementedError('Override adminAppTypeProvider in each app');
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final sessionPreferencesProvider =
    Provider<SessionPreferences>((ref) => SessionPreferences());

final adminUserServiceProvider =
    Provider<AdminUserService>((ref) => AdminUserService());

final adminRoleServiceProvider =
    Provider<AdminRoleService>((ref) => AdminRoleService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// Tracks ID token refreshes (custom claims preparation).
final idTokenProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).idTokenChanges();
});

/// Stream that stays open with no events so [StreamProvider] remains loading.
Stream<T> _pendingStream<T>() => Stream<T>.multi((_) {});

/// Resolves the additive admin profile for the signed-in user.
final adminUserProvider = StreamProvider<AdminUser?>((ref) {
  final authAsync = ref.watch(authStateProvider);
  // Never use Stream.empty() here — it completes immediately and looks like
  // "no admin profile", flashing Access Denied before Firestore responds.
  if (authAsync.isLoading) {
    return _pendingStream<AdminUser?>();
  }
  final user = authAsync.asData?.value;
  if (user == null) {
    return Stream.value(null);
  }
  return ref.watch(adminUserServiceProvider).watchByUid(user.uid);
});

final roleDefinitionProvider = StreamProvider<RoleDefinition?>((ref) {
  final adminAsync = ref.watch(adminUserProvider);
  if (adminAsync.isLoading || (!adminAsync.hasValue && !adminAsync.hasError)) {
    return _pendingStream<RoleDefinition?>();
  }
  final admin = adminAsync.asData?.value;
  if (admin == null) {
    return Stream.value(null);
  }
  return ref.watch(adminRoleServiceProvider).watchById(admin.roleId);
});

/// High-level session used by GoRouter redirects.
enum AdminSessionStatus {
  loading,
  unauthenticated,
  noAdminProfile,
  inactive,
  unauthorizedRole,
  wrongPanel,
  authorized,
}

class AdminSession {
  const AdminSession({
    required this.status,
    this.firebaseUser,
    this.adminUser,
    this.role,
    this.permissions = const {},
    this.customClaims = const {},
  });

  final AdminSessionStatus status;
  final User? firebaseUser;
  final AdminUser? adminUser;
  final RoleDefinition? role;
  final Set<AdminPermission> permissions;
  final Map<String, dynamic> customClaims;

  bool get isAuthorized => status == AdminSessionStatus.authorized;

  bool hasPermission(AdminPermission permission) =>
      isAuthorized && permissions.contains(permission);
}

final adminSessionProvider = Provider<AdminSession>((ref) {
  // Keep session in sync with token refresh (claims may appear later).
  ref.watch(idTokenProvider);

  final authAsync = ref.watch(authStateProvider);
  final adminAsync = ref.watch(adminUserProvider);
  final roleAsync = ref.watch(roleDefinitionProvider);
  final appType = ref.watch(adminAppTypeProvider);

  if (authAsync.isLoading || (!authAsync.hasValue && !authAsync.hasError)) {
    return const AdminSession(status: AdminSessionStatus.loading);
  }

  final user = authAsync.asData?.value;
  if (user == null) {
    return const AdminSession(status: AdminSessionStatus.unauthenticated);
  }

  // Wait until admin + role streams have settled (not still loading / pending).
  final adminPending =
      adminAsync.isLoading || (!adminAsync.hasValue && !adminAsync.hasError);
  if (adminPending) {
    return AdminSession(
      status: AdminSessionStatus.loading,
      firebaseUser: user,
    );
  }

  final admin = adminAsync.asData?.value;
  if (admin == null) {
    return AdminSession(
      status: AdminSessionStatus.noAdminProfile,
      firebaseUser: user,
    );
  }

  final rolePending =
      roleAsync.isLoading || (!roleAsync.hasValue && !roleAsync.hasError);
  if (rolePending) {
    return AdminSession(
      status: AdminSessionStatus.loading,
      firebaseUser: user,
      adminUser: admin,
    );
  }

  if (!admin.isActive) {
    return AdminSession(
      status: AdminSessionStatus.inactive,
      firebaseUser: user,
      adminUser: admin,
    );
  }

  final role = roleAsync.asData?.value ??
      (AdminRole.tryParse(admin.roleId) != null
          ? RoleDefinition.fallback(AdminRole.tryParse(admin.roleId)!)
          : null);

  if (role == null || !role.canAccessAnyAdminPanel) {
    return AdminSession(
      status: AdminSessionStatus.unauthorizedRole,
      firebaseUser: user,
      adminUser: admin,
      role: role,
    );
  }

  if (!role.canAccessPanel(appType)) {
    return AdminSession(
      status: AdminSessionStatus.wrongPanel,
      firebaseUser: user,
      adminUser: admin,
      role: role,
      permissions: admin.resolvePermissions(role),
    );
  }

  // Org admins must be scoped to an organization.
  if (appType == AdminAppType.organizationAdmin &&
      (admin.organizationId == null || admin.organizationId!.isEmpty)) {
    return AdminSession(
      status: AdminSessionStatus.noAdminProfile,
      firebaseUser: user,
      adminUser: admin,
      role: role,
    );
  }

  // Prefer custom claims when present (server-backed). Fall back to Firestore.
  // Cloud Functions can later mirror roleId + permissions into token claims.
  final permissions = admin.resolvePermissions(role);

  return AdminSession(
    status: AdminSessionStatus.authorized,
    firebaseUser: user,
    adminUser: admin,
    role: role,
    permissions: permissions,
  );
});

final permissionCheckerProvider = Provider<PermissionChecker>((ref) {
  final session = ref.watch(adminSessionProvider);
  return PermissionChecker(session);
});

class PermissionChecker {
  const PermissionChecker(this.session);

  final AdminSession session;

  bool can(AdminPermission permission) => session.hasPermission(permission);

  bool canAny(Iterable<AdminPermission> permissions) =>
      permissions.any(can);

  bool canAll(Iterable<AdminPermission> permissions) =>
      permissions.every(can);
}
