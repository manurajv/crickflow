import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_permission.dart';
import '../../../models/admin_role.dart';
import '../../../models/admin_user.dart';
import '../../../services/admin_user_service.dart';
import '../../../services/auth_service.dart';

final adminAppTypeProvider = Provider<AdminAppType>((ref) {
  throw UnimplementedError('Override adminAppTypeProvider in each app');
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final adminUserServiceProvider =
    Provider<AdminUserService>((ref) => AdminUserService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// Resolves the additive admin profile for the signed-in user.
final adminUserProvider = StreamProvider<AdminUser?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(adminUserServiceProvider).watchByUid(user.uid);
    },
    loading: () => const Stream.empty(),
    error: (_, _) => Stream.value(null),
  );
});

/// High-level session used by GoRouter redirects.
enum AdminSessionStatus {
  loading,
  unauthenticated,
  noAdminProfile,
  inactive,
  wrongPanel,
  authorized,
}

class AdminSession {
  const AdminSession({
    required this.status,
    this.firebaseUser,
    this.adminUser,
  });

  final AdminSessionStatus status;
  final User? firebaseUser;
  final AdminUser? adminUser;

  bool get isAuthorized => status == AdminSessionStatus.authorized;
}

final adminSessionProvider = Provider<AdminSession>((ref) {
  final authAsync = ref.watch(authStateProvider);
  final adminAsync = ref.watch(adminUserProvider);
  final appType = ref.watch(adminAppTypeProvider);

  if (authAsync.isLoading) {
    return const AdminSession(status: AdminSessionStatus.loading);
  }

  final user = authAsync.asData?.value;
  if (user == null) {
    return const AdminSession(status: AdminSessionStatus.unauthenticated);
  }

  if (adminAsync.isLoading) {
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

  if (!admin.isActive) {
    return AdminSession(
      status: AdminSessionStatus.inactive,
      firebaseUser: user,
      adminUser: admin,
    );
  }

  final allowed = _rolesForPanel(appType);
  if (!allowed.contains(admin.platformRole)) {
    return AdminSession(
      status: AdminSessionStatus.wrongPanel,
      firebaseUser: user,
      adminUser: admin,
    );
  }

  // Org admins must never access global platform data via missing org id.
  if (appType == AdminAppType.organizationAdmin &&
      admin.platformRole != AdminRole.superAdmin &&
      (admin.organizationId == null || admin.organizationId!.isEmpty)) {
    return AdminSession(
      status: AdminSessionStatus.noAdminProfile,
      firebaseUser: user,
      adminUser: admin,
    );
  }

  return AdminSession(
    status: AdminSessionStatus.authorized,
    firebaseUser: user,
    adminUser: admin,
  );
});

Set<AdminRole> _rolesForPanel(AdminAppType type) => switch (type) {
      AdminAppType.superAdmin => {AdminRole.superAdmin},
      AdminAppType.organizationAdmin => {
          AdminRole.admin,
          AdminRole.moderator,
          AdminRole.tournamentAdmin,
          AdminRole.support,
        },
    };

final permissionCheckerProvider = Provider<PermissionChecker>((ref) {
  final session = ref.watch(adminSessionProvider);
  return PermissionChecker(session.adminUser);
});

class PermissionChecker {
  const PermissionChecker(this.user);

  final AdminUser? user;

  bool can(AdminPermission permission) =>
      user?.hasPermission(permission) ?? false;

  bool canAny(Iterable<AdminPermission> permissions) =>
      permissions.any(can);

  bool canAll(Iterable<AdminPermission> permissions) =>
      permissions.every(can);
}
