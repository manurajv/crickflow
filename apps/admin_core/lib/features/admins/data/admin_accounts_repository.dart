import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/admin_collections.dart';
import '../../../models/admin_user.dart';
import '../../users/models/admin_audit_log.dart';
import '../models/admin_account.dart';

/// Audit action names for administrator access management.
abstract final class AdminAccessAuditActions {
  static const granted = 'admin.access_granted';
  static const updated = 'admin.access_updated';
  static const suspended = 'admin.suspended';
  static const reactivated = 'admin.reactivated';
  static const revoked = 'admin.revoked';
}

/// Super Admin management of `admin_users/{uid}` profiles.
///
/// Writes are allowed by Firestore rules for active Super Admins only. The
/// client never deletes admin profiles (rules deny delete); revoke flips
/// `isActive` off and records `accessStatus: revoked`.
class AdminAccountsRepository {
  AdminAccountsRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _admins =>
      _db.collection(AdminCollections.adminUsers);

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(AdminCollections.users);

  CollectionReference<Map<String, dynamic>> get _orgs =>
      _db.collection(AdminCollections.organizations);

  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  Future<List<AdminAccount>> listAll({int limit = 500}) async {
    final snap = await _admins.limit(limit).get();
    final list = snap.docs
        .map((d) => AdminAccount.fromMap(d.id, d.data()))
        .toList(growable: false);
    return list;
  }

  Future<List<AdminOrgOption>> listOrganizations({int limit = 500}) async {
    final snap = await _orgs.limit(limit).get();
    final list = <AdminOrgOption>[];
    for (final d in snap.docs) {
      final data = d.data();
      final record = (data['recordStatus'] as String?) ?? 'active';
      if (record == 'soft_deleted' || record == 'deleted') continue;
      final name = (data['name'] as String?)?.trim();
      list.add(
        AdminOrgOption(
          id: d.id,
          name: (name == null || name.isEmpty) ? d.id : name,
          status: data['status'] as String?,
        ),
      );
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Finds a person by Auth UID or email: existing admin profile first, then
  /// the mobile `users` profile. Returns null when nothing matches.
  Future<AdminCandidate?> resolveCandidate(String uidOrEmail) async {
    final key = uidOrEmail.trim();
    if (key.isEmpty) return null;
    final isEmail = key.contains('@');

    if (!isEmail) {
      final adminDoc = await _admins.doc(key).get();
      if (adminDoc.exists && adminDoc.data() != null) {
        return _fromAdminDoc(adminDoc.id, adminDoc.data()!);
      }
      final userDoc = await _users.doc(key).get();
      if (userDoc.exists && userDoc.data() != null) {
        return _fromUserDoc(userDoc.id, userDoc.data()!);
      }
      return null;
    }

    for (final email in {key, key.toLowerCase()}) {
      final adminSnap = await _admins
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (adminSnap.docs.isNotEmpty) {
        final d = adminSnap.docs.first;
        return _fromAdminDoc(d.id, d.data());
      }
    }
    for (final email in {key, key.toLowerCase()}) {
      final userSnap = await _users
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (userSnap.docs.isNotEmpty) {
        final d = userSnap.docs.first;
        // Profile may already have an admin doc under the same UID.
        final adminDoc = await _admins.doc(d.id).get();
        if (adminDoc.exists && adminDoc.data() != null) {
          return _fromAdminDoc(adminDoc.id, adminDoc.data()!);
        }
        return _fromUserDoc(d.id, d.data());
      }
    }
    return null;
  }

  AdminCandidate _fromAdminDoc(String uid, Map<String, dynamic> data) {
    final account = AdminAccount.fromMap(uid, data);
    return AdminCandidate(
      uid: uid,
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
      existing: account,
      source: 'admin_users',
    );
  }

  AdminCandidate _fromUserDoc(String uid, Map<String, dynamic> data) {
    final name = (data['displayName'] as String?)?.trim().isNotEmpty == true
        ? data['displayName'] as String
        : (data['name'] as String?);
    return AdminCandidate(
      uid: uid,
      email: (data['email'] as String?) ?? '',
      displayName: name,
      photoUrl: (data['photoUrl'] as String?) ?? (data['photoURL'] as String?),
      source: 'users',
    );
  }

  /// Creates or updates an admin profile with [roleId] and optional org scope.
  Future<void> saveAccess({
    required String uid,
    required String email,
    required String? displayName,
    required String? photoUrl,
    required String roleId,
    required AdminOrgOption? organization,
    required Map<String, bool> permissionOverrides,
    required AdminUser actor,
    required bool isNew,
    String? reason,
  }) async {
    final now = DateTime.now().toIso8601String();
    final data = <String, dynamic>{
      'email': email.trim(),
      'displayName': (displayName?.trim().isEmpty ?? true)
          ? null
          : displayName!.trim(),
      'roleId': roleId,
      'organizationId': organization?.id,
      'organizationName': organization?.name,
      'permissionOverrides': permissionOverrides,
      'claimsVersion': FieldValue.increment(1),
      'updatedAt': now,
      'updatedBy': actor.uid,
    };
    if (photoUrl != null && photoUrl.isNotEmpty) data['photoUrl'] = photoUrl;
    if (isNew) {
      data.addAll({
        'isActive': true,
        'accessStatus': AdminAccessStatus.active.wireValue,
        'statusReason': null,
        'createdAt': now,
        'createdBy': actor.uid,
      });
    }

    // mergeFields replaces each listed field wholesale, so cleared
    // permission overrides are removed instead of deep-merged.
    await _admins
        .doc(uid)
        .set(data, SetOptions(mergeFields: data.keys.toList()));

    await _writeAudit(
      action: isNew
          ? AdminAccessAuditActions.granted
          : AdminAccessAuditActions.updated,
      actor: actor,
      targetUid: uid,
      targetEmail: email,
      reason: reason,
      metadata: {
        'roleId': roleId,
        'organizationId': organization?.id ?? '',
        'overrideCount': permissionOverrides.length,
      },
    );
  }

  Future<void> setStatus({
    required AdminAccount target,
    required AdminAccessStatus status,
    required AdminUser actor,
    String? reason,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _admins.doc(target.uid).set({
      'isActive': status.grantsAccess,
      'accessStatus': status.wireValue,
      'statusReason': (reason?.trim().isEmpty ?? true) ? null : reason!.trim(),
      'statusChangedAt': now,
      'statusChangedBy': actor.uid,
      'claimsVersion': FieldValue.increment(1),
      'updatedAt': now,
      'updatedBy': actor.uid,
    }, SetOptions(merge: true));

    await _writeAudit(
      action: switch (status) {
        AdminAccessStatus.active => AdminAccessAuditActions.reactivated,
        AdminAccessStatus.suspended => AdminAccessAuditActions.suspended,
        AdminAccessStatus.revoked => AdminAccessAuditActions.revoked,
      },
      actor: actor,
      targetUid: target.uid,
      targetEmail: target.email,
      reason: reason,
      metadata: {
        'roleId': target.roleId,
        'previousStatus': target.status.wireValue,
      },
    );
  }

  Future<void> _writeAudit({
    required String action,
    required AdminUser actor,
    required String targetUid,
    required String targetEmail,
    String? reason,
    Map<String, dynamic> metadata = const {},
  }) async {
    final entry = AdminAuditLogEntry(
      id: '',
      action: action,
      actorUid: actor.uid,
      actorEmail: actor.email,
      targetUid: targetUid,
      targetEmail: targetEmail,
      timestamp: DateTime.now(),
      reason: reason,
      metadata: {...metadata, 'entity': 'admin_user'},
    );
    await _audit.add(entry.toMap());
  }
}
