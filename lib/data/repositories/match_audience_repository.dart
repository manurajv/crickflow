import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks match page views and live audience presence.
class MatchAudienceRepository {
  MatchAudienceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Set<String> _recordedViews = {};
  final Map<String, Timer> _heartbeats = {};

  DocumentReference<Map<String, dynamic>> _engagementStats(String matchId) =>
      _firestore
          .collection('matches')
          .doc(matchId)
          .collection('engagement')
          .doc('stats');

  CollectionReference<Map<String, dynamic>> _liveAudience(String matchId) =>
      _firestore.collection('matches').doc(matchId).collection('liveAudience');

  /// Counts once per app session when the match hub opens.
  Future<void> recordView(String matchId) async {
    if (matchId.isEmpty || _recordedViews.contains(matchId)) return;
    _recordedViews.add(matchId);
    try {
      await _engagementStats(matchId).set(
        {
          'totalViews': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      _recordedViews.remove(matchId);
    }
  }

  /// Marks the signed-in user as actively watching a live match.
  Future<void> joinLiveAudience({
    required String matchId,
    required String userId,
  }) async {
    if (matchId.isEmpty || userId.isEmpty) return;
    _heartbeats[matchId]?.cancel();

    final doc = _liveAudience(matchId).doc(userId);
    try {
      await doc.set(
        {'lastSeen': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      return;
    }

    _heartbeats[matchId] = Timer.periodic(const Duration(seconds: 30), (_) {
      doc.update({'lastSeen': FieldValue.serverTimestamp()}).catchError((_) {});
    });
  }

  Future<void> leaveLiveAudience({
    required String matchId,
    required String userId,
  }) async {
    if (matchId.isEmpty || userId.isEmpty) return;
    _heartbeats.remove(matchId)?.cancel();
    try {
      await _liveAudience(matchId).doc(userId).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }
  }

  Stream<int> watchTotalViews(String matchId) {
    if (matchId.isEmpty) return Stream.value(0);
    return _engagementStats(matchId).snapshots().map((doc) {
      if (!doc.exists) return 0;
      final raw = doc.data()?['totalViews'];
      if (raw is num) return raw.toInt();
      return 0;
    });
  }

  Stream<int> watchLiveViewerCount(String matchId) {
    if (matchId.isEmpty) return Stream.value(0);
    return _liveAudienceTicker(matchId);
  }

  /// Re-counts active viewers on each snapshot and every 30s so stale
  /// entries drop off even when the collection doc set is unchanged.
  Stream<int> _liveAudienceTicker(String matchId) {
    late StreamController<int> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? snapshotSub;
    Timer? tick;

    controller = StreamController<int>(
      onListen: () {
        void emit(QuerySnapshot<Map<String, dynamic>> snap) {
          if (!controller.isClosed) {
            controller.add(_countActiveViewers(snap));
          }
        }

        snapshotSub = _liveAudience(matchId).snapshots().listen(
          emit,
          onError: (_) {
            if (!controller.isClosed) controller.add(0);
          },
        );
        tick = Timer.periodic(const Duration(seconds: 30), (_) async {
          try {
            final snap = await _liveAudience(matchId).get();
            emit(snap);
          } catch (_) {
            if (!controller.isClosed) controller.add(0);
          }
        });
      },
      onCancel: () async {
        tick?.cancel();
        await snapshotSub?.cancel();
      },
    );

    return controller.stream;
  }

  static int _countActiveViewers(QuerySnapshot<Map<String, dynamic>> snap) {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
    var count = 0;
    for (final doc in snap.docs) {
      final lastSeen = doc.data()['lastSeen'];
      if (lastSeen is Timestamp && lastSeen.toDate().isAfter(cutoff)) {
        count++;
      }
    }
    return count;
  }

  void dispose() {
    for (final timer in _heartbeats.values) {
      timer.cancel();
    }
    _heartbeats.clear();
  }
}
