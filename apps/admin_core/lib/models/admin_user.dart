import 'package:equatable/equatable.dart';

import 'admin_permission.dart';
import 'admin_role.dart';

/// Document shape for `admin_users/{uid}` (additive collection).
class AdminUser extends Equatable {
  const AdminUser({
    required this.uid,
    required this.email,
    required this.platformRole,
    this.displayName,
    this.photoUrl,
    this.organizationId,
    this.organizationName,
    this.permissionGrants = const [],
    this.permissionDenies = const [],
    this.isActive = true,
  });

  final String uid;
  final String email;
  final AdminRole platformRole;
  final String? displayName;
  final String? photoUrl;

  /// Required for org-scoped roles; null for SuperAdmin.
  final String? organizationId;
  final String? organizationName;
  final List<String> permissionGrants;
  final List<String> permissionDenies;
  final bool isActive;

  Set<AdminPermission> get permissions => AdminPermissionCatalog.resolve(
        role: platformRole,
        grants: permissionGrants,
        denies: permissionDenies,
      );

  bool hasPermission(AdminPermission permission) =>
      isActive && permissions.contains(permission);

  bool get isSuperAdmin => platformRole == AdminRole.superAdmin;

  String get initials {
    final source = (displayName?.trim().isNotEmpty == true)
        ? displayName!
        : email;
    final parts = source.split(RegExp(r'\s+|@')).where((e) => e.isNotEmpty);
    if (parts.isEmpty) return '?';
    final list = parts.take(2).toList();
    return list.map((e) => e[0].toUpperCase()).join();
  }

  factory AdminUser.fromMap(String uid, Map<String, dynamic> map) {
    final role = AdminRole.tryParse(map['platformRole'] as String?) ??
        AdminRole.tryParse(map['role'] as String?);
    if (role == null) {
      throw FormatException('admin_users/$uid missing platformRole');
    }
    return AdminUser(
      uid: uid,
      email: (map['email'] as String?) ?? '',
      platformRole: role,
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      organizationId: map['organizationId'] as String?,
      organizationName: map['organizationName'] as String?,
      permissionGrants:
          (map['permissionGrants'] as List?)?.cast<String>() ?? const [],
      permissionDenies:
          (map['permissionDenies'] as List?)?.cast<String>() ?? const [],
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'platformRole': platformRole.wireValue,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'organizationId': organizationId,
        'organizationName': organizationName,
        'permissionGrants': permissionGrants,
        'permissionDenies': permissionDenies,
        'isActive': isActive,
      };

  @override
  List<Object?> get props => [
        uid,
        email,
        platformRole,
        organizationId,
        isActive,
      ];
}
