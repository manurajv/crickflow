import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/admin_collections.dart';
import '../models/admin_role.dart';
import '../models/role_definition.dart';

/// Reads `admin_roles/{roleId}` with built-in fallback definitions.
///
/// Client-side permission checks are UX only — enforce with Firestore rules
/// and (later) custom claims.
class AdminRoleService {
  AdminRoleService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String roleId) =>
      _db.collection(AdminCollections.adminRoles).doc(roleId);

  Future<RoleDefinition> fetchById(String roleId) async {
    try {
      final snap = await _doc(roleId).get();
      if (snap.exists && snap.data() != null) {
        return RoleDefinition.fromMap(roleId, snap.data()!);
      }
    } catch (_) {
      // Fall through to built-in catalog (offline / rules not deployed yet).
    }
    return _fallback(roleId);
  }

  Stream<RoleDefinition> watchById(String roleId) {
    return _doc(roleId).snapshots().map((snap) {
      if (snap.exists && snap.data() != null) {
        return RoleDefinition.fromMap(roleId, snap.data()!);
      }
      return _fallback(roleId);
    });
  }

  RoleDefinition _fallback(String roleId) {
    final known = AdminRole.tryParse(roleId);
    if (known != null) return RoleDefinition.fallback(known);
    return RoleDefinition(
      id: roleId,
      label: roleId,
      permissions: const {},
      allowedPanel: null,
      description: 'Unknown role — no admin panel access',
      isSystem: false,
    );
  }

  /// Seed maps for Firestore Console / admin bootstrap scripts.
  static Map<String, Map<String, dynamic>> seedDocuments() {
    return {
      for (final role in AdminRole.values)
        role.wireValue: RoleDefinition.fallback(role).toSeedMap(),
    };
  }
}
