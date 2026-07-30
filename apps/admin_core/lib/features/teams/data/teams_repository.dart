import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/constants/admin_collections.dart';
import '../../../core/constants/admin_query_limits.dart';
import '../../../models/admin_user.dart';
import '../../users/models/admin_audit_log.dart';
import '../models/managed_team.dart';
import '../models/team_enums.dart';
import '../models/team_filters.dart';

/// Paginated reads / additive admin updates for Firestore `teams`.
///
/// Never hard-deletes team docs from the admin panel.
/// Never mutates roster (`playerIds`), stats, or leadership ids.
class TeamsRepository {
  TeamsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _teams =>
      _db.collection(AdminCollections.teams);

  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  Future<TeamPageResult> fetchPage({
    required AdminAppType appType,
    required AdminUser? actor,
    required TeamListFilters filters,
    required TeamSort sort,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    Query<Map<String, dynamic>> query = _teams;

    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) {
        return const TeamPageResult(teams: [], hasMore: false);
      }
      query = query.where('organizationId', isEqualTo: orgId);
    }

    if (filters.statuses.length == 1) {
      final status = filters.statuses.first;
      if (status == ManagedTeamStatus.suspended ||
          status == ManagedTeamStatus.pendingVerification ||
          status == ManagedTeamStatus.active) {
        query = query.where('adminStatus', isEqualTo: status.wireValue);
      }
    }

    if (filters.categories.length == 1) {
      query = query.where(
        'adminCategory',
        isEqualTo: filters.categories.first.wireValue,
      );
    }

    final q = filters.query.trim();
    if (q.isNotEmpty) {
      if (RegExp(r'^[A-Za-z0-9_-]{12,}$').hasMatch(q) && !q.contains(' ')) {
        final doc = await _teams.doc(q).get();
        if (!doc.exists || doc.data() == null) {
          return const TeamPageResult(teams: [], hasMore: false);
        }
        final team = ManagedTeam.fromFirestore(id: doc.id, map: doc.data()!);
        if (!_visibleToActor(team, appType: appType, actor: actor)) {
          return const TeamPageResult(teams: [], hasMore: false);
        }
        final filtered = _applyClientFilters([team], filters);
        return TeamPageResult(teams: filtered, hasMore: false, cursor: doc);
      }
      query = query.orderBy('name').startAt([q]).endAt(['$q\uf8ff']);
    } else {
      switch (sort.field) {
        case TeamSortField.name:
          query = query.orderBy('name', descending: sort.descending);
        case TeamSortField.members:
          query = query.orderBy('memberCount', descending: sort.descending);
        case TeamSortField.matches:
        case TeamSortField.winPct:
        case TeamSortField.createdAt:
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
      var fallback = _teams.orderBy(FieldPath.documentId).limit(limit + 1);
      if (appType == AdminAppType.organizationAdmin &&
          actor?.organizationId != null) {
        fallback = _teams
            .where('organizationId', isEqualTo: actor!.organizationId)
            .limit(limit + 1);
      }
      snap = await fallback.get();
    }

    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;

    var teams = pageDocs
        .map((d) => ManagedTeam.fromFirestore(id: d.id, map: d.data()))
        .toList();
    teams = _applyClientFilters(teams, filters);

    if (sort.field == TeamSortField.winPct) {
      teams.sort((a, b) => sort.descending
          ? b.winPercentage.compareTo(a.winPercentage)
          : a.winPercentage.compareTo(b.winPercentage));
    } else if (sort.field == TeamSortField.matches) {
      teams.sort((a, b) => sort.descending
          ? b.matchesPlayed.compareTo(a.matchesPlayed)
          : a.matchesPlayed.compareTo(b.matchesPlayed));
    }

    return TeamPageResult(
      teams: teams,
      hasMore: hasMore,
      cursor: pageDocs.isEmpty ? null : pageDocs.last,
    );
  }

  List<ManagedTeam> _applyClientFilters(
    List<ManagedTeam> list,
    TeamListFilters filters,
  ) {
    Iterable<ManagedTeam> items = list;

    if (!filters.includeDeleted) {
      items = items.where((t) => !t.isSoftDeleted);
    }
    if (!filters.includeArchived) {
      items = items.where(
        (t) => t.recordStatus != AdminTeamRecordStatus.archived,
      );
    }

    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((t) {
        return t.name.toLowerCase().contains(q) ||
            t.id.toLowerCase().contains(q) ||
            (t.teamCode?.toLowerCase().contains(q) ?? false) ||
            (t.captainId?.toLowerCase().contains(q) ?? false) ||
            (t.createdBy?.toLowerCase().contains(q) ?? false) ||
            t.coachName.toLowerCase().contains(q) ||
            t.contactNumber.toLowerCase().contains(q) ||
            t.locationLabel.toLowerCase().contains(q) ||
            t.city.toLowerCase().contains(q) ||
            t.stateProvince.toLowerCase().contains(q) ||
            t.country.toLowerCase().contains(q);
      });
    }

    if (filters.statuses.isNotEmpty) {
      items = items.where((t) => filters.statuses.contains(t.displayStatus));
    }
    if (filters.ballTypes.isNotEmpty) {
      items = items.where(
        (t) => t.ballType != null && filters.ballTypes.contains(t.ballType),
      );
    }
    if (filters.categories.isNotEmpty) {
      items = items.where(
        (t) => t.category != null && filters.categories.contains(t.category),
      );
    }
    if (filters.country?.trim().isNotEmpty == true) {
      final c = filters.country!.trim().toLowerCase();
      items = items.where((t) => t.country.toLowerCase().contains(c));
    }
    if (filters.stateProvince?.trim().isNotEmpty == true) {
      final s = filters.stateProvince!.trim().toLowerCase();
      items = items.where((t) => t.stateProvince.toLowerCase().contains(s));
    }
    if (filters.city?.trim().isNotEmpty == true) {
      final c = filters.city!.trim().toLowerCase();
      items = items.where((t) => t.city.toLowerCase().contains(c));
    }
    if (filters.createdFrom != null) {
      items = items.where(
        (t) =>
            t.createdAt != null && !t.createdAt!.isBefore(filters.createdFrom!),
      );
    }
    if (filters.createdTo != null) {
      items = items.where(
        (t) =>
            t.createdAt != null && !t.createdAt!.isAfter(filters.createdTo!),
      );
    }
    if (filters.minMembers != null) {
      items = items.where((t) => t.memberCount >= filters.minMembers!);
    }
    if (filters.maxMembers != null) {
      items = items.where((t) => t.memberCount <= filters.maxMembers!);
    }

    return items.toList();
  }

  bool _visibleToActor(
    ManagedTeam t, {
    required AdminAppType appType,
    required AdminUser? actor,
  }) {
    if (appType != AdminAppType.organizationAdmin) return true;
    final orgId = actor?.organizationId;
    if (orgId == null || orgId.isEmpty) return false;
    return t.organizationId == orgId;
  }

  Stream<ManagedTeam?> watchById(
    String id, {
    required AdminAppType appType,
    required AdminUser? actor,
  }) {
    return _teams.doc(id).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      final t = ManagedTeam.fromFirestore(id: snap.id, map: snap.data()!);
      if (!_visibleToActor(t, appType: appType, actor: actor)) return null;
      return t;
    });
  }

  /// One-shot detail fetch (preferred for admin detail panels).
  Future<ManagedTeam?> fetchById(
    String id, {
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    final snap = await _teams.doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    final t = ManagedTeam.fromFirestore(id: snap.id, map: snap.data()!);
    if (!_visibleToActor(t, appType: appType, actor: actor)) return null;
    return t;
  }

  Future<TeamSummaryStats> fetchSummary({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    Query<Map<String, dynamic>> base = _teams;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) return const TeamSummaryStats();
      base = base.where('organizationId', isEqualTo: orgId);
    }

    try {
      final snap = await base.limit(AdminQueryLimits.summaryScanMax).get();
      final list = snap.docs
          .map((d) => ManagedTeam.fromFirestore(id: d.id, map: d.data()))
          .where((t) => !t.isSoftDeleted)
          .toList();
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      return TeamSummaryStats(
        total: list.length,
        verified: list.where((t) => t.isVerified).length,
        active: list
            .where(
              (t) =>
                  t.displayStatus == ManagedTeamStatus.active ||
                  t.displayStatus == ManagedTeamStatus.verified,
            )
            .length,
        newTeams: list
            .where(
              (t) => t.createdAt != null && !t.createdAt!.isBefore(weekAgo),
            )
            .length,
        tournamentTeams: list
            .where((t) => t.matchesPlayed > 0)
            .length,
        clubTeams: list
            .where((t) => t.category == ManagedTeamCategory.club)
            .length,
        schoolTeams: list
            .where((t) => t.category == ManagedTeamCategory.school)
            .length,
        universityTeams: list
            .where((t) => t.category == ManagedTeamCategory.university)
            .length,
        nationalTeams: list
            .where((t) => t.category == ManagedTeamCategory.national)
            .length,
      );
    } catch (_) {
      return const TeamSummaryStats();
    }
  }

  Future<List<AdminAuditLogEntry>> fetchAuditForTeam(
    String teamId, {
    int limit = 30,
  }) async {
    try {
      final snap = await _audit
          .where('targetUid', isEqualTo: teamId)
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

  Future<void> setFeatured({
    required ManagedTeam target,
    required bool featured,
    required AdminUser actor,
    String? reason,
  }) async {
    await _teams.doc(target.id).set({
      'adminFeatured': featured,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: featured
          ? AdminAuditActions.teamFeatured
          : AdminAuditActions.teamUnfeatured,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> setVerified({
    required ManagedTeam target,
    required bool verified,
    required AdminUser actor,
    String? reason,
  }) async {
    await _teams.doc(target.id).set({
      'adminVerified': verified,
      'adminStatus': verified
          ? ManagedTeamStatus.verified.wireValue
          : ManagedTeamStatus.active.wireValue,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: verified
          ? AdminAuditActions.teamVerified
          : AdminAuditActions.teamUnverified,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> setStatus({
    required ManagedTeam target,
    required ManagedTeamStatus status,
    required AdminUser actor,
    String? reason,
  }) async {
    await _teams.doc(target.id).set({
      'adminStatus': status.wireValue,
      if (status == ManagedTeamStatus.verified) 'adminVerified': true,
      if (status == ManagedTeamStatus.active) 'adminVerified': false,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    final action = switch (status) {
      ManagedTeamStatus.suspended => AdminAuditActions.teamSuspended,
      ManagedTeamStatus.active => AdminAuditActions.teamUnsuspended,
      ManagedTeamStatus.verified => AdminAuditActions.teamVerified,
      ManagedTeamStatus.pendingVerification => AdminAuditActions.teamEdited,
      _ => AdminAuditActions.teamEdited,
    };
    await _writeAudit(
      action: action,
      actor: actor,
      target: target,
      reason: reason,
      metadata: {'status': status.wireValue},
    );
  }

  Future<void> softDelete({
    required ManagedTeam target,
    required AdminUser actor,
    String? reason,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _teams.doc(target.id).set({
      'adminRecordStatus': AdminTeamRecordStatus.deleted.wireValue,
      'adminDeletedAt': now,
      'adminDeletedBy': actor.uid,
      'updatedAt': now,
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.teamSoftDeleted,
      actor: actor,
      target: target,
      reason: reason,
      metadata: {'softDelete': true},
    );
  }

  Future<void> restore({
    required ManagedTeam target,
    required AdminUser actor,
    String? reason,
  }) async {
    await _teams.doc(target.id).set({
      'adminRecordStatus': AdminTeamRecordStatus.active.wireValue,
      'adminDeletedAt': FieldValue.delete(),
      'adminDeletedBy': FieldValue.delete(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.teamRestored,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> archive({
    required ManagedTeam target,
    required AdminUser actor,
    String? reason,
  }) async {
    await _teams.doc(target.id).set({
      'adminRecordStatus': AdminTeamRecordStatus.archived.wireValue,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.teamArchived,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> updateBasicInfo({
    required ManagedTeam target,
    required AdminUser actor,
    String? name,
    String? coachName,
    String? contactNumber,
    ManagedTeamCategory? category,
    ManagedTeamBallType? ballType,
    String? reason,
  }) async {
    await _teams.doc(target.id).set({
      'name': ?name,
      'coachName': ?coachName,
      'contactNumber': ?contactNumber,
      'adminCategory': ?category?.wireValue,
      'adminBallType': ?ballType?.wireValue,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.teamEdited,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> _writeAudit({
    required String action,
    required AdminUser actor,
    required ManagedTeam target,
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
        'entity': 'team',
        'teamCode': target.teamCode,
      },
    );
    await _audit.add(entry.toMap());
  }
}
