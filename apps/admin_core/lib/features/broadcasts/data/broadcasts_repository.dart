import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/constants/admin_collections.dart';
import '../../../core/constants/admin_query_limits.dart';
import '../../../models/admin_user.dart';
import '../../matches/models/match_enums.dart';
import '../../users/models/admin_audit_log.dart';
import '../models/broadcast_enums.dart';
import '../models/broadcast_filters.dart';
import '../models/managed_broadcast.dart';

/// Paginated broadcast monitor reads from `matches` + `stream` metadata.
///
/// Monitoring only — never writes stream keys, RTMP secrets, or stops streams.
class BroadcastsRepository {
  BroadcastsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _matches =>
      _db.collection(AdminCollections.matches);

  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  Future<BroadcastPageResult> fetchPage({
    required AdminAppType appType,
    required AdminUser? actor,
    required BroadcastListFilters filters,
    required BroadcastSort sort,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    Query<Map<String, dynamic>> query = _matches;

    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) {
        return const BroadcastPageResult(broadcasts: [], hasMore: false);
      }
      query = query.where('organizationId', isEqualTo: orgId);
    }

    if (filters.liveOnly ||
        (filters.statuses.length == 1 &&
            filters.statuses.first == ManagedBroadcastStatus.live)) {
      query = query.where('stream.status', isEqualTo: 'live');
    }

    final q = filters.query.trim();
    if (q.isNotEmpty &&
        RegExp(r'^[A-Za-z0-9_-]{12,}$').hasMatch(q) &&
        !q.contains(' ')) {
      final doc = await _matches.doc(q).get();
      if (!doc.exists || doc.data() == null) {
        return const BroadcastPageResult(broadcasts: [], hasMore: false);
      }
      final b = ManagedBroadcast.fromFirestore(id: doc.id, map: doc.data()!);
      if (!_visibleToActor(b, appType: appType, actor: actor)) {
        return const BroadcastPageResult(broadcasts: [], hasMore: false);
      }
      final filtered = _applyClientFilters([b], filters);
      return BroadcastPageResult(
        broadcasts: filtered,
        hasMore: false,
        cursor: doc,
      );
    }

    // Prefer stream start time when available; fall back to createdAt.
    try {
      query = query.orderBy('stream.startedAt', descending: sort.descending);
    } catch (_) {
      query = query.orderBy('createdAt', descending: true);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await query.limit(limit * 3).get();
    } on FirebaseException {
      var fallback =
          _matches.orderBy(FieldPath.documentId).limit(limit * 3);
      if (appType == AdminAppType.organizationAdmin &&
          actor?.organizationId != null) {
        fallback = _matches
            .where('organizationId', isEqualTo: actor!.organizationId)
            .limit(limit * 3);
      }
      snap = await fallback.get();
    }

    var broadcasts = snap.docs
        .map((d) => ManagedBroadcast.fromFirestore(id: d.id, map: d.data()))
        .where((b) => b.hasBroadcastActivity)
        .toList();
    broadcasts = _applyClientFilters(broadcasts, filters);
    _sortInPlace(broadcasts, sort);

    final hasMore = broadcasts.length > limit;
    final page = hasMore ? broadcasts.sublist(0, limit) : broadcasts;
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    if (page.isNotEmpty) {
      final lastId = page.last.id;
      for (final d in snap.docs) {
        if (d.id == lastId) {
          cursor = d;
          break;
        }
      }
    }

    return BroadcastPageResult(
      broadcasts: page,
      hasMore: hasMore || snap.docs.length >= limit * 3,
      cursor: cursor,
    );
  }

  void _sortInPlace(List<ManagedBroadcast> list, BroadcastSort sort) {
    int cmp(ManagedBroadcast a, ManagedBroadcast b) {
      final r = switch (sort.field) {
        BroadcastSortField.matchTitle =>
          a.matchTitle.toLowerCase().compareTo(b.matchTitle.toLowerCase()),
        BroadcastSortField.startedAt => (a.streamStartedAt ?? DateTime(1970))
            .compareTo(b.streamStartedAt ?? DateTime(1970)),
        BroadcastSortField.status =>
          a.displayStatus.label.compareTo(b.displayStatus.label),
        BroadcastSortField.platform =>
          a.platform.label.compareTo(b.platform.label),
        BroadcastSortField.createdAt =>
          (a.createdAt ?? DateTime(1970)).compareTo(b.createdAt ?? DateTime(1970)),
      };
      return sort.descending ? -r : r;
    }

    list.sort(cmp);
  }

  List<ManagedBroadcast> _applyClientFilters(
    List<ManagedBroadcast> list,
    BroadcastListFilters filters,
  ) {
    Iterable<ManagedBroadcast> items = list;
    if (!filters.includeDeleted) {
      items = items.where((b) => !b.isSoftDeleted);
    }
    if (!filters.includeArchived) {
      items = items.where(
        (b) => b.recordStatus != AdminMatchRecordStatus.archived,
      );
    }

    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((b) {
        return b.matchTitle.toLowerCase().contains(q) ||
            b.id.toLowerCase().contains(q) ||
            b.organizerName.toLowerCase().contains(q) ||
            (b.organizerId?.toLowerCase().contains(q) ?? false) ||
            b.teamAName.toLowerCase().contains(q) ||
            b.teamBName.toLowerCase().contains(q) ||
            (b.tournamentName?.toLowerCase().contains(q) ?? false) ||
            (b.youtubeVideoId?.toLowerCase().contains(q) ?? false) ||
            b.platform.label.toLowerCase().contains(q) ||
            b.city.toLowerCase().contains(q) ||
            b.country.toLowerCase().contains(q);
      });
    }

    if (filters.liveOnly) {
      items = items.where((b) => b.isLive);
    }
    if (filters.statuses.isNotEmpty) {
      items = items.where((b) => filters.statuses.contains(b.displayStatus));
    }
    if (filters.platforms.isNotEmpty) {
      items = items.where((b) => filters.platforms.contains(b.platform));
    }
    if (filters.health.isNotEmpty) {
      items = items.where((b) => filters.health.contains(b.health));
    }
    if (filters.visibilities.isNotEmpty) {
      items =
          items.where((b) => filters.visibilities.contains(b.visibility));
    }
    if (filters.country?.trim().isNotEmpty == true) {
      final c = filters.country!.trim().toLowerCase();
      items = items.where((b) => b.country.toLowerCase().contains(c));
    }
    if (filters.stateProvince?.trim().isNotEmpty == true) {
      final s = filters.stateProvince!.trim().toLowerCase();
      items = items.where((b) => b.stateProvince.toLowerCase().contains(s));
    }
    if (filters.city?.trim().isNotEmpty == true) {
      final c = filters.city!.trim().toLowerCase();
      items = items.where((b) => b.city.toLowerCase().contains(c));
    }
    if (filters.from != null) {
      items = items.where(
        (b) =>
            b.streamStartedAt != null &&
            !b.streamStartedAt!.isBefore(filters.from!),
      );
    }
    if (filters.to != null) {
      items = items.where(
        (b) =>
            b.streamStartedAt != null &&
            !b.streamStartedAt!.isAfter(filters.to!),
      );
    }
    return items.toList();
  }

  bool _visibleToActor(
    ManagedBroadcast b, {
    required AdminAppType appType,
    required AdminUser? actor,
  }) {
    if (appType != AdminAppType.organizationAdmin) return true;
    final orgId = actor?.organizationId;
    if (orgId == null || orgId.isEmpty) return false;
    return b.organizationId == orgId;
  }

  Stream<ManagedBroadcast?> watchById(
    String id, {
    required AdminAppType appType,
    required AdminUser? actor,
  }) {
    return _matches.doc(id).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      final b = ManagedBroadcast.fromFirestore(id: snap.id, map: snap.data()!);
      if (!_visibleToActor(b, appType: appType, actor: actor)) return null;
      return b;
    });
  }

  Future<BroadcastSummaryStats> fetchSummary({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    Query<Map<String, dynamic>> base = _matches;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) return const BroadcastSummaryStats();
      base = base.where('organizationId', isEqualTo: orgId);
    }

    try {
      final snap = await base.limit(AdminQueryLimits.summaryScanMax).get();
      final list = snap.docs
          .map((d) => ManagedBroadcast.fromFirestore(id: d.id, map: d.data()))
          .where((b) => b.hasBroadcastActivity && !b.isSoftDeleted)
          .toList();

      return BroadcastSummaryStats(
        total: list.length,
        live: list.where((b) => b.isLive).length,
        scheduled: list
            .where((b) => b.displayStatus == ManagedBroadcastStatus.scheduled)
            .length,
        completed: list
            .where((b) => b.displayStatus == ManagedBroadcastStatus.completed)
            .length,
        failed: list
            .where((b) => b.displayStatus == ManagedBroadcastStatus.failed)
            .length,
        youtube: list
            .where((b) => b.platform == ManagedStreamPlatform.youtube)
            .length,
        facebook: list
            .where((b) => b.platform == ManagedStreamPlatform.facebook)
            .length,
        externalRtmp: list
            .where((b) => b.platform == ManagedStreamPlatform.externalRtmp)
            .length,
      );
    } catch (_) {
      return const BroadcastSummaryStats();
    }
  }

  Future<List<BroadcastTimelineItem>> fetchTimeline(ManagedBroadcast b) async {
    final items = <BroadcastTimelineItem>[];
    if (b.createdAt != null) {
      items.add(
        BroadcastTimelineItem(
          id: 'created',
          title: 'Broadcast Created',
          occurredAt: b.createdAt!,
          subtitle: b.matchTitle,
        ),
      );
    }
    if (b.streamStartedAt != null) {
      items.add(
        BroadcastTimelineItem(
          id: 'live',
          title: 'Live Started',
          occurredAt: b.streamStartedAt!,
          subtitle: b.platform.label,
        ),
      );
    }
    if (b.lastHeartbeatAt != null && b.isLive) {
      items.add(
        BroadcastTimelineItem(
          id: 'heartbeat',
          title: 'Last Heartbeat',
          occurredAt: b.lastHeartbeatAt!,
          subtitle: b.health.label,
        ),
      );
    }
    if (b.endedAt != null) {
      items.add(
        BroadcastTimelineItem(
          id: 'ended',
          title: 'Live Ended',
          occurredAt: b.endedAt!,
        ),
      );
    }
    if (b.displayStatus == ManagedBroadcastStatus.completed &&
        b.lastHeartbeatAt != null &&
        b.endedAt == null) {
      items.add(
        BroadcastTimelineItem(
          id: 'completed',
          title: 'Broadcast Completed',
          occurredAt: b.lastHeartbeatAt!,
        ),
      );
    }
    final audits = await fetchAuditForBroadcast(b.id);
    for (final a in audits) {
      items.add(
        BroadcastTimelineItem(
          id: a.id,
          title: a.action,
          occurredAt: a.timestamp,
          subtitle: a.reason ?? a.actorEmail,
        ),
      );
    }
    items.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return items;
  }

  Future<List<AdminAuditLogEntry>> fetchAuditForBroadcast(
    String matchId, {
    int limit = 30,
  }) async {
    try {
      final snap = await _audit
          .where('targetUid', isEqualTo: matchId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => AdminAuditLogEntry.fromMap(d.id, d.data()))
          .where(
            (e) =>
                e.action.startsWith('broadcast.') ||
                e.action.startsWith('match.'),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setFeatured({
    required ManagedBroadcast target,
    required bool featured,
    required AdminUser actor,
    String? reason,
  }) async {
    await _matches.doc(target.id).set({
      'adminFeatured': featured,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: featured
          ? AdminAuditActions.broadcastFeatured
          : AdminAuditActions.broadcastUnfeatured,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> softDelete({
    required ManagedBroadcast target,
    required AdminUser actor,
    String? reason,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _matches.doc(target.id).set({
      'adminRecordStatus': AdminMatchRecordStatus.deleted.wireValue,
      'adminDeletedAt': now,
      'adminDeletedBy': actor.uid,
      'updatedAt': now,
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.broadcastSoftDeleted,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> restore({
    required ManagedBroadcast target,
    required AdminUser actor,
    String? reason,
  }) async {
    await _matches.doc(target.id).set({
      'adminRecordStatus': AdminMatchRecordStatus.active.wireValue,
      'adminDeletedAt': FieldValue.delete(),
      'adminDeletedBy': FieldValue.delete(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.broadcastRestored,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> archive({
    required ManagedBroadcast target,
    required AdminUser actor,
    String? reason,
  }) async {
    await _matches.doc(target.id).set({
      'adminRecordStatus': AdminMatchRecordStatus.archived.wireValue,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.broadcastArchived,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> _writeAudit({
    required String action,
    required AdminUser actor,
    required ManagedBroadcast target,
    String? reason,
  }) async {
    final entry = AdminAuditLogEntry(
      id: '',
      action: action,
      actorUid: actor.uid,
      actorEmail: actor.email,
      targetUid: target.id,
      targetEmail: target.matchTitle,
      timestamp: DateTime.now(),
      reason: reason,
      metadata: {
        'entity': 'broadcast',
        'platform': target.platform.name,
        'streamStatus': target.streamStatus.name,
      },
    );
    await _audit.add(entry.toMap());
  }
}
