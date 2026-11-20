import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../models/series/series.dart';
import '../services/series_functions_service.dart';

const kPendingApprovalsLimit = 100;

/// Unions pending approval lists by id. Later lists win on conflicts; newest
/// [requestedAt] comes first. Used to merge the nested and legacy queues
/// without waiting for either one.
@visibleForTesting
List<SeriesApprovalModel> mergePendingApprovalLists(
  Iterable<List<SeriesApprovalModel>?> sources,
) {
  final byId = <String, SeriesApprovalModel>{};
  for (final list in sources) {
    if (list == null) continue;
    for (final item in list) {
      byId[item.id] = item;
    }
  }
  return byId.values.toList()..sort(
    (a, b) =>
        (b.requestedAt ?? DateTime(0)).compareTo(a.requestedAt ?? DateTime(0)),
  );
}

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

  /// Mirrors legacy top-level docs into the nested collection. Never awaited
  /// on the read path — it used to block first paint while every historical
  /// approval was copied.
  void _syncMirrorsInBackground(String seriesId) {
    unawaited(_syncMirrors(seriesId));
  }

  Future<void> _syncMirrors(String seriesId) async {
    try {
      await _functions.syncSeriesApprovalMirrors(seriesId: seriesId);
    } catch (_) {}
  }

  Query<Map<String, dynamic>> _pendingNestedQuery(String seriesId) =>
      _seriesApprovals(seriesId)
          .where('status', isEqualTo: SeriesApprovalStatus.pending.name)
          .orderBy('requestedAt', descending: true)
          .limit(kPendingApprovalsLimit);

  Query<Map<String, dynamic>> _pendingLegacyQuery(String seriesId) =>
      _legacyApprovals
          .where('seriesId', isEqualTo: seriesId)
          .where('status', isEqualTo: SeriesApprovalStatus.pending.name)
          .orderBy('requestedAt', descending: true)
          .limit(kPendingApprovalsLimit);

  List<SeriesApprovalModel> _mapDocs(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) => snapshot.docs
      .map((doc) => SeriesApprovalModel.fromMap(doc.id, doc.data()))
      .toList();

  Stream<List<SeriesApprovalModel>> watchPendingApprovals(String seriesId) {
    _syncMirrorsInBackground(seriesId);
    return combineLatestApprovalStreams([
      _pendingNestedQuery(seriesId).snapshots().map(_mapDocs),
      _pendingLegacyQuery(seriesId).snapshots().map(_mapDocs),
    ]);
  }

  /// Pending approvals for one org team. Org staff and that team's admins can
  /// list these (team admins can't list the whole org's queue).
  Stream<List<SeriesApprovalModel>> watchPendingClubApprovals({
    required String seriesId,
    required String clubId,
  }) {
    return _seriesApprovals(seriesId)
        .where('clubId', isEqualTo: clubId)
        .where('status', isEqualTo: SeriesApprovalStatus.pending.name)
        .limit(kPendingApprovalsLimit)
        .snapshots()
        .map((snapshot) {
          final items = _mapDocs(snapshot)
            ..sort(
              (a, b) => (b.requestedAt ?? DateTime(0)).compareTo(
                a.requestedAt ?? DateTime(0),
              ),
            );
          return items;
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
        .limit(kPendingApprovalsLimit)
        .snapshots()
        .map((snapshot) {
          final items = _mapDocs(snapshot)
            ..sort(
              (a, b) => (b.requestedAt ?? DateTime(0)).compareTo(
                a.requestedAt ?? DateTime(0),
              ),
            );
          return items;
        });
  }

  Future<SeriesApprovalModel?> getApproval(String approvalId) async {
    final doc = await _legacyApprovals.doc(approvalId).get();
    final data = doc.data();
    return doc.exists && data != null
        ? SeriesApprovalModel.fromMap(doc.id, data)
        : null;
  }

  /// Nested path — team admins can read their club's requests here.
  Stream<SeriesApprovalModel?> watchApproval({
    required String seriesId,
    required String approvalId,
  }) {
    if (seriesId.isEmpty || approvalId.isEmpty) {
      return Stream.value(null);
    }
    return _seriesApprovals(seriesId).doc(approvalId).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return SeriesApprovalModel.fromMap(doc.id, data);
    });
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

/// Emits the merged list as soon as any source has data. If every source
/// errors, the first error is forwarded (the UI can show Retry). A single
/// permission-denied source is treated as empty so the other queue can paint.
@visibleForTesting
Stream<List<SeriesApprovalModel>> combineLatestApprovalStreams(
  List<Stream<List<SeriesApprovalModel>>> sources,
) {
  if (sources.isEmpty) return Stream.value(const []);
  late StreamController<List<SeriesApprovalModel>> controller;
  final latest = List<List<SeriesApprovalModel>?>.filled(sources.length, null);
  final failed = List<bool>.filled(sources.length, false);
  final done = List<bool>.filled(sources.length, false);
  final subs = <StreamSubscription<List<SeriesApprovalModel>>>[];
  Object? firstError;
  StackTrace? firstStack;

  void emitOrError() {
    if (failed.every((f) => f)) {
      controller.addError(
        firstError ?? StateError('Could not load approvals'),
        firstStack,
      );
      return;
    }
    final merged = <List<SeriesApprovalModel>?>[];
    var hasData = false;
    for (var i = 0; i < sources.length; i++) {
      if (failed[i]) {
        merged.add(const []);
      } else {
        merged.add(latest[i]);
        if (latest[i] != null) hasData = true;
      }
    }
    if (!hasData) return;
    controller.add(mergePendingApprovalLists(merged));
  }

  controller = StreamController<List<SeriesApprovalModel>>(
    onListen: () {
      for (var i = 0; i < sources.length; i++) {
        final index = i;
        subs.add(
          sources[index].listen(
            (value) {
              latest[index] = value;
              failed[index] = false;
              emitOrError();
            },
            onError: (Object error, StackTrace stack) {
              failed[index] = true;
              firstError ??= error;
              firstStack ??= stack;
              emitOrError();
            },
            onDone: () {
              done[index] = true;
              if (done.every((d) => d) && !controller.isClosed) {
                controller.close();
              }
            },
            cancelOnError: false,
          ),
        );
      }
    },
    onCancel: () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    },
  );
  return controller.stream;
}
