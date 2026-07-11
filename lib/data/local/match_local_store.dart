import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/ball_event_model.dart';
import '../models/match_model.dart';
import '../models/overlay_state_model.dart';
import 'pending_sync_action.dart';

/// Hive-backed local store for live match snapshots, ball events, and sync queue.
class MatchLocalStore {
  MatchLocalStore();

  static const _boxName = 'crickflow_match_local';
  static const _snapshotPrefix = 'snapshot:';
  static const _eventsPrefix = 'events:';
  static const _overlayPrefix = 'overlay:';
  static const _syncQueueKey = 'sync_queue';
  static const _lastSyncPrefix = 'last_sync:';

  Box<String>? _box;
  bool _initialized = false;

  final _matchControllers = <String, StreamController<MatchModel?>>{};
  final _eventsControllers =
      <String, StreamController<List<BallEventModel>>>{};
  final _overlayControllers =
      <String, StreamController<OverlayStateModel?>>{};
  final _syncMetaController = StreamController<MatchSyncMeta>.broadcast();

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  Box<String> get _storage {
    final box = _box;
    if (box == null) {
      throw StateError('MatchLocalStore not initialized');
    }
    return box;
  }

  String _snapshotKey(String matchId) => '$_snapshotPrefix$matchId';
  String _eventsKey(String matchId) => '$_eventsPrefix$matchId';
  String _overlayKey(String matchId) => '$_overlayPrefix$matchId';
  String _lastSyncKey(String matchId) => '$_lastSyncPrefix$matchId';

  Future<void> saveSnapshot({
    required String matchId,
    required MatchModel match,
    OverlayStateModel? overlay,
  }) async {
    final payload = jsonEncode({
      'match': match.toMap(),
      'savedAt': DateTime.now().toIso8601String(),
    });
    await _storage.put(_snapshotKey(matchId), payload);
    if (overlay != null) {
      await _storage.put(_overlayKey(matchId), jsonEncode(overlay.toMap()));
    }
    _emitMatch(matchId, match);
    if (overlay != null) {
      _emitOverlay(matchId, overlay);
    }
    _notifySyncMeta(matchId);
  }

  Future<void> importFromRemote({
    required MatchModel match,
    required List<BallEventModel> events,
    OverlayStateModel? overlay,
  }) async {
    await saveSnapshot(matchId: match.id, match: match, overlay: overlay);
    await setBallEvents(match.id, events);
  }

  Future<MatchModel?> getMatch(String matchId) async {
    final raw = _storage.get(_snapshotKey(matchId));
    if (raw == null) return null;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final matchMap = Map<String, dynamic>.from(decoded['match'] as Map);
    return MatchModel.fromMap(matchId, matchMap);
  }

  Future<OverlayStateModel?> getOverlay(String matchId) async {
    final raw = _storage.get(_overlayKey(matchId));
    if (raw == null) return null;
    return OverlayStateModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<List<BallEventModel>> getBallEvents(String matchId) async {
    final raw = _storage.get(_eventsKey(matchId));
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map(
          (e) => BallEventModel.fromMap(
            (e as Map<String, dynamic>)['id'] as String,
            Map<String, dynamic>.from(e),
          ),
        )
        .toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
  }

  Future<void> setBallEvents(
    String matchId,
    List<BallEventModel> events,
  ) async {
    final sorted = List<BallEventModel>.from(events)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final payload = jsonEncode(
      sorted.map((e) => {'id': e.id, ...e.toMap()}).toList(),
    );
    await _storage.put(_eventsKey(matchId), payload);
    _emitEvents(matchId, sorted);
  }

  Future<void> appendBallEvent(String matchId, BallEventModel event) async {
    final normalized = event.timestamp == null
        ? event.copyWith(timestamp: DateTime.now())
        : event;
    final events = await getBallEvents(matchId);
    if (events.any((e) => e.id == normalized.id)) return;
    events.add(normalized);
    await setBallEvents(matchId, events);
  }

  Future<void> removeBallEvents(
    String matchId,
    Iterable<String> eventIds,
  ) async {
    final remove = eventIds.toSet();
    final events = await getBallEvents(matchId);
    events.removeWhere((e) => remove.contains(e.id));
    await setBallEvents(matchId, events);
  }

  bool hasLocalSnapshot(String matchId) =>
      _storage.containsKey(_snapshotKey(matchId));

  Future<void> enqueueSync(PendingSyncAction action) async {
    final queue = await pendingActions();
    queue.add(action);
    await _persistQueue(queue);
    _notifySyncMeta(action.matchId);
  }

  Future<List<PendingSyncAction>> pendingActions({String? matchId}) async {
    final raw = _storage.get(_syncQueueKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    final actions = list
        .map((e) => PendingSyncAction.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (matchId == null) return actions;
    return actions.where((a) => a.matchId == matchId).toList();
  }

  Future<void> removeSyncAction(String actionId) async {
    final queue = await pendingActions();
    queue.removeWhere((a) => a.id == actionId);
    await _persistQueue(queue);
  }

  Future<void> updateSyncAction(PendingSyncAction action) async {
    final queue = await pendingActions();
    final idx = queue.indexWhere((a) => a.id == action.id);
    if (idx < 0) return;
    queue[idx] = action;
    await _persistQueue(queue);
  }

  int pendingCountForMatch(String matchId) {
    final raw = _storage.get(_syncQueueKey);
    if (raw == null) return 0;
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => PendingSyncAction.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((a) => a.matchId == matchId)
        .length;
  }

  int totalPendingCount() {
    final raw = _storage.get(_syncQueueKey);
    if (raw == null) return 0;
    return (jsonDecode(raw) as List).length;
  }

  bool hasPendingSync(String matchId) => pendingCountForMatch(matchId) > 0;

  DateTime? lastSyncAt(String matchId) {
    final raw = _storage.get(_lastSyncKey(matchId));
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setLastSyncAt(String matchId, DateTime time) async {
    await _storage.put(_lastSyncKey(matchId), time.toIso8601String());
    _notifySyncMeta(matchId);
  }

  Stream<MatchModel?> watchMatch(String matchId) {
    return _matchStream(matchId).stream;
  }

  Stream<List<BallEventModel>> watchBallEvents(String matchId) {
    return _eventsStream(matchId).stream;
  }

  Stream<OverlayStateModel?> watchOverlay(String matchId) {
    return _overlayStream(matchId).stream;
  }

  Stream<MatchSyncMeta> watchSyncMeta(String matchId) {
    return _syncMetaController.stream.where((m) => m.matchId == matchId);
  }

  void notifyConnectivity(ConnectivityStatus status, {String? matchId}) {
    if (matchId != null) {
      _notifySyncMeta(matchId, status: status);
      return;
    }
    for (final key in _storage.keys) {
      if (key.startsWith(_snapshotPrefix)) {
        final id = key.substring(_snapshotPrefix.length);
        _notifySyncMeta(id, status: status);
      }
    }
  }

  Future<void> _persistQueue(List<PendingSyncAction> queue) async {
    await _storage.put(
      _syncQueueKey,
      jsonEncode(queue.map((a) => a.toMap()).toList()),
    );
  }

  void _notifySyncMeta(String matchId, {ConnectivityStatus? status}) {
    if (_syncMetaController.isClosed) return;
    _syncMetaController.add(
      MatchSyncMeta(
        matchId: matchId,
        pendingCount: pendingCountForMatch(matchId),
        lastSyncAt: lastSyncAt(matchId),
        status: status ?? ConnectivityStatus.online,
      ),
    );
  }

  StreamController<MatchModel?> _matchStream(String matchId) {
    return _matchControllers.putIfAbsent(
      matchId,
      () {
        final controller = StreamController<MatchModel?>.broadcast();
        unawaited(getMatch(matchId).then(controller.add));
        return controller;
      },
    );
  }

  StreamController<List<BallEventModel>> _eventsStream(String matchId) {
    return _eventsControllers.putIfAbsent(
      matchId,
      () {
        final controller =
            StreamController<List<BallEventModel>>.broadcast();
        unawaited(getBallEvents(matchId).then(controller.add));
        return controller;
      },
    );
  }

  StreamController<OverlayStateModel?> _overlayStream(String matchId) {
    return _overlayControllers.putIfAbsent(
      matchId,
      () {
        final controller = StreamController<OverlayStateModel?>.broadcast();
        unawaited(getOverlay(matchId).then(controller.add));
        return controller;
      },
    );
  }

  void _emitMatch(String matchId, MatchModel? match) {
    final controller = _matchControllers[matchId];
    if (controller != null && !controller.isClosed) {
      controller.add(match);
    }
  }

  void _emitEvents(String matchId, List<BallEventModel> events) {
    final controller = _eventsControllers[matchId];
    if (controller != null && !controller.isClosed) {
      controller.add(events);
    }
  }

  void _emitOverlay(String matchId, OverlayStateModel? overlay) {
    final controller = _overlayControllers[matchId];
    if (controller != null && !controller.isClosed) {
      controller.add(overlay);
    }
  }

  void dispose() {
    for (final c in _matchControllers.values) {
      c.close();
    }
    for (final c in _eventsControllers.values) {
      c.close();
    }
    for (final c in _overlayControllers.values) {
      c.close();
    }
    _syncMetaController.close();
  }
}
