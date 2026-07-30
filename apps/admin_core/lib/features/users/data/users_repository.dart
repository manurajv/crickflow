import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/constants/admin_collections.dart';
import '../../../core/constants/admin_query_limits.dart';
import '../../../models/admin_role.dart';
import '../../../models/admin_user.dart';
import '../models/admin_audit_log.dart';
import '../models/managed_user.dart';
import '../models/user_account_status.dart';
import '../models/user_filters.dart';

/// Reads / updates CrickFlow `users` with additive admin fields only.
///
/// Does not change mobile auth. Org admins are scoped by `organizationId`.
class UsersRepository {
  UsersRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(AdminCollections.users);

  CollectionReference<Map<String, dynamic>> get _adminUsers =>
      _db.collection(AdminCollections.adminUsers);

  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  Future<UserPageResult> fetchPage({
    required AdminAppType appType,
    required AdminUser? actor,
    required UserListFilters filters,
    required UserSort sort,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    Query<Map<String, dynamic>> query = _users;

    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) {
        return const UserPageResult(users: [], hasMore: false);
      }
      query = query.where('organizationId', isEqualTo: orgId);
    }

    // Server-side filters that map cleanly to Firestore.
    if (filters.statuses.length == 1) {
      query = query.where(
        'accountStatus',
        isEqualTo: filters.statuses.first.wireValue,
      );
    }
    if (filters.verified != null) {
      query = query.where('adminVerified', isEqualTo: filters.verified);
    }
    if (filters.country != null && filters.country!.trim().isNotEmpty) {
      query = query.where('country', isEqualTo: filters.country!.trim());
    }

    final q = filters.query.trim();
    if (q.isNotEmpty) {
      if (q.contains('@')) {
        query = query.where('email', isEqualTo: q.toLowerCase());
      } else if (RegExp(r'^CF\d+', caseSensitive: false).hasMatch(q)) {
        query = query.where('playerId', isEqualTo: q.toUpperCase());
      } else {
        // Prefix search on displayName (requires index when combined with filters).
        query = query
            .orderBy('displayName')
            .startAt([q]).endAt(['$q\uf8ff']);
      }
    } else {
      switch (sort.field) {
        case UserSortField.name:
          query = query.orderBy('displayName', descending: sort.descending);
        case UserSortField.email:
          query = query.orderBy('email', descending: sort.descending);
        case UserSortField.country:
          query = query.orderBy('country', descending: sort.descending);
        case UserSortField.lastLoginAt:
          query = query.orderBy('lastLoginAt', descending: sort.descending);
        case UserSortField.joinedAt:
          query = query.orderBy('createdAt', descending: sort.descending);
      }
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await query.limit(limit + 1).get();
    } on FirebaseException {
      // Fallback: unfiltered page by document id if composite index missing.
      var fallback = _users.orderBy(FieldPath.documentId).limit(limit + 1);
      if (appType == AdminAppType.organizationAdmin &&
          actor?.organizationId != null) {
        fallback = _users
            .where('organizationId', isEqualTo: actor!.organizationId)
            .limit(limit + 1);
      }
      snap = await fallback.get();
    }

    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;

    final adminRoleMap = await _loadAdminRoles(pageDocs.map((d) => d.id));

    var users = pageDocs
        .map(
          (d) => ManagedUser.fromFirestore(
            id: d.id,
            map: d.data(),
            adminRole: adminRoleMap[d.id],
          ),
        )
        .toList();

    users = _applyClientFilters(users, filters);

    return UserPageResult(
      users: users,
      hasMore: hasMore,
      cursor: pageDocs.isEmpty ? null : pageDocs.last,
    );
  }

  List<ManagedUser> _applyClientFilters(
    List<ManagedUser> users,
    UserListFilters filters,
  ) {
    Iterable<ManagedUser> list = users;

    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty && !q.contains('@') && !RegExp(r'^cf\d+').hasMatch(q)) {
      list = list.where((u) {
        return u.effectiveName.toLowerCase().contains(q) ||
            u.username.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            (u.playerId?.toLowerCase().contains(q) ?? false) ||
            (u.phoneNumber?.toLowerCase().contains(q) ?? false) ||
            (u.currentTeamName?.toLowerCase().contains(q) ?? false) ||
            u.country.toLowerCase().contains(q);
      });
    }

    if (filters.statuses.isNotEmpty) {
      list = list.where((u) => filters.statuses.contains(u.accountStatus));
    } else {
      // Soft-deleted accounts stay in Firestore but stay out of the default list.
      list = list.where((u) => !u.isSoftDeleted);
    }
    if (filters.adminRoles.isNotEmpty) {
      list = list.where(
        (u) => u.adminRole != null && filters.adminRoles.contains(u.adminRole),
      );
    }
    if (filters.stateProvince?.trim().isNotEmpty == true) {
      final s = filters.stateProvince!.trim().toLowerCase();
      list = list.where((u) => u.stateProvince.toLowerCase().contains(s));
    }
    if (filters.city?.trim().isNotEmpty == true) {
      final c = filters.city!.trim().toLowerCase();
      list = list.where((u) => u.city.toLowerCase().contains(c));
    }
    if (filters.gender?.trim().isNotEmpty == true) {
      final g = filters.gender!.trim().toLowerCase();
      list = list.where((u) => (u.gender ?? '').toLowerCase() == g);
    }
    if (filters.joinedFrom != null) {
      list = list.where(
        (u) =>
            u.createdAt != null &&
            !u.createdAt!.isBefore(filters.joinedFrom!),
      );
    }
    if (filters.joinedTo != null) {
      list = list.where(
        (u) =>
            u.createdAt != null && !u.createdAt!.isAfter(filters.joinedTo!),
      );
    }
    if (filters.lastLoginFrom != null) {
      list = list.where(
        (u) =>
            u.lastLoginAt != null &&
            !u.lastLoginAt!.isBefore(filters.lastLoginFrom!),
      );
    }
    if (filters.lastLoginTo != null) {
      list = list.where(
        (u) =>
            u.lastLoginAt != null &&
            !u.lastLoginAt!.isAfter(filters.lastLoginTo!),
      );
    }

    return list.toList();
  }

  Future<Map<String, AdminRole>> _loadAdminRoles(Iterable<String> uids) async {
    final ids = uids.toList();
    if (ids.isEmpty) return {};
    final result = <String, AdminRole>{};
    // Firestore whereIn limit 30
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap = await _adminUsers
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final role = AdminRole.tryParse(doc.data()['roleId'] as String?) ??
            AdminRole.tryParse(doc.data()['platformRole'] as String?);
        if (role != null) result[doc.id] = role;
      }
    }
    return result;
  }

  Future<ManagedUser?> fetchById(
    String uid, {
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    if (!_visibleToActor(snap.data()!, appType: appType, actor: actor)) {
      return null;
    }
    final roles = await _loadAdminRoles([uid]);
    return ManagedUser.fromFirestore(
      id: uid,
      map: snap.data()!,
      adminRole: roles[uid],
    );
  }

  Stream<ManagedUser?> watchById(
    String uid, {
    required AdminAppType appType,
    required AdminUser? actor,
  }) {
    return _users.doc(uid).snapshots().asyncMap((snap) async {
      if (!snap.exists || snap.data() == null) return null;
      if (!_visibleToActor(snap.data()!, appType: appType, actor: actor)) {
        return null;
      }
      final roles = await _loadAdminRoles([uid]);
      return ManagedUser.fromFirestore(
        id: uid,
        map: snap.data()!,
        adminRole: roles[uid],
      );
    });
  }

  bool _visibleToActor(
    Map<String, dynamic> map, {
    required AdminAppType appType,
    required AdminUser? actor,
  }) {
    if (appType != AdminAppType.organizationAdmin) return true;
    final orgId = actor?.organizationId;
    if (orgId == null || orgId.isEmpty) return false;
    return map['organizationId'] == orgId;
  }

  Future<UserSummaryStats> fetchSummary({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    Query<Map<String, dynamic>> base = _users;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) return const UserSummaryStats();
      base = base.where('organizationId', isEqualTo: orgId);
    }

    // Count via limited reads — placeholders when aggregation unavailable.
    try {
      final snap = await base.limit(AdminQueryLimits.summaryScanMax).get();
      final users = snap.docs
          .map((d) => ManagedUser.fromFirestore(id: d.id, map: d.data()))
          .toList();
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final onlineCutoff = now.subtract(const Duration(minutes: 15));

      final adminSnap = appType == AdminAppType.superAdmin
          ? await _adminUsers.limit(200).get()
          : await _adminUsers
              .where('organizationId', isEqualTo: actor?.organizationId)
              .limit(200)
              .get();

      final activeUsers =
          users.where((u) => !u.isSoftDeleted).toList(growable: false);

      return UserSummaryStats(
        total: activeUsers.length,
        verified: activeUsers.where((u) => u.adminVerified).length,
        online: activeUsers
            .where(
              (u) =>
                  u.lastLoginAt != null &&
                  u.lastLoginAt!.isAfter(onlineCutoff),
            )
            .length,
        newToday: activeUsers
            .where(
              (u) =>
                  u.createdAt != null && !u.createdAt!.isBefore(startOfDay),
            )
            .length,
        suspended: activeUsers
            .where((u) => u.accountStatus == UserAccountStatus.suspended)
            .length,
        admins: adminSnap.docs.length,
      );
    } catch (_) {
      return const UserSummaryStats();
    }
  }

  /// Soft account lifecycle update — never deletes the `users` document.
  ///
  /// Soft-delete sets `accountStatus: deleted` plus `deletedAt` / `deletedBy`.
  /// Restore clears those fields and returns the account to [UserAccountStatus.active].
  Future<void> updateAccountStatus({
    required ManagedUser target,
    required UserAccountStatus status,
    required AdminUser actor,
    String? reason,
  }) async {
    final now = DateTime.now().toIso8601String();
    final data = <String, dynamic>{
      'accountStatus': status.wireValue,
      // Alias kept for dashboards / future tooling that expect `status`.
      'status': status.wireValue,
      'updatedAt': now,
    };

    if (status == UserAccountStatus.deleted) {
      data['deletedAt'] = now;
      data['deletedBy'] = actor.uid;
    } else if (target.isSoftDeleted || target.deletedAt != null) {
      // Leaving soft-deleted state — drop markers (restore / reclassify).
      data['deletedAt'] = FieldValue.delete();
      data['deletedBy'] = FieldValue.delete();
    }

    await _users.doc(target.id).set(data, SetOptions(merge: true));

    final action = switch (status) {
      UserAccountStatus.suspended => AdminAuditActions.userSuspended,
      UserAccountStatus.banned => AdminAuditActions.userBanned,
      UserAccountStatus.deleted => AdminAuditActions.userDeleted,
      UserAccountStatus.active => target.isSoftDeleted
          ? AdminAuditActions.userRestored
          : target.accountStatus == UserAccountStatus.banned
              ? AdminAuditActions.userUnbanned
              : AdminAuditActions.userUnsuspended,
      UserAccountStatus.pendingVerification => AdminAuditActions.userEdited,
      UserAccountStatus.inactive => AdminAuditActions.userEdited,
    };
    await _writeAudit(
      action: action,
      actor: actor,
      target: target,
      reason: reason,
      metadata: {
        'status': status.wireValue,
        'softDelete': status == UserAccountStatus.deleted,
      },
    );
  }

  /// Convenience alias — soft-deletes only (see [updateAccountStatus]).
  Future<void> softDeleteUser({
    required ManagedUser target,
    required AdminUser actor,
    String? reason,
  }) {
    return updateAccountStatus(
      target: target,
      status: UserAccountStatus.deleted,
      actor: actor,
      reason: reason,
    );
  }

  /// Restores a soft-deleted account (preserves match / team history).
  Future<void> restoreUser({
    required ManagedUser target,
    required AdminUser actor,
    String? reason,
  }) {
    return updateAccountStatus(
      target: target,
      status: UserAccountStatus.active,
      actor: actor,
      reason: reason,
    );
  }

  Future<void> setVerified({
    required ManagedUser target,
    required bool verified,
    required AdminUser actor,
    String? reason,
  }) async {
    await _users.doc(target.id).set({
      'adminVerified': verified,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: verified
          ? AdminAuditActions.userVerified
          : AdminAuditActions.userUnverified,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> updateBasicInfo({
    required ManagedUser target,
    required AdminUser actor,
    String? displayName,
    String? phoneNumber,
    String? bio,
    String? country,
    String? stateProvince,
    String? city,
    String? reason,
  }) async {
    final location = <String, dynamic>{};
    if (country != null) location['country'] = country;
    if (stateProvince != null) location['stateProvince'] = stateProvince;
    if (city != null) location['city'] = city;

    await _users.doc(target.id).set({
      'displayName': ?displayName,
      'mobile': ?phoneNumber,
      'phoneNumber': ?phoneNumber,
      'bio': ?bio,
      'country': ?country,
      if (location.isNotEmpty) 'location': location,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    await _writeAudit(
      action: AdminAuditActions.userEdited,
      actor: actor,
      target: target,
      reason: reason,
      metadata: {
        'displayName': ?displayName,
        'phone': ?phoneNumber,
      },
    );
  }

  Future<void> sendPasswordReset({
    required ManagedUser target,
    required AdminUser actor,
    String? reason,
  }) async {
    if (target.email.isEmpty) {
      throw StateError('User has no email for password reset');
    }
    await _auth.sendPasswordResetEmail(email: target.email);
    await _writeAudit(
      action: AdminAuditActions.userPasswordReset,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  /// Creates / updates additive `admin_users` role (does not change mobile role).
  Future<void> setAdminRole({
    required ManagedUser target,
    required AdminRole? role,
    required AdminUser actor,
    String? organizationId,
    String? reason,
  }) async {
    final ref = _adminUsers.doc(target.id);
    if (role == null || role == AdminRole.viewer) {
      final existing = await ref.get();
      if (existing.exists) {
        await ref.set({
          'roleId': AdminRole.viewer.wireValue,
          'isActive': false,
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }
    } else {
      await ref.set({
        'email': target.email,
        'displayName': target.effectiveName,
        'photoUrl': target.photoUrl,
        'roleId': role.wireValue,
        'organizationId': organizationId ??
            (role == AdminRole.superAdmin ? null : actor.organizationId),
        'organizationName': actor.organizationName,
        'permissionOverrides': {},
        'isActive': true,
        'claimsVersion': FieldValue.increment(1),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    }

    await _writeAudit(
      action: AdminAuditActions.userRoleChanged,
      actor: actor,
      target: target,
      reason: reason,
      metadata: {
        'roleId': role?.wireValue ?? 'none',
      },
    );
  }

  Future<List<AdminAuditLogEntry>> fetchAuditForUser(String uid,
      {int limit = 40}) async {
    try {
      final snap = await _audit
          .where('targetUid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => AdminAuditLogEntry.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<UserActivityItem>> fetchActivityTimeline(ManagedUser user) async {
    // Built from known user fields + audit until dedicated activity feed exists.
    final items = <UserActivityItem>[];
    if (user.createdAt != null) {
      items.add(
        UserActivityItem(
          id: 'joined',
          title: 'Joined CrickFlow',
          subtitle: 'Account created',
          occurredAt: user.createdAt!,
          iconKey: 'joined',
        ),
      );
    }
    if (user.onboardingCompleted) {
      items.add(
        UserActivityItem(
          id: 'onboarded',
          title: 'Completed profile setup',
          subtitle: user.playerId ?? 'Player profile ready',
          occurredAt: user.updatedAt ?? user.createdAt ?? DateTime.now(),
          iconKey: 'profile',
        ),
      );
    }
    if (user.lastLoginAt != null) {
      items.add(
        UserActivityItem(
          id: 'login',
          title: 'Last login',
          subtitle: 'Recorded on profile',
          occurredAt: user.lastLoginAt!,
          iconKey: 'login',
        ),
      );
    }
    final audits = await fetchAuditForUser(user.id, limit: 20);
    for (final a in audits) {
      items.add(
        UserActivityItem(
          id: a.id,
          title: a.action,
          subtitle: a.reason ?? a.actorEmail,
          occurredAt: a.timestamp,
          iconKey: 'audit',
        ),
      );
    }
    items.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return items;
  }

  Future<void> _writeAudit({
    required String action,
    required AdminUser actor,
    required ManagedUser target,
    String? reason,
    Map<String, dynamic> metadata = const {},
  }) async {
    final entry = AdminAuditLogEntry(
      id: '',
      action: action,
      actorUid: actor.uid,
      actorEmail: actor.email,
      targetUid: target.id,
      targetEmail: target.email,
      timestamp: DateTime.now(),
      reason: reason,
      metadata: metadata,
    );
    await _audit.add(entry.toMap());
  }
}
