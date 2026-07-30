import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/admin_collections.dart';
import '../models/admin_role.dart';
import '../models/role_definition.dart';

/// Reads / manages `admin_roles/{roleId}` with built-in fallback definitions.
///
/// Client-side permission checks are UX only — enforce with Firestore rules
/// and (later) custom claims. Writes require Super Admin (see firestore.rules).
class AdminRoleService {
  AdminRoleService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AdminCollections.adminRoles);

  DocumentReference<Map<String, dynamic>> _doc(String roleId) =>
      _col.doc(roleId);

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

  /// Lists Firestore roles + ensures built-in catalog appears even if unseeded.
  Future<List<RoleDefinition>> listAll({bool includeArchived = false}) async {
    final byId = <String, RoleDefinition>{};
    for (final role in AdminRole.values) {
      byId[role.wireValue] = RoleDefinition.fallback(role);
    }
    try {
      final snap = await _col.limit(100).get();
      for (final d in snap.docs) {
        byId[d.id] = RoleDefinition.fromMap(d.id, d.data());
      }
    } catch (_) {
      // Use fallbacks only.
    }
    var list = byId.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    if (!includeArchived) {
      list = list.where((r) => !r.archived).toList();
    }
    return list;
  }

  Future<int> countUsersWithRole(String roleId) async {
    try {
      final agg = await _db
          .collection(AdminCollections.adminUsers)
          .where('roleId', isEqualTo: roleId)
          .count()
          .get();
      return agg.count ?? 0;
    } catch (_) {
      try {
        final snap = await _db
            .collection(AdminCollections.adminUsers)
            .where('roleId', isEqualTo: roleId)
            .limit(50)
            .get();
        return snap.docs.length;
      } catch (_) {
        return 0;
      }
    }
  }

  Future<void> saveRole(RoleDefinition role) async {
    await _doc(role.id).set(role.toSeedMap(), SetOptions(merge: true));
  }

  Future<RoleDefinition> duplicateRole(RoleDefinition source, String newId) async {
    final copy = source.copyWith(
      label: '${source.label} (copy)',
      isSystem: false,
      archived: false,
    );
    final data = copy.toSeedMap();
    // Use new id document.
    await _doc(newId).set({
      ...data,
      'label': copy.label,
      'isSystem': false,
    }, SetOptions(merge: true));
    return fetchById(newId);
  }

  Future<void> renameRole(String roleId, String label) async {
    await _doc(roleId).set({'label': label}, SetOptions(merge: true));
  }

  Future<void> archiveRole(String roleId) async {
    await _doc(roleId).set({
      'archived': true,
      'recordStatus': 'archived',
    }, SetOptions(merge: true));
  }

  /// Soft-delete only — never hard-deletes system roles from the client.
  Future<void> deleteRole(String roleId, {required bool isSystem}) async {
    if (isSystem) {
      await archiveRole(roleId);
      return;
    }
    await _doc(roleId).delete();
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
