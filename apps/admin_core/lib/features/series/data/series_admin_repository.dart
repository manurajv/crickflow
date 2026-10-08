import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/admin_collections.dart';
import '../../../models/admin_user.dart';
import '../models/managed_series.dart';

/// Read + moderate access to mobile Orgs (`series` and related collections).
///
/// Writes are limited to status changes that `firestore.rules` allows for
/// admins with `canManageOrganizations`, plus audit entries.
class SeriesAdminRepository {
  SeriesAdminRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _series =>
      _db.collection('series');

  Future<List<ManagedSeries>> listSeries() async {
    final snap = await _series.limit(300).get();
    final items = snap.docs
        .map((d) => ManagedSeries.fromFirestore(d.id, d.data()))
        .toList();
    items.sort((a, b) {
      final ad = a.createdAt, bd = b.createdAt;
      if (ad == null && bd == null) return a.name.compareTo(b.name);
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return items;
  }

  Future<SeriesInvestigation?> investigate(String seriesId) async {
    final results = await Future.wait<Object?>([
      _series.doc(seriesId).get(),
      _safe(
        _db
            .collection('series_admins')
            .where('seriesId', isEqualTo: seriesId)
            .limit(100),
      ),
      _safe(
        _db
            .collection('series_clubs')
            .where('seriesId', isEqualTo: seriesId)
            .limit(200),
      ),
      _safe(_series.doc(seriesId).collection('approvals').limit(100)),
      _safe(
        _db
            .collection('series_audit_logs')
            .where('seriesId', isEqualTo: seriesId)
            .limit(200),
      ),
    ]);
    final doc = results[0]! as DocumentSnapshot<Map<String, dynamic>>;
    if (!doc.exists || doc.data() == null) return null;
    List<SeriesRow> rows(int i) => results[i]! as List<SeriesRow>;
    final audit = [...rows(4)]
      ..sort((a, b) {
        final ad = a.date('timestamp'), bd = b.date('timestamp');
        if (ad == null || bd == null) return 0;
        return bd.compareTo(ad);
      });
    return SeriesInvestigation(
      series: ManagedSeries.fromFirestore(doc.id, doc.data()!),
      admins: rows(1),
      clubs: rows(2),
      approvals: rows(3),
      auditLogs: audit,
    );
  }

  /// Lists that fail (e.g. a missing permission) come back empty instead of
  /// breaking the whole investigation.
  Future<List<SeriesRow>> _safe(Query<Map<String, dynamic>> q) async {
    try {
      final snap = await q.get();
      return snap.docs.map((d) => SeriesRow(d.id, d.data())).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Suspend / restore / archive an org. Audited in the org's own audit log
  /// (visible to its owner in the app) and in `admin_audit_logs`.
  Future<void> setSeriesStatus(
    ManagedSeries series, {
    required String nextStatus,
    required AdminUser actor,
    String reason = '',
  }) async {
    if (!OrgModeration.seriesStatuses.contains(nextStatus)) {
      throw ArgumentError('Unsupported status $nextStatus');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final batch = _db.batch();
    batch.update(_series.doc(series.id), {
      'status': nextStatus,
      // Platform hold: owners cannot lift a platform suspension/archive via
      // setSeriesLifecycle until platform staff restore the org.
      'platformHold': nextStatus != 'active',
      'updatedAt': now,
    });
    _audit(
      batch,
      seriesId: series.id,
      action: OrgModeration.auditAction(nextStatus),
      targetType: 'series',
      targetId: series.id,
      previous: series.status,
      next: nextStatus,
      actor: actor,
      reason: reason,
      now: now,
      label: series.name,
    );
    await batch.commit();
  }

  /// Suspend or restore (approved) a club inside an org.
  Future<void> setClubStatus(
    String seriesId,
    SeriesRow club, {
    required String nextStatus,
    required AdminUser actor,
    String reason = '',
  }) async {
    if (!OrgModeration.clubStatuses.contains(nextStatus)) {
      throw ArgumentError('Unsupported club status $nextStatus');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final batch = _db.batch();
    batch.update(_db.collection('series_clubs').doc(club.id), {
      'status': nextStatus,
      'updatedAt': now,
    });
    _audit(
      batch,
      seriesId: seriesId,
      action: OrgModeration.auditAction(
        nextStatus == 'approved' ? 'active' : nextStatus,
      ),
      targetType: 'club',
      targetId: club.id,
      previous: club.str('status'),
      next: nextStatus,
      actor: actor,
      reason: reason,
      now: now,
      label: club.str('name', club.id),
    );
    await batch.commit();
  }

  void _audit(
    WriteBatch batch, {
    required String seriesId,
    required String action,
    required String targetType,
    required String targetId,
    required String previous,
    required String next,
    required AdminUser actor,
    required String reason,
    required String now,
    required String label,
  }) {
    final why = reason.trim().isEmpty
        ? 'Platform moderation (CrickFlow staff)'
        : reason.trim();
    batch.set(_db.collection('series_audit_logs').doc(), {
      'seriesId': seriesId,
      'action': action,
      'actorUserId': actor.uid,
      'actorRole': 'platformAdmin',
      'targetType': targetType,
      'targetId': targetId,
      'timestamp': now,
      'previousState': {'status': previous},
      'newState': {'status': next},
      'reason': why,
      'metadata': {'source': 'superadmin'},
    });
    batch.set(_db.collection(AdminCollections.adminAuditLogs).doc(), {
      'action': 'org.${action.toLowerCase()}',
      'actorUid': actor.uid,
      'actorEmail': actor.email,
      'targetUid': targetId,
      'targetEmail': '',
      'reason': why,
      'metadata': {
        'entity': 'series',
        'label': label,
        'seriesId': seriesId,
        'targetType': targetType,
        'from': previous,
        'to': next,
      },
      'timestamp': now,
    });
  }
}
