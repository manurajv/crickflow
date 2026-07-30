import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/admin_collections.dart';
import '../../../core/constants/admin_query_limits.dart';
import '../../../models/admin_role.dart';
import '../../../models/admin_user.dart';
import '../../users/models/admin_audit_log.dart';
import '../models/managed_organization.dart';
import '../models/organization_enums.dart';
import '../models/organization_filters.dart';

/// CRUD + related counts for admin-native `organizations` collection.
///
/// Super Admin only for writes. Org Admin may read their own org via rules.
class OrganizationsRepository {
  OrganizationsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _orgs =>
      _db.collection(AdminCollections.organizations);

  CollectionReference<Map<String, dynamic>> get _adminUsers =>
      _db.collection(AdminCollections.adminUsers);

  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  // ─── Listing ─────────────────────────────────────────────────────────────

  Future<OrganizationPageResult> fetchPage({
    required OrganizationListFilters filters,
    required OrganizationSort sort,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    Query<Map<String, dynamic>> query = _orgs;

    // Server-side status filter for a single status.
    if (filters.statuses.length == 1) {
      final status = filters.statuses.first;
      if (status != ManagedOrganizationStatus.deleted &&
          status != ManagedOrganizationStatus.archived) {
        query = query.where('status', isEqualTo: status.wireValue);
      }
    }

    if (filters.types.length == 1) {
      query = query.where('type', isEqualTo: filters.types.first.wireValue);
    }

    final q = filters.query.trim();
    if (q.isNotEmpty) {
      // Exact ID lookup shortcut.
      if (RegExp(r'^[A-Za-z0-9_-]{12,}$').hasMatch(q) && !q.contains(' ')) {
        final doc = await _orgs.doc(q).get();
        if (!doc.exists || doc.data() == null) {
          return const OrganizationPageResult(
            organizations: [],
            hasMore: false,
          );
        }
        final org = ManagedOrganization.fromFirestore(
          id: doc.id,
          map: doc.data()!,
        );
        final filtered = _applyClientFilters([org], filters);
        return OrganizationPageResult(
          organizations: filtered,
          hasMore: false,
          cursor: doc,
        );
      }
      query = query.orderBy('name').startAt([q]).endAt(['$q\uf8ff']);
    } else {
      switch (sort.field) {
        case OrganizationSortField.name:
          query = query.orderBy('name', descending: sort.descending);
        case OrganizationSortField.type:
          query = query.orderBy('type', descending: sort.descending);
        case OrganizationSortField.city:
          query = query.orderBy('city', descending: sort.descending);
        case OrganizationSortField.status:
          query = query.orderBy('status', descending: sort.descending);
        case OrganizationSortField.createdAt:
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
      snap = await _orgs.orderBy(FieldPath.documentId).limit(limit + 1).get();
    }

    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;

    var orgs = pageDocs
        .map((d) => ManagedOrganization.fromFirestore(id: d.id, map: d.data()))
        .toList();
    orgs = _applyClientFilters(orgs, filters);

    return OrganizationPageResult(
      organizations: orgs,
      hasMore: hasMore,
      cursor: pageDocs.isEmpty ? null : pageDocs.last,
    );
  }

  List<ManagedOrganization> _applyClientFilters(
    List<ManagedOrganization> list,
    OrganizationListFilters filters,
  ) {
    Iterable<ManagedOrganization> items = list;

    if (!filters.includeDeleted) {
      items = items.where((o) => !o.isSoftDeleted);
    }
    if (!filters.includeArchived) {
      items = items.where((o) => !o.isArchived);
    }

    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((o) {
        return o.name.toLowerCase().contains(q) ||
            o.id.toLowerCase().contains(q) ||
            o.slug.toLowerCase().contains(q) ||
            o.email.toLowerCase().contains(q) ||
            o.phone.toLowerCase().contains(q) ||
            o.registrationNumber.toLowerCase().contains(q) ||
            o.locationLabel.toLowerCase().contains(q) ||
            (o.primaryAdminEmail?.toLowerCase().contains(q) ?? false);
      });
    }

    if (filters.statuses.isNotEmpty) {
      items = items.where((o) => filters.statuses.contains(o.displayStatus));
    }
    if (filters.types.isNotEmpty) {
      items = items.where((o) => filters.types.contains(o.type));
    }
    if (filters.country?.trim().isNotEmpty == true) {
      final c = filters.country!.trim().toLowerCase();
      items = items.where((o) => o.country.toLowerCase().contains(c));
    }
    if (filters.stateProvince?.trim().isNotEmpty == true) {
      final s = filters.stateProvince!.trim().toLowerCase();
      items = items.where((o) => o.stateProvince.toLowerCase().contains(s));
    }
    if (filters.city?.trim().isNotEmpty == true) {
      final c = filters.city!.trim().toLowerCase();
      items = items.where((o) => o.city.toLowerCase().contains(c));
    }
    if (filters.registrationDateFrom != null) {
      items = items.where(
        (o) =>
            o.createdAt != null &&
            !o.createdAt!.isBefore(filters.registrationDateFrom!),
      );
    }
    if (filters.registrationDateTo != null) {
      items = items.where(
        (o) =>
            o.createdAt != null &&
            !o.createdAt!.isAfter(filters.registrationDateTo!),
      );
    }

    return items.toList();
  }

  // ─── Single doc ───────────────────────────────────────────────────────────

  Stream<ManagedOrganization?> watchById(String id) {
    return _orgs.doc(id).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return ManagedOrganization.fromFirestore(id: snap.id, map: snap.data()!);
    });
  }

  Future<ManagedOrganization?> fetchById(String id) async {
    final doc = await _orgs.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return ManagedOrganization.fromFirestore(id: doc.id, map: doc.data()!);
  }

  // ─── Summary stats ────────────────────────────────────────────────────────

  Future<OrganizationSummaryStats> fetchSummary() async {
    try {
      final snap = await _orgs.limit(AdminQueryLimits.summaryScanMax).get();
      final list = snap.docs
          .map((d) => ManagedOrganization.fromFirestore(id: d.id, map: d.data()))
          .toList();

      final nonDeleted = list.where((o) => !o.isSoftDeleted).toList();

      return OrganizationSummaryStats(
        total: nonDeleted.length,
        active: nonDeleted
            .where((o) => o.displayStatus == ManagedOrganizationStatus.active)
            .length,
        pending: nonDeleted
            .where((o) => o.displayStatus == ManagedOrganizationStatus.pending)
            .length,
        verified: nonDeleted
            .where(
              (o) => o.displayStatus == ManagedOrganizationStatus.verified,
            )
            .length,
        inactive: nonDeleted
            .where(
              (o) => o.displayStatus == ManagedOrganizationStatus.inactive,
            )
            .length,
        suspended: nonDeleted
            .where(
              (o) => o.displayStatus == ManagedOrganizationStatus.suspended,
            )
            .length,
        archived: nonDeleted
            .where(
              (o) => o.displayStatus == ManagedOrganizationStatus.archived,
            )
            .length,
        boards: nonDeleted
            .where(
              (o) =>
                  o.type == ManagedOrganizationType.nationalBoard ||
                  o.type == ManagedOrganizationType.provincialBoard ||
                  o.type == ManagedOrganizationType.districtAssociation,
            )
            .length,
        clubs: nonDeleted
            .where((o) => o.type == ManagedOrganizationType.club)
            .length,
        academies: nonDeleted
            .where((o) => o.type == ManagedOrganizationType.academy)
            .length,
        withAdmin: nonDeleted.where((o) => o.hasPrimaryAdmin).length,
      );
    } catch (_) {
      return const OrganizationSummaryStats();
    }
  }

  // ─── Related counts ───────────────────────────────────────────────────────

  Future<OrganizationRelatedCounts> fetchRelatedCounts(String orgId) async {
    Future<int> count(String collection, {String? whereField}) async {
      final field = whereField ?? 'organizationId';
      try {
        final agg = await _db
            .collection(collection)
            .where(field, isEqualTo: orgId)
            .count()
            .get();
        return agg.count ?? 0;
      } catch (_) {
        try {
          final snap = await _db
              .collection(collection)
              .where(field, isEqualTo: orgId)
              .limit(200)
              .get();
          return snap.docs.length;
        } catch (_) {
          return 0;
        }
      }
    }

    final results = await Future.wait([
      count(AdminCollections.users),
      count(AdminCollections.teams),
      count(AdminCollections.tournaments),
      count(AdminCollections.matches),
      count(AdminCollections.grounds),
    ]);

    return OrganizationRelatedCounts(
      users: results[0],
      teams: results[1],
      tournaments: results[2],
      matches: results[3],
      grounds: results[4],
    );
  }

  // ─── Audit ────────────────────────────────────────────────────────────────

  Future<List<AdminAuditLogEntry>> fetchAuditForOrg(
    String orgId, {
    int limit = 50,
  }) async {
    try {
      final snap = await _audit
          .where('targetUid', isEqualTo: orgId)
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

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<ManagedOrganization> create({
    required ManagedOrganization draft,
    required AdminUser actor,
  }) async {
    final ref = _orgs.doc();
    final data = draft.toCreateMap(createdBy: actor.uid);
    await ref.set(data);
    final created = ManagedOrganization.fromFirestore(id: ref.id, map: data);
    await _writeAudit(
      action: AdminAuditActions.organizationCreated,
      actor: actor,
      target: created,
    );
    return created;
  }

  Future<void> update({
    required ManagedOrganization target,
    required AdminUser actor,
    required ManagedOrganization draft,
  }) async {
    final now = DateTime.now().toIso8601String();
    final updateMap = <String, dynamic>{
      'name': draft.name.trim(),
      'slug': draft.slug.trim().isEmpty
          ? ManagedOrganization.slugify(draft.name)
          : draft.slug.trim(),
      'type': draft.type.wireValue,
      'status': (draft.status == ManagedOrganizationStatus.deleted ||
              draft.status == ManagedOrganizationStatus.archived)
          ? target.status.wireValue
          : draft.status.wireValue,
      'email': draft.email.trim(),
      'phone': draft.phone.trim(),
      'website': draft.website.trim(),
      'country': draft.country.trim(),
      'stateProvince': draft.stateProvince.trim(),
      'city': draft.city.trim(),
      'address': draft.address.trim(),
      'logoUrl': draft.logoUrl?.trim(),
      'description': draft.description.trim(),
      'establishedYear': draft.establishedYear,
      'registrationNumber': draft.registrationNumber.trim(),
      'updatedAt': now,
    };
    if (draft.bannerUrl != null) {
      updateMap['bannerUrl'] = draft.bannerUrl!.trim();
    }

    await _orgs.doc(target.id).set(updateMap, SetOptions(merge: true));

    // Keep linked admin org name in sync.
    if (target.primaryAdminUid != null &&
        target.primaryAdminUid!.isNotEmpty &&
        draft.name.trim() != target.name) {
      await _adminUsers.doc(target.primaryAdminUid!).set({
        'organizationName': draft.name.trim(),
      }, SetOptions(merge: true));
    }

    await _writeAudit(
      action: AdminAuditActions.organizationEdited,
      actor: actor,
      target: target,
      metadata: {'name': draft.name.trim()},
    );
  }

  // ─── Status operations ────────────────────────────────────────────────────

  Future<void> setStatus({
    required ManagedOrganization target,
    required ManagedOrganizationStatus status,
    required AdminUser actor,
    String? reason,
  }) async {
    if (status == ManagedOrganizationStatus.deleted) return;
    final now = DateTime.now().toIso8601String();

    final extraFields = <String, dynamic>{};
    if (status == ManagedOrganizationStatus.verified) {
      extraFields['verifiedAt'] = now;
      extraFields['verifiedBy'] = actor.uid;
    } else if (status == ManagedOrganizationStatus.active &&
        target.status == ManagedOrganizationStatus.pending) {
      extraFields['approvedAt'] = now;
      extraFields['approvedBy'] = actor.uid;
    }

    await _orgs.doc(target.id).set({
      'status': status.wireValue,
      'updatedAt': now,
      ...extraFields,
    }, SetOptions(merge: true));

    final action = switch (status) {
      ManagedOrganizationStatus.active => target.status ==
              ManagedOrganizationStatus.pending
          ? AdminAuditActions.organizationApproved
          : AdminAuditActions.organizationActivated,
      ManagedOrganizationStatus.pending => AdminAuditActions.organizationPending,
      ManagedOrganizationStatus.verified =>
        AdminAuditActions.organizationVerified,
      ManagedOrganizationStatus.inactive =>
        AdminAuditActions.organizationDeactivated,
      ManagedOrganizationStatus.suspended =>
        AdminAuditActions.organizationSuspended,
      ManagedOrganizationStatus.archived =>
        AdminAuditActions.organizationArchived,
      ManagedOrganizationStatus.deleted =>
        AdminAuditActions.organizationSoftDeleted,
    };
    await _writeAudit(
      action: action,
      actor: actor,
      target: target,
      reason: reason,
      metadata: {'status': status.wireValue},
    );
  }

  Future<void> archive({
    required ManagedOrganization target,
    required AdminUser actor,
    String? reason,
  }) async {
    await _orgs.doc(target.id).set({
      'recordStatus': AdminOrganizationRecordStatus.archived.wireValue,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.organizationArchived,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> unarchive({
    required ManagedOrganization target,
    required AdminUser actor,
    String? reason,
  }) async {
    await _orgs.doc(target.id).set({
      'recordStatus': AdminOrganizationRecordStatus.active.wireValue,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.organizationUnarchived,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> softDelete({
    required ManagedOrganization target,
    required AdminUser actor,
    String? reason,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _orgs.doc(target.id).set({
      'recordStatus': AdminOrganizationRecordStatus.softDeleted.wireValue,
      'deletedAt': now,
      'deletedBy': actor.uid,
      'updatedAt': now,
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.organizationSoftDeleted,
      actor: actor,
      target: target,
      reason: reason,
      metadata: {'softDelete': true},
    );
  }

  Future<void> restore({
    required ManagedOrganization target,
    required AdminUser actor,
    String? reason,
  }) async {
    await _orgs.doc(target.id).set({
      'recordStatus': AdminOrganizationRecordStatus.active.wireValue,
      'deletedAt': FieldValue.delete(),
      'deletedBy': FieldValue.delete(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.organizationRestored,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> setFeatured({
    required ManagedOrganization target,
    required bool featured,
    required AdminUser actor,
    String? reason,
  }) async {
    await _orgs.doc(target.id).set({
      'featured': featured,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: featured
          ? AdminAuditActions.organizationFeatured
          : AdminAuditActions.organizationUnfeatured,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  // ─── Admin management ─────────────────────────────────────────────────────

  /// Link an existing `admin_users` profile as Org Admin for [target].
  Future<void> linkOrgAdmin({
    required ManagedOrganization target,
    required AdminUser actor,
    required String uidOrEmail,
    String? reason,
  }) async {
    final key = uidOrEmail.trim();
    if (key.isEmpty) throw ArgumentError('UID or email is required');

    final adminDoc = await _resolveAdminUser(key);
    if (adminDoc == null) {
      throw StateError(
        'No admin_users profile found for "$key". '
        'Create the Auth user and admin_users doc first.',
      );
    }

    final adminUid = adminDoc.id;
    final adminData = adminDoc.data()!;
    final adminEmail = (adminData['email'] as String?)?.trim() ?? '';

    await _adminUsers.doc(adminUid).set({
      'roleId': AdminRole.admin.wireValue,
      'organizationId': target.id,
      'organizationName': target.name,
      'isActive': true,
    }, SetOptions(merge: true));

    await _orgs.doc(target.id).set({
      'primaryAdminUid': adminUid,
      'primaryAdminEmail': adminEmail,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    await _writeAudit(
      action: AdminAuditActions.organizationAdminLinked,
      actor: actor,
      target: target,
      reason: reason,
      metadata: {'adminUid': adminUid, 'adminEmail': adminEmail},
    );
  }

  Future<void> unlinkOrgAdmin({
    required ManagedOrganization target,
    required AdminUser actor,
    String? reason,
  }) async {
    final adminUid = target.primaryAdminUid;
    if (adminUid != null && adminUid.isNotEmpty) {
      await _adminUsers.doc(adminUid).set({
        'organizationId': FieldValue.delete(),
        'organizationName': FieldValue.delete(),
      }, SetOptions(merge: true));
    }

    await _orgs.doc(target.id).set({
      'primaryAdminUid': FieldValue.delete(),
      'primaryAdminEmail': FieldValue.delete(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    await _writeAudit(
      action: AdminAuditActions.organizationAdminUnlinked,
      actor: actor,
      target: target,
      reason: reason,
      metadata: adminUid == null || adminUid.isEmpty
          ? const {}
          : {'adminUid': adminUid},
    );
  }

  Future<void> transferOwnership({
    required ManagedOrganization target,
    required AdminUser actor,
    required String newOwnerUidOrEmail,
    String? reason,
  }) async {
    final previousUid = target.primaryAdminUid;
    await linkOrgAdmin(
      target: target,
      actor: actor,
      uidOrEmail: newOwnerUidOrEmail,
      reason: reason,
    );
    await _writeAudit(
      action: AdminAuditActions.organizationOwnershipTransferred,
      actor: actor,
      target: target,
      reason: reason,
      metadata: {
        'previousOwnerUid': previousUid ?? '',
        'newOwner': newOwnerUidOrEmail,
      },
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<DocumentSnapshot<Map<String, dynamic>>?> _resolveAdminUser(
    String uidOrEmail,
  ) async {
    final byUid = await _adminUsers.doc(uidOrEmail).get();
    if (byUid.exists && byUid.data() != null) return byUid;

    final email = uidOrEmail.toLowerCase();
    if (!email.contains('@')) return null;

    final snap = await _adminUsers
        .where('email', isEqualTo: uidOrEmail)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return snap.docs.first;

    final snapLower = await _adminUsers
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snapLower.docs.isNotEmpty) return snapLower.docs.first;
    return null;
  }

  Future<void> _writeAudit({
    required String action,
    required AdminUser actor,
    required ManagedOrganization target,
    String? reason,
    Map<String, dynamic> metadata = const {},
  }) async {
    final entry = AdminAuditLogEntry(
      id: '',
      action: action,
      actorUid: actor.uid,
      actorEmail: actor.email,
      targetUid: target.id,
      targetEmail: target.name,
      timestamp: DateTime.now(),
      reason: reason,
      metadata: {
        ...metadata,
        'entity': 'organization',
        'type': target.type.wireValue,
      },
    );
    await _audit.add(entry.toMap());
  }
}
