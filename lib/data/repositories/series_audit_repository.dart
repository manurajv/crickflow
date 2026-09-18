import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/series/series.dart';

/// Read-only access to server-authored Series audit records.
class SeriesAuditRepository {
  SeriesAuditRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<SeriesAuditLogModel>> watchAuditLogs(String seriesId) {
    return _firestore
        .collection(AppConstants.seriesAuditLogsCollection)
        .where('seriesId', isEqualTo: seriesId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SeriesAuditLogModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }
}
