import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/series/series.dart';
import '../services/series_functions_service.dart';

class SeriesApprovalRepository {
  SeriesApprovalRepository({
    FirebaseFirestore? firestore,
    SeriesFunctionsService? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? SeriesFunctionsService();

  final FirebaseFirestore _firestore;
  final SeriesFunctionsService _functions;

  /// Path-scoped approvals — manager list queries work with canManageSeries(seriesId).
  CollectionReference<Map<String, dynamic>> _seriesApprovals(String seriesId) =>
      _firestore
          .collection(AppConstants.seriesCollection)
          .doc(seriesId)
          .collection('approvals');

  CollectionReference<Map<String, dynamic>> get _legacyApprovals =>
      _firestore.collection(AppConstants.seriesApprovalsCollection);

  Future<void> _ensureMirrored(String seriesId) async {
    try {
      await _functions.syncSeriesApprovalMirrors(seriesId: seriesId);
    } catch (_) {
      // Stream may still succeed if mirrors already exist.
    }
  }

  Stream<List<SeriesApprovalModel>> watchPendingApprovals(String seriesId) {
    return Stream.fromFuture(_ensureMirrored(seriesId)).asyncExpand((_) {
      return _seriesApprovals(seriesId)
          .where('status', isEqualTo: SeriesApprovalStatus.pending.name)
          .orderBy('requestedAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => SeriesApprovalModel.fromMap(doc.id, doc.data()))
                .toList(),
          );
    });
  }

  /// Own requests — top-level query with requestedBy is rules-safe (no manager get()).
  Stream<List<SeriesApprovalModel>> watchMyApprovals({
    required String seriesId,
    required String userId,
  }) {
    return _legacyApprovals
        .where('seriesId', isEqualTo: seriesId)
        .where('requestedBy', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) {
            final items = snapshot.docs
                .map((doc) => SeriesApprovalModel.fromMap(doc.id, doc.data()))
                .toList()
              ..sort(
                (a, b) => (b.requestedAt ?? DateTime(0))
                    .compareTo(a.requestedAt ?? DateTime(0)),
              );
            return items;
          },
        );
  }

  Future<SeriesApprovalModel?> getApproval(String approvalId) async {
    final doc = await _legacyApprovals.doc(approvalId).get();
    final data = doc.data();
    return doc.exists && data != null
        ? SeriesApprovalModel.fromMap(doc.id, data)
        : null;
  }

  /// Creates only a pending request; review fields are server-owned.
  /// Prefer callables for production writes; this path is for local/tests.
  Future<SeriesApprovalModel> createPendingApproval(
    SeriesApprovalModel approval,
  ) async {
    final ref = approval.id.isEmpty
        ? _legacyApprovals.doc()
        : _legacyApprovals.doc(approval.id);
    final data = approval.toMap()
      ..remove('reviewedBy')
      ..remove('reviewedAt')
      ..addAll({
        'status': SeriesApprovalStatus.pending.name,
        'requestedAt': (approval.requestedAt ?? DateTime.now())
            .toIso8601String(),
      });
    await ref.set(data);
    if (approval.seriesId.isNotEmpty) {
      await _seriesApprovals(approval.seriesId).doc(ref.id).set(data);
    }
    return SeriesApprovalModel.fromMap(ref.id, data);
  }

  Future<Map<String, dynamic>> reviewSeriesApproval({
    required String seriesId,
    required String approvalId,
    required SeriesApprovalStatus decision,
    String reason = '',
  }) {
    if (decision != SeriesApprovalStatus.approved &&
        decision != SeriesApprovalStatus.rejected) {
      throw ArgumentError.value(decision, 'decision', 'Must approve or reject');
    }
    return _functions.reviewSeriesApproval(
      seriesId: seriesId,
      approvalId: approvalId,
      decision: decision.name,
      reason: reason,
    );
  }
}
