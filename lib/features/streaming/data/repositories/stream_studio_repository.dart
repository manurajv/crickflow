import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/replay_marker_model.dart';
import '../models/saved_rtmp_server.dart';
import '../models/saved_stream_key.dart';
import '../models/saved_stream_studio_preferences.dart';
import '../models/stream_studio_config.dart';
import '../../domain/streaming_enums.dart';

class StreamStudioRepository {
  StreamStudioRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _savedServersKey = 'crickflow_saved_rtmp_servers';
  static const _streamKeyHistoryKey = 'crickflow_stream_key_history';
  static const _lastStudioPreferencesKey = 'crickflow_last_studio_preferences';
  static const _maxStreamKeyHistory = 24;

  CollectionReference<Map<String, dynamic>> _markers(String matchId) =>
      _firestore.collection('matches').doc(matchId).collection('replayMarkers');

  Stream<List<ReplayMarkerModel>> watchReplayMarkers(String matchId) {
    return _markers(matchId)
        .orderBy('streamOffsetMs', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReplayMarkerModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> addReplayMarker(ReplayMarkerModel marker) async {
    await _markers(marker.matchId).doc(marker.id).set(marker.toMap());
  }

  Future<List<SavedRtmpServer>> loadSavedRtmpServers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_savedServersKey) ?? const [];
    return raw
        .map((s) => SavedRtmpServer.fromMap(
              jsonDecode(s) as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<void> saveRtmpServer(SavedRtmpServer server) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSavedRtmpServers();
    final updated = [
      server,
      ...existing.where((e) => e.id != server.id),
    ];
    await prefs.setStringList(
      _savedServersKey,
      updated.map((e) => jsonEncode(e.toMap())).toList(),
    );
  }

  Future<void> deleteRtmpServer(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSavedRtmpServers();
    await prefs.setStringList(
      _savedServersKey,
      existing
          .where((e) => e.id != id)
          .map((e) => jsonEncode(e.toMap()))
          .toList(),
    );
  }

  Future<List<SavedStreamKey>> loadStreamKeyHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_streamKeyHistoryKey) ?? const [];
    return raw
        .map((s) => SavedStreamKey.fromMap(
              jsonDecode(s) as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<List<SavedStreamKey>> loadStreamKeyHistoryForPlatform(
    StreamPlatform platform,
  ) async {
    final all = await loadStreamKeyHistory();
    return all.where((e) => e.platform == platform).toList();
  }

  Future<void> rememberStreamKey(SavedStreamKey entry) async {
    if (entry.streamKey.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadStreamKeyHistory();
    final normalizedKey = entry.streamKey.trim();
    final updated = [
      entry.copyWithLastUsed(DateTime.now()),
      ...existing.where(
        (e) =>
            !(e.platform == entry.platform &&
                e.streamKey.trim() == normalizedKey),
      ),
    ].take(_maxStreamKeyHistory).toList();
    await prefs.setStringList(
      _streamKeyHistoryKey,
      updated.map((e) => jsonEncode(e.toMap())).toList(),
    );
  }

  Future<void> deleteStreamKeyHistoryEntry(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadStreamKeyHistory();
    await prefs.setStringList(
      _streamKeyHistoryKey,
      existing
          .where((e) => e.id != id)
          .map((e) => jsonEncode(e.toMap()))
          .toList(),
    );
  }

  Future<SavedStreamStudioPreferences?> loadLastStudioPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastStudioPreferencesKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SavedStreamStudioPreferences.fromMap(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> rememberLastStudioPreferences(StreamStudioConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = SavedStreamStudioPreferences(
      platform: config.platform,
      broadcastSetupMode: config.broadcastSetupMode,
      orientation: config.orientation,
      streamingMode: config.streamingMode,
      rtmpUrl: config.rtmpUrl.trim(),
      streamKey: config.streamKey.trim(),
      youtubeChannelId: config.youtubeChannelId.trim(),
      youtubeChannelName: config.youtubeChannelName.trim(),
      goLiveImmediately: config.goLiveImmediately,
      resolution: config.resolution,
      lastUsedAt: DateTime.now(),
    );
    await prefs.setString(
      _lastStudioPreferencesKey,
      jsonEncode(entry.toMap()),
    );
  }
}
