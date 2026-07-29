import 'package:equatable/equatable.dart';

import '../core/config/admin_app_type.dart';
import 'admin_permission.dart';
import 'admin_role.dart';

/// Document shape for `admin_roles/{roleId}`.
///
/// Changing permissions here updates every user with that [id] — no per-user
/// permission rewrites required.
class RoleDefinition extends Equatable {
  const RoleDefinition({
    required this.id,
    required this.label,
    required this.permissions,
    this.allowedPanel,
    this.description,
    this.isSystem = true,
  });

  final String id;
  final String label;
  final Map<String, bool> permissions;
  final AdminAppType? allowedPanel;
  final String? description;
  final bool isSystem;

  AdminRole? get knownRole => AdminRole.tryParse(id);

  Set<AdminPermission> get permissionSet =>
      AdminPermissionResolver.resolve(rolePermissions: permissions);

  bool get canAccessAnyAdminPanel => allowedPanel != null;

  bool canAccessPanel(AdminAppType panel) => allowedPanel == panel;

  factory RoleDefinition.fromMap(String id, Map<String, dynamic> map) {
    final rawPerms = map['permissions'];
    final perms = <String, bool>{};
    if (rawPerms is Map) {
      rawPerms.forEach((key, value) {
        if (value is bool) perms[key.toString()] = value;
      });
    }

    final known = AdminRole.tryParse(id) ??
        AdminRole.tryParse(map['roleKey'] as String?);

    AdminAppType? panel;
    final panelRaw = map['allowedPanel'] as String?;
    if (panelRaw == 'superAdmin') {
      panel = AdminAppType.superAdmin;
    } else if (panelRaw == 'organizationAdmin' || panelRaw == 'admin') {
      panel = AdminAppType.organizationAdmin;
    } else if (panelRaw == null && known != null) {
      panel = known.allowedPanel;
    }

    final label = (map['label'] as String?) ?? known?.label ?? id;
    final permissions = perms.isEmpty && known != null
        ? DefaultAdminRolePermissions.asPermissionMap(known)
        : perms;

    return RoleDefinition(
      id: id,
      label: label,
      permissions: permissions,
      allowedPanel: panel,
      description: map['description'] as String?,
      isSystem: map['isSystem'] as bool? ?? true,
    );
  }

  /// Offline / missing-doc fallback from the built-in catalog.
  factory RoleDefinition.fallback(AdminRole role) {
    return RoleDefinition(
      id: role.wireValue,
      label: role.label,
      permissions: DefaultAdminRolePermissions.asPermissionMap(role),
      allowedPanel: role.allowedPanel,
      description: 'Built-in fallback role definition',
      isSystem: true,
    );
  }

  Map<String, dynamic> toSeedMap() => {
        'label': label,
        'description': description,
        'allowedPanel': switch (allowedPanel) {
          AdminAppType.superAdmin => 'superAdmin',
          AdminAppType.organizationAdmin => 'organizationAdmin',
          null => 'none',
        },
        'permissions': permissions,
        'isSystem': isSystem,
      };

  @override
  List<Object?> get props => [id, label, permissions, allowedPanel];
}
