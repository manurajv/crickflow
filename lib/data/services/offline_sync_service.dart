import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../local/match_local_store.dart';
import '../local/pending_sync_action.dart';
import '../models/match_model.dart';
import '../models/overlay_state_model.dart';
import '../services/public_scorecard_sync.dart';
import 'connectivity_service.dart';

/// Flushes locally queued scoring actions to Firestore when online.
class OfflineSyncService {
  OfflineSyncService({
    required MatchLocalStore localStore,
    required ConnectivityService connectivity,
    FirebaseFirestore? firestore,
    PublicScorecardSync? publicScorecardSync,
    Uuid? uuid,
  })  : _localStore = localStore,
        _connectivity = connectivity,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _publicSync = publicScorecardSync ?? PublicScorecardSync(),
        _uuid = uuid ?? const Uuid();

  final MatchLocalStore _localStore;
  final ConnectivityService _connectivity;
  final FirebaseFirestore _firestore;
  final PublicScorecardSync _publicSync;
  final Uuid _uuid;

  StreamSubscription<bool>? _connectivitySub;
  bool _flushing = false;
  final _statusController = StreamController<ConnectivityStatus>.broadcast();

  Stream<ConnectivityStatus> get onSyncStatusChanged => _statusController.stream;

  ConnectivityStatus get currentStatus {
    if (_flushing) return ConnectivityStatus.syncing;
    return _connectivity.isOnline
        ? ConnectivityStatus.online
        : ConnectivityStatus.offline;
  }

  void start() {
    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onStatusChanged.listen((online) {
      if (online) {
        unawaited(flush());
      } else {
        _emitStatus(ConnectivityStatus.offline);
      }
    });
    _emitStatus(currentStatus);
    if (_connectivity.isOnline) {
      unawaited(flush());
    }
  }

  Future<void> enqueue(PendingSyncAction action) async {
    await _localStore.enqueueSync(action);
    if (_connectivity.isOnline) {
      unawaited(flush(matchId: action.matchId));
    }
  }

  PendingSyncAction newAction({
    required String matchId,
    required String type,
    required Map<String, dynamic> payload,
  }) {
    return PendingSyncAction(
      id: _uuid.v4(),
      matchId: matchId,
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    );
  }

  Future<void> flush({String? matchId}) async {
    if (!_connectivity.isOnline || _flushing) return;
    final pending = await _localStore.pendingActions(matchId: matchId);
    if (pending.isEmpty) {
      _emitStatus(ConnectivityStatus.online);
      return;
    }

    _flushing = true;
    _emitStatus(ConnectivityStatus.syncing);
    try {
      for (final action in pending) {
        try {
          await _execute(action);
          await _localStore.removeSyncAction(action.id);
          await _localStore.setLastSyncAt(action.matchId, DateTime.now());
        } catch (_) {
          final retried = action.copyWith(attemptCount: action.attemptCount + 1);
          await _localStore.updateSyncAction(retried);
          break;
        }
      }
    } finally {
      _flushing = false;
      _emitStatus(currentStatus);
    }
  }

  Future<void> _execute(PendingSyncAction action) async {
    switch (action.type) {
      case SyncActionType.ballCommit:
        await _executeBallCommit(action);
      case SyncActionType.undoBalls:
        await _executeUndoBalls(action);
      case SyncActionType.matchOverlay:
        await _executeMatchOverlay(action);
      case SyncActionType.matchUpdate:
        await _executeMatchUpdate(action);
      case SyncActionType.firestoreBatch:
        await _executeFirestoreBatch(action);
      default:
        throw UnsupportedError('Unknown sync action: ${action.type}');
    }
  }

  Future<void> _executeBallCommit(PendingSyncAction action) async {
    final matchId = action.matchId;
    final matchData = Map<String, dynamic>.from(
      action.payload['matchData'] as Map,
    );
    final eventId = action.payload['eventId'] as String;
    final eventData = Map<String, dynamic>.from(
      action.payload['eventData'] as Map,
    );
    final overlayData = Map<String, dynamic>.from(
      action.payload['overlayData'] as Map,
    );

    final batch = _firestore.batch();
    batch.update(_matchDoc(matchId), matchData);
    batch.set(_ballEvents(matchId).doc(eventId), eventData);
    batch.set(_overlayDoc(matchId), overlayData);
    await batch.commit();

    final match = MatchModel.fromMap(matchId, matchData);
    final overlay = OverlayStateModel.fromMap(overlayData);
    await _syncPublicScorecard(match, overlay: overlay);
  }

  Future<void> _executeUndoBalls(PendingSyncAction action) async {
    final matchId = action.matchId;
    final matchData = Map<String, dynamic>.from(
      action.payload['matchData'] as Map,
    );
    final overlayData = Map<String, dynamic>.from(
      action.payload['overlayData'] as Map,
    );
    final deletedIds = (action.payload['deletedEventIds'] as List<dynamic>)
        .map((e) => e as String)
        .toList();

    final batch = _firestore.batch();
    for (final id in deletedIds) {
      batch.delete(_ballEvents(matchId).doc(id));
    }
    batch.update(_matchDoc(matchId), matchData);
    batch.set(_overlayDoc(matchId), overlayData);
    await batch.commit();

    final match = MatchModel.fromMap(matchId, matchData);
    final overlay = OverlayStateModel.fromMap(overlayData);
    await _syncPublicScorecard(match, overlay: overlay);
  }

  Future<void> _executeMatchOverlay(PendingSyncAction action) async {
    final matchId = action.matchId;
    final matchData = Map<String, dynamic>.from(
      action.payload['matchData'] as Map,
    );
    final overlayData = Map<String, dynamic>.from(
      action.payload['overlayData'] as Map,
    );

    final batch = _firestore.batch();
    batch.update(_matchDoc(matchId), matchData);
    batch.set(_overlayDoc(matchId), overlayData);
    await batch.commit();

    final match = MatchModel.fromMap(matchId, matchData);
    final overlay = OverlayStateModel.fromMap(overlayData);
    await _syncPublicScorecard(match, overlay: overlay);
  }

  Future<void> _executeMatchUpdate(PendingSyncAction action) async {
    final matchId = action.matchId;
    final rawMatchData = Map<String, dynamic>.from(
      action.payload['matchData'] as Map,
    );
    final updateData = Map<String, dynamic>.from(rawMatchData);
    final fieldDeletes = (action.payload['fieldDeletes'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const <String>[];
    for (final field in fieldDeletes) {
      updateData[field] = FieldValue.delete();
    }
    await _matchDoc(matchId).update(updateData);
    final match = MatchModel.fromMap(matchId, rawMatchData);
    await _syncPublicScorecard(match);
  }

  Future<void> _executeFirestoreBatch(PendingSyncAction action) async {
    final ops = (action.payload['operations'] as List<dynamic>)
        .map((e) => FirestoreBatchOp.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    final batch = _firestore.batch();
    MatchModel? matchForPublicSync;
    OverlayStateModel? overlayForPublicSync;

    for (final op in ops) {
      final ref = _resolveRef(op);
      switch (op.op) {
        case 'set':
          batch.set(ref, op.data ?? {}, SetOptions(merge: op.merge));
        case 'update':
          batch.update(ref, op.data ?? {});
        case 'delete':
          batch.delete(ref);
      }

      if (op.collection == AppConstants.matchesCollection &&
          op.docId == action.matchId &&
          op.subcollection == null &&
          op.data != null &&
          (op.op == 'set' || op.op == 'update')) {
        matchForPublicSync =
            MatchModel.fromMap(action.matchId, op.data!);
      }
      if (op.subcollection == 'overlay' &&
          op.subDocId == 'current' &&
          op.data != null) {
        overlayForPublicSync = OverlayStateModel.fromMap(op.data!);
      }
    }

    await batch.commit();
    if (matchForPublicSync != null) {
      await _syncPublicScorecard(
        matchForPublicSync,
        overlay: overlayForPublicSync,
      );
    }
  }

  DocumentReference<Map<String, dynamic>> _resolveRef(FirestoreBatchOp op) {
    var ref = _firestore.collection(op.collection).doc(op.docId);
    if (op.subcollection != null && op.subDocId != null) {
      ref = ref.collection(op.subcollection!).doc(op.subDocId!);
    }
    return ref;
  }

  DocumentReference<Map<String, dynamic>> _matchDoc(String matchId) =>
      _firestore.collection(AppConstants.matchesCollection).doc(matchId);

  CollectionReference<Map<String, dynamic>> _ballEvents(String matchId) =>
      _matchDoc(matchId).collection('ball_events');

  DocumentReference<Map<String, dynamic>> _overlayDoc(String matchId) =>
      _matchDoc(matchId).collection('overlay').doc('current');

  Future<void> _syncPublicScorecard(
    MatchModel match, {
    OverlayStateModel? overlay,
  }) async {
    try {
      await _publicSync.syncFromMatch(match, overlay: overlay);
    } catch (_) {
      // Non-fatal.
    }
  }

  void _emitStatus(ConnectivityStatus status) {
    if (_statusController.isClosed) return;
    _statusController.add(status);
    _localStore.notifyConnectivity(status);
  }

  void dispose() {
    _connectivitySub?.cancel();
    _statusController.close();
  }
}
