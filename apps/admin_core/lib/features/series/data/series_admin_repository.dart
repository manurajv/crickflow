import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/managed_series.dart';

class SeriesAdminRepository {
  SeriesAdminRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Future<List<ManagedSeries>> listSeries({String queryText = ''}) async {
    final snap = await _db
        .collection('series')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    final items = snap.docs
        .map((d) => ManagedSeries.fromFirestore(d.id, d.data()))
        .toList();
    final q = queryText.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.id.toLowerCase().contains(q) ||
              s.superAdminUserId.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<SeriesInvestigation?> investigate(String seriesId) async {
    final results = await Future.wait([
      _db.collection('series').doc(seriesId).get(),
      _db
          .collection('series_clubs')
          .where('seriesId', isEqualTo: seriesId)
          .limit(100)
          .get(),
      _db
          .collection('series_admins')
          .where('seriesId', isEqualTo: seriesId)
          .limit(100)
          .get(),
      _db
          .collection('series_audit_logs')
          .where('seriesId', isEqualTo: seriesId)
          .limit(100)
          .get(),
    ]);
    final seriesDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    if (!seriesDoc.exists || seriesDoc.data() == null) return null;
    List<Map<String, dynamic>> rows(int index) {
      final snap = results[index] as QuerySnapshot<Map<String, dynamic>>;
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    }

    return SeriesInvestigation(
      series: ManagedSeries.fromFirestore(seriesDoc.id, seriesDoc.data()!),
      clubs: rows(1),
      admins: rows(2),
      auditLogs: rows(3),
    );
  }

  /// Admin panel fallback because admin_core intentionally has no Functions SDK.
  Future<void> suspendSeries(
    ManagedSeries series, {
    required String actorId,
  }) async {
    final now = DateTime.now().toIso8601String();
    final batch = _db.batch();
    batch.set(_db.collection('series').doc(series.id), {
      'status': 'suspended',
      'updatedAt': now,
    }, SetOptions(merge: true));
    batch.set(_db.collection('series_audit_logs').doc(), {
      'seriesId': series.id,
      'action': 'ENTITY_SUSPENDED',
      'actorUserId': actorId,
      'actorRole': 'platformAdmin',
      'targetType': 'series',
      'targetId': series.id,
      'timestamp': now,
      'previousState': {'status': series.status},
      'newState': {'status': 'suspended'},
      'reason': 'Suspended by platform Super Admin',
      'metadata': {},
    });
    await batch.commit();
  }
}
