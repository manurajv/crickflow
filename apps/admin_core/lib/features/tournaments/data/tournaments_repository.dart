import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/constants/admin_collections.dart';
import '../../../models/admin_user.dart';
import '../../users/models/admin_audit_log.dart';
import '../models/managed_tournament.dart';
import '../models/tournament_enums.dart';
import '../models/tournament_filters.dart';

/// Paginated reads / additive admin updates for Firestore `tournaments`.
///
/// Never hard-deletes tournament docs from the admin panel.
class TournamentsRepository {
  TournamentsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _tournaments =>
      _db.collection(AdminCollections.tournaments);

  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  Future<TournamentPageResult> fetchPage({
    required AdminAppType appType,
    required AdminUser? actor,
    required TournamentListFilters filters,
    required TournamentSort sort,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    Query<Map<String, dynamic>> query = _tournaments;

    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) {
        return const TournamentPageResult(tournaments: [], hasMore: false);
      }
      query = query.where('organizationId', isEqualTo: orgId);
    }

    if (filters.statuses.length == 1) {
      query = query.where('status', isEqualTo: filters.statuses.first.wireValue);
    }
    if (filters.featured != null) {
      query = query.where('adminFeatured', isEqualTo: filters.featured);
    }

    final q = filters.query.trim();
    if (q.isNotEmpty) {
      if (RegExp(r'^[A-Za-z0-9_-]{12,}$').hasMatch(q) && !q.contains(' ')) {
        // Likely document id — fetch single.
        final doc = await _tournaments.doc(q).get();
        if (!doc.exists || doc.data() == null) {
          return const TournamentPageResult(tournaments: [], hasMore: false);
        }
        final t = ManagedTournament.fromFirestore(id: doc.id, map: doc.data()!);
        if (!_visibleToActor(t, appType: appType, actor: actor)) {
          return const TournamentPageResult(tournaments: [], hasMore: false);
        }
        final filtered = _applyClientFilters([t], filters);
        return TournamentPageResult(
          tournaments: filtered,
          hasMore: false,
          cursor: doc,
        );
      }
      query = query.orderBy('name').startAt([q]).endAt(['$q\uf8ff']);
    } else {
      switch (sort.field) {
        case TournamentSortField.name:
          query = query.orderBy('name', descending: sort.descending);
        case TournamentSortField.startDate:
          query = query.orderBy('startDate', descending: sort.descending);
        case TournamentSortField.endDate:
          query = query.orderBy('endDate', descending: sort.descending);
        case TournamentSortField.status:
          query = query.orderBy('status', descending: sort.descending);
        case TournamentSortField.createdAt:
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
      var fallback = _tournaments.orderBy(FieldPath.documentId).limit(limit + 1);
      if (appType == AdminAppType.organizationAdmin &&
          actor?.organizationId != null) {
        fallback = _tournaments
            .where('organizationId', isEqualTo: actor!.organizationId)
            .limit(limit + 1);
      }
      snap = await fallback.get();
    }

    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;

    var tournaments = pageDocs
        .map((d) => ManagedTournament.fromFirestore(id: d.id, map: d.data()))
        .toList();
    tournaments = _applyClientFilters(tournaments, filters);

    return TournamentPageResult(
      tournaments: tournaments,
      hasMore: hasMore,
      cursor: pageDocs.isEmpty ? null : pageDocs.last,
    );
  }

  List<ManagedTournament> _applyClientFilters(
    List<ManagedTournament> list,
    TournamentListFilters filters,
  ) {
    Iterable<ManagedTournament> items = list;

    if (!filters.includeDeleted) {
      items = items.where((t) => !t.isSoftDeleted);
    }
    if (!filters.includeArchived) {
      items = items.where(
        (t) => t.recordStatus != AdminTournamentRecordStatus.archived,
      );
    }

    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((t) {
        return t.name.toLowerCase().contains(q) ||
            t.id.toLowerCase().contains(q) ||
            (t.tournamentCode?.toLowerCase().contains(q) ?? false) ||
            t.organizerName.toLowerCase().contains(q) ||
            t.effectiveOrganizerId.toLowerCase().contains(q) ||
            t.locationLabel.toLowerCase().contains(q) ||
            t.grounds.any((g) => g.toLowerCase().contains(q)) ||
            t.city.toLowerCase().contains(q) ||
            t.stateProvince.toLowerCase().contains(q) ||
            t.country.toLowerCase().contains(q);
      });
    }

    if (filters.statuses.isNotEmpty) {
      items = items.where((t) => filters.statuses.contains(t.status));
    }
    if (filters.formats.isNotEmpty) {
      items = items.where((t) => filters.formats.contains(t.format));
    }
    if (filters.ballTypes.isNotEmpty) {
      items = items.where(
        (t) => t.ballType != null && filters.ballTypes.contains(t.ballType),
      );
    }
    if (filters.featured != null) {
      items = items.where((t) => t.adminFeatured == filters.featured);
    }
    if (filters.paidEntry != null) {
      items = items.where((t) => t.isFree != filters.paidEntry);
    }
    if (filters.approvals.isNotEmpty) {
      items = items.where((t) => filters.approvals.contains(t.adminApproval));
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
    if (filters.startFrom != null) {
      items = items.where(
        (t) =>
            t.startDate != null && !t.startDate!.isBefore(filters.startFrom!),
      );
    }
    if (filters.startTo != null) {
      items = items.where(
        (t) => t.startDate != null && !t.startDate!.isAfter(filters.startTo!),
      );
    }

    return items.toList();
  }

  bool _visibleToActor(
    ManagedTournament t, {
    required AdminAppType appType,
    required AdminUser? actor,
  }) {
    if (appType != AdminAppType.organizationAdmin) return true;
    final orgId = actor?.organizationId;
    if (orgId == null || orgId.isEmpty) return false;
    return t.organizationId == orgId;
  }

  Stream<ManagedTournament?> watchById(
    String id, {
    required AdminAppType appType,
    required AdminUser? actor,
  }) {
    return _tournaments.doc(id).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      final t = ManagedTournament.fromFirestore(id: snap.id, map: snap.data()!);
      if (!_visibleToActor(t, appType: appType, actor: actor)) return null;
      return t;
    });
  }

  Future<TournamentSummaryStats> fetchSummary({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    Query<Map<String, dynamic>> base = _tournaments;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) return const TournamentSummaryStats();
      base = base.where('organizationId', isEqualTo: orgId);
    }

    try {
      final snap = await base.limit(500).get();
      final list = snap.docs
          .map((d) => ManagedTournament.fromFirestore(id: d.id, map: d.data()))
          .where((t) => !t.isSoftDeleted)
          .toList();

      return TournamentSummaryStats(
        total: list.length,
        upcoming: list
            .where((t) => t.status == ManagedTournamentStatus.upcoming)
            .length,
        ongoing:
            list.where((t) => t.status == ManagedTournamentStatus.live).length,
        completed: list
            .where((t) => t.status == ManagedTournamentStatus.completed)
            .length,
        cancelled: list
            .where((t) => t.status == ManagedTournamentStatus.cancelled)
            .length,
        live:
            list.where((t) => t.status == ManagedTournamentStatus.live).length,
        featured: list.where((t) => t.adminFeatured).length,
      );
    } catch (_) {
      return const TournamentSummaryStats();
    }
  }

  Future<void> setFeatured({
    required ManagedTournament target,
    required bool featured,
    required AdminUser actor,
    String? reason,
  }) async {
    await _tournaments.doc(target.id).set({
      'adminFeatured': featured,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: featured
          ? AdminAuditActions.tournamentFeatured
          : AdminAuditActions.tournamentUnfeatured,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> setApproval({
    required ManagedTournament target,
    required AdminTournamentApproval approval,
    required AdminUser actor,
    String? reason,
  }) async {
    await _tournaments.doc(target.id).set({
      'adminApprovalStatus': approval.wireValue,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: approval == AdminTournamentApproval.approved
          ? AdminAuditActions.tournamentApproved
          : AdminAuditActions.tournamentRejected,
      actor: actor,
      target: target,
      reason: reason,
      metadata: {'approval': approval.wireValue},
    );
  }

  Future<void> cancelTournament({
    required ManagedTournament target,
    required AdminUser actor,
    String? reason,
  }) async {
    await _tournaments.doc(target.id).set({
      'status': ManagedTournamentStatus.cancelled.wireValue,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.tournamentCancelled,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> softDelete({
    required ManagedTournament target,
    required AdminUser actor,
    String? reason,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _tournaments.doc(target.id).set({
      'adminRecordStatus': AdminTournamentRecordStatus.deleted.wireValue,
      'adminDeletedAt': now,
      'adminDeletedBy': actor.uid,
      'updatedAt': now,
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.tournamentSoftDeleted,
      actor: actor,
      target: target,
      reason: reason,
      metadata: {'softDelete': true},
    );
  }

  Future<void> restore({
    required ManagedTournament target,
    required AdminUser actor,
    String? reason,
  }) async {
    await _tournaments.doc(target.id).set({
      'adminRecordStatus': AdminTournamentRecordStatus.active.wireValue,
      'adminDeletedAt': FieldValue.delete(),
      'adminDeletedBy': FieldValue.delete(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.tournamentRestored,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> archive({
    required ManagedTournament target,
    required AdminUser actor,
    String? reason,
  }) async {
    await _tournaments.doc(target.id).set({
      'adminRecordStatus': AdminTournamentRecordStatus.archived.wireValue,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.tournamentArchived,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> updateBasicInfo({
    required ManagedTournament target,
    required AdminUser actor,
    String? name,
    String? description,
    String? winningPrize,
    double? entryFee,
    String? reason,
  }) async {
    await _tournaments.doc(target.id).set({
      'name': ?name,
      'description': ?description,
      'winningPrize': ?winningPrize,
      'entryFee': ?entryFee,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.tournamentEdited,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> _writeAudit({
    required String action,
    required AdminUser actor,
    required ManagedTournament target,
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
        'entity': 'tournament',
        'tournamentCode': target.tournamentCode,
      },
    );
    await _audit.add(entry.toMap());
  }
}
