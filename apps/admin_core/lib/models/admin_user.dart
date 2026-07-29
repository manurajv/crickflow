import 'package:equatable/equatable.dart';

import 'admin_permission.dart';
import 'admin_role.dart';
import 'role_definition.dart';

/// Document shape for `admin_users/{uid}` (additive collection).
///
/// Permissions are resolved from `admin_roles/{roleId}` plus optional
/// [permissionOverrides]. Do not hardcode role checks in feature modules —
/// use [AdminPermission] via the session / route guard.
class AdminUser extends Equatable {
  const AdminUser({
    required this.uid,
    required this.email,
    required this.roleId,
    this.displayName,
    this.photoUrl,
    this.organizationId,
    this.organizationName,
    this.permissionOverrides = const {},
    this.isActive = true,
    this.claimsVersion = 0,
  });

  final String uid;
  final String email;

  /// Points at `admin_roles/{roleId}`. Prefer this over embedding permissions.
  final String roleId;
  final String? displayName;
  final String? photoUrl;

  /// Required for organization-scoped roles; null for Super Admin.
  final String? organizationId;
  final String? organizationName;

  /// Sparse overrides on top of the role definition (`permission → enabled`).
  final Map<String, bool> permissionOverrides;
  final bool isActive;

  /// Bumped when custom claims should be re-synced (Cloud Function later).
  final int claimsVersion;

  AdminRole? get knownRole => AdminRole.tryParse(roleId);

  String get roleLabel => knownRole?.label ?? roleId;

  bool get isSuperAdmin => knownRole == AdminRole.superAdmin;

  String get initials {
    final source =
        (displayName?.trim().isNotEmpty == true) ? displayName! : email;
    final parts = source.split(RegExp(r'\s+|@')).where((e) => e.isNotEmpty);
    if (parts.isEmpty) return '?';
    final list = parts.take(2).toList();
    return list.map((e) => e[0].toUpperCase()).join();
  }

  Set<AdminPermission> resolvePermissions(RoleDefinition role) {
    return AdminPermissionResolver.resolve(
      rolePermissions: role.permissions,
      overrides: permissionOverrides,
    );
  }

  factory AdminUser.fromMap(String uid, Map<String, dynamic> map) {
    final roleId = (map['roleId'] as String?) ??
        (map['platformRole'] as String?) ??
        (map['role'] as String?);
    if (roleId == null || roleId.isEmpty) {
      throw FormatException('admin_users/$uid missing roleId');
    }

    final overrides = <String, bool>{};
    final rawOverrides = map['permissionOverrides'] ?? map['permissions'];
    if (rawOverrides is Map) {
      rawOverrides.forEach((key, value) {
        if (value is bool) overrides[key.toString()] = value;
      });
    }

    // Legacy list grants/denies → overrides
    for (final g in (map['permissionGrants'] as List?)?.cast<String>() ?? []) {
      overrides[g] = true;
    }
    for (final d in (map['permissionDenies'] as List?)?.cast<String>() ?? []) {
      overrides[d] = false;
    }

    return AdminUser(
      uid: uid,
      email: (map['email'] as String?) ?? '',
      roleId: roleId,
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      organizationId: map['organizationId'] as String?,
      organizationName: map['organizationName'] as String?,
      permissionOverrides: overrides,
      isActive: map['isActive'] as bool? ?? true,
      claimsVersion: (map['claimsVersion'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'roleId': roleId,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'organizationId': organizationId,
        'organizationName': organizationName,
        'permissionOverrides': permissionOverrides,
        'isActive': isActive,
        'claimsVersion': claimsVersion,
      };

  @override
  List<Object?> get props => [
        uid,
        email,
        roleId,
        organizationId,
        isActive,
        claimsVersion,
      ];
}
