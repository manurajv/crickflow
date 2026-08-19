import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
    FirebaseAuth? auth,
    PublicScorecardSync? publicScorecardSync,
    Uuid? uuid,
  })  : _localStore = localStore,
        _connectivity = connectivity,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _publicSync = publicScorecardSync ?? PublicScorecardSync(),
        _uuid = uuid ?? const Uuid();

  final MatchLocalStore _localStore;
  final ConnectivityService _connectivity;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final PublicScorecardSync _publicSync;
  final Uuid _uuid;

  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<User?>? _authSub;
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
    _authSub?.cancel();
    _connectivitySub = _connectivity.onStatusChanged.listen((online) {
      if (online) {
        unawaited(flush());
      } else {
        _emitStatus(ConnectivityStatus.offline);
      }
    });
    // Auth can restore after connectivity; flush again once the user is signed in.
    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null && _connectivity.isOnline) {
        unawaited(flush());
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

    final user = await _waitForSignedInUser();
    if (user == null) {
      debugPrint('OfflineSyncService: skip flush — auth not ready');
      _emitStatus(ConnectivityStatus.online);
      return;
    }

    try {
      await user.getIdToken(true);
    } catch (e) {
      debugPrint('OfflineSyncService: token refresh failed: $e');
    }

    final pending = await _localStore.pendingActions(matchId: matchId);
    if (pending.isEmpty) {
      _emitStatus(ConnectivityStatus.online);
      return;
    }

    _flushing = true;
    _emitStatus(ConnectivityStatus.syncing);
    try {
      final preparedMatches = <String>{};
      for (final action in pending) {
        try {
          if (preparedMatches.add(action.matchId)) {
            await _ensureScorerCanSync(action.matchId, user.uid);
          }
          await _execute(action);
          await _localStore.removeSyncAction(action.id);
          await _localStore.setLastSyncAt(action.matchId, DateTime.now());
        } catch (e, st) {
          debugPrint('OfflineSyncService: flush failed for ${action.id}: $e\n$st');
          final retried = action.copyWith(attemptCount: action.attemptCount + 1);
          await _localStore.updateSyncAction(retried);

          // One recovery pass: refresh auth + reclaim ownership, then retry once.
          if (_isPermissionDenied(e) && action.attemptCount < 2) {
            try {
              await user.getIdToken(true);
              await _ensureScorerCanSync(action.matchId, user.uid);
              await _execute(action);
              await _localStore.removeSyncAction(action.id);
              await _localStore.setLastSyncAt(action.matchId, DateTime.now());
              continue;
            } catch (e2) {
              debugPrint('OfflineSyncService: retry failed: $e2');
              await _localStore.setSyncError(
                action.matchId,
                _userFacingSyncError(e2),
              );
              break;
            }
          }

          await _localStore.setSyncError(
            action.matchId,
            _userFacingSyncError(e),
          );
          break;
        }
      }
    } finally {
      _flushing = false;
      _emitStatus(currentStatus);
    }
  }

  Future<User?> _waitForSignedInUser({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final current = _auth.currentUser;
    if (current != null) return current;
    try {
      return await _auth
          .authStateChanges()
          .where((u) => u != null)
          .cast<User>()
          .first
          .timeout(timeout);
    } catch (_) {
      return _auth.currentUser;
    }
  }

  /// Makes sure the signed-in user is authorized to write scoring docs before
  /// flushing the queue (avoids PERMISSION_DENIED after offline/reopen).
  Future<void> _ensureScorerCanSync(String matchId, String uid) async {
    final snap = await _matchDoc(matchId).get();
    if (!snap.exists) return;

    final remote = snap.data() ?? const <String, dynamic>{};
    final remoteScorer = (remote['currentScorerId'] as String?)?.trim() ?? '';
    if (remoteScorer == uid) {
      // Already the active scorer — do not write a pre-flight patch (that can
      // fail validation on older match docs and block the whole sync queue).
      return;
    }

    final local = await _localStore.getMatch(matchId);
    final canClaim = _canClaimScorerOwnership(remote: remote, local: local, uid: uid);
    if (!canClaim) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message:
            'Another scorer owns this match. Ask them to transfer scoring, then sync again.',
      );
    }

    final patch = <String, dynamic>{
      'currentScorerId': uid,
      'scorerIds': FieldValue.arrayUnion([uid]),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (local != null && local.currentScorerName.isNotEmpty) {
      patch['currentScorerName'] = local.currentScorerName;
    }
    if (local?.currentScorerPhoto != null &&
        local!.currentScorerPhoto!.isNotEmpty) {
      patch['currentScorerPhoto'] = local.currentScorerPhoto;
    }

    final remoteToken = (remote['scorerOwnershipToken'] as String?)?.trim();
    if (remoteScorer.isEmpty) {
      // Soft claim on legacy / unclaimed matches.
      patch['scorerOwnershipToken'] = (remoteToken != null && remoteToken.isNotEmpty)
          ? remoteToken
          : (local?.scorerOwnershipToken ?? _uuid.v4());
      await _matchDoc(matchId).update(patch);
      return;
    }

    // Takeover: token must stay unchanged for Firestore rules.
    if (remoteToken == null || remoteToken.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message:
            'Cannot reclaim scoring ownership. Open the match and take over scoring, then sync.',
      );
    }
    patch['scorerOwnershipToken'] = remoteToken;
    await _matchDoc(matchId).update(patch);
  }

  bool _canClaimScorerOwnership({
    required Map<String, dynamic> remote,
    required MatchModel? local,
    required String uid,
  }) {
    if ((remote['createdBy'] as String?) == uid) return true;
    if ((remote['scorer1UserId'] as String?) == uid) return true;
    if ((remote['scorer2UserId'] as String?) == uid) return true;
    if (_stringList(remote['scorerIds']).contains(uid)) return true;
    if (_isOfficialScorer(remote, uid)) return true;

    if (local == null) return false;
    if (local.createdBy == uid) return true;
    if (local.scorer1UserId == uid || local.scorer2UserId == uid) return true;
    if (local.scorerIds.contains(uid)) return true;
    if (local.currentScorerId == uid) return true;
    return false;
  }

  bool _isOfficialScorer(Map<String, dynamic> remote, String uid) {
    final officials = remote['officials'];
    if (officials is! Map) return false;
    final map = Map<String, dynamic>.from(officials);
    bool entryMatches(dynamic entry) {
      if (entry is! Map) return false;
      return (entry['userId'] as String?) == uid;
    }

    final scorers = map['scorers'];
    if (scorers is List && scorers.any(entryMatches)) return true;
    if (entryMatches(map['scorer1']) || entryMatches(map['scorer2'])) {
      return true;
    }
    return false;
  }

  List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  bool _isPermissionDenied(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }
    final text = error.toString().toLowerCase();
    return text.contains('permission-denied') ||
        text.contains('permission_denied') ||
        text.contains('missing or insufficient permissions');
  }

  String _userFacingSyncError(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Sync blocked — check you are still the active scorer, then try again.';
      }
      if (error.code == 'unauthenticated') {
        return 'Sign in again to sync pending scores.';
      }
      return error.message ?? error.code;
    }
    return error.toString();
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

  Map<String, dynamic> _sanitizeMatchData(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    data.remove('streamKey');
    data.remove('rtmpUrl');
    final stream = data['stream'];
    if (stream is Map) {
      final cleaned = Map<String, dynamic>.from(stream);
      cleaned['streamKey'] = '';
      cleaned['rtmpUrl'] = '';
      data['stream'] = cleaned;
    }
    if (data['activeMatchBreak'] == null) {
      data.remove('activeMatchBreak');
    }
    final rules = data['rules'];
    if (rules is Map) {
      data['rules'] = _sanitizeRules(Map<String, dynamic>.from(rules));
    }
    _coerceIntFields(data, const [
      'overlayVersion',
      'currentInningsIndex',
    ]);
    return data;
  }

  /// Ball/undo/overlay sync must not rewrite the full match doc (rules/squads/
  /// stream). Full rewrites often fail Firestore validation as PERMISSION_DENIED
  /// even for the active scorer.
  Map<String, dynamic> _scoringPatch(Map<String, dynamic> full) {
    const keys = <String>{
      'innings',
      'currentInningsIndex',
      'status',
      'overlayVersion',
      'updatedAt',
      'overNotes',
      'overMetadata',
      'targetState',
      'activeMatchBreak',
      'matchBreakHistory',
      'winnerTeamId',
      'resultSummary',
      'completedAt',
      'startedAt',
      'currentScorerId',
      'currentScorerName',
      'currentScorerPhoto',
      'scorerIds',
      'scorerOwnershipToken',
      'lastScorerTransferAt',
      'scorerTransferHistory',
      'badgeIds',
      'matchHero',
      'playerOfMatchId',
      'publicMatchId',
    };
    final patch = <String, dynamic>{};
    for (final key in keys) {
      if (!full.containsKey(key)) continue;
      final value = full[key];
      if (key == 'activeMatchBreak' && value == null) continue;
      patch[key] = value;
    }
    patch['updatedAt'] =
        full['updatedAt'] ?? DateTime.now().toIso8601String();
    return _sanitizeMatchData(patch);
  }

  static const _allowedRuleKeys = <String>{
    'format',
    'cricketMatchType',
    'ballType',
    'totalOvers',
    'ballsPerOver',
    'playersPerTeam',
    'oversPerBowler',
    'isManualOversPerBowler',
    'wideRuns',
    'noBallRuns',
    'freeHitEnabled',
    'wicketKeeperCanBowl',
    'maxInnings',
    'maxWickets',
    'superOverEnabled',
    'powerplayOvers',
    'powerplaySlot1',
    'powerplaySlot2',
    'powerplaySlot3',
    'powerplayLabels',
    'wagonWheelEnabled',
    'wagonWheelDots',
    'wagonWheelRuns123',
    'wagonWheelShotSelection',
    'wideCountsAsLegalDelivery',
    'noBallCountsAsLegalDelivery',
    'impactPlayerEnabled',
    'pitchType',
    'matchOfficials',
    'pointsPerWin',
    'pointsPerTie',
    'pointsPerLoss',
    'extrasCountToBowler',
    'lastManStanding',
    'notes',
  };

  static const _intRuleKeys = <String>{
    'totalOvers',
    'ballsPerOver',
    'playersPerTeam',
    'oversPerBowler',
    'wideRuns',
    'noBallRuns',
    'maxInnings',
    'maxWickets',
    'powerplayOvers',
    'pointsPerWin',
    'pointsPerTie',
    'pointsPerLoss',
  };

  Map<String, dynamic> _sanitizeRules(Map<String, dynamic> rules) {
    final out = <String, dynamic>{};
    for (final entry in rules.entries) {
      if (!_allowedRuleKeys.contains(entry.key)) continue;
      var value = entry.value;
      if (_intRuleKeys.contains(entry.key) && value is num) {
        value = value.toInt();
      }
      if (entry.key.startsWith('powerplaySlot') && value is List) {
        value = value.map((e) => e is num ? e.toInt() : e).toList();
      }
      out[entry.key] = value;
    }
    return out;
  }

  void _coerceIntFields(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) data[key] = value.toInt();
    }
  }

  Future<void> _executeBallCommit(PendingSyncAction action) async {
    final matchId = action.matchId;
    final fullMatchData = Map<String, dynamic>.from(
      action.payload['matchData'] as Map,
    );
    final matchData = _scoringPatch(fullMatchData);
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

    final match = MatchModel.fromMap(matchId, {
      ...fullMatchData,
      ...matchData,
    });
    final overlay = OverlayStateModel.fromMap(overlayData);
    await _syncPublicScorecard(match, overlay: overlay);
  }

  Future<void> _executeUndoBalls(PendingSyncAction action) async {
    final matchId = action.matchId;
    final fullMatchData = Map<String, dynamic>.from(
      action.payload['matchData'] as Map,
    );
    final matchData = _scoringPatch(fullMatchData);
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

    final match = MatchModel.fromMap(matchId, {
      ...fullMatchData,
      ...matchData,
    });
    final overlay = OverlayStateModel.fromMap(overlayData);
    await _syncPublicScorecard(match, overlay: overlay);
  }

  Future<void> _executeMatchOverlay(PendingSyncAction action) async {
    final matchId = action.matchId;
    final fullMatchData = Map<String, dynamic>.from(
      action.payload['matchData'] as Map,
    );
    final matchData = _scoringPatch(fullMatchData);
    final overlayData = Map<String, dynamic>.from(
      action.payload['overlayData'] as Map,
    );

    final batch = _firestore.batch();
    batch.update(_matchDoc(matchId), matchData);
    batch.set(_overlayDoc(matchId), overlayData);
    await batch.commit();

    final match = MatchModel.fromMap(matchId, {
      ...fullMatchData,
      ...matchData,
    });
    final overlay = OverlayStateModel.fromMap(overlayData);
    await _syncPublicScorecard(match, overlay: overlay);
  }

  Future<void> _executeMatchUpdate(PendingSyncAction action) async {
    final matchId = action.matchId;
    final rawMatchData = _sanitizeMatchData(
      Map<String, dynamic>.from(action.payload['matchData'] as Map),
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
      final data = op.data == null
          ? null
          : (op.collection == AppConstants.matchesCollection &&
                  op.subcollection == null
              ? _sanitizeMatchData(Map<String, dynamic>.from(op.data!))
              : Map<String, dynamic>.from(op.data!));
      switch (op.op) {
        case 'set':
          batch.set(ref, data ?? {}, SetOptions(merge: op.merge));
        case 'update':
          batch.update(ref, data ?? {});
        case 'delete':
          batch.delete(ref);
      }

      if (op.collection == AppConstants.matchesCollection &&
          op.docId == action.matchId &&
          op.subcollection == null &&
          data != null &&
          (op.op == 'set' || op.op == 'update')) {
        matchForPublicSync = MatchModel.fromMap(action.matchId, data);
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
    _authSub?.cancel();
    _statusController.close();
  }
}
