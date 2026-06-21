import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/prefs_keys.dart';

/// Queues profile edits when offline; flushed when connectivity returns.
class ProfileUpdateQueueService {
  ProfileUpdateQueueService({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _storage async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<bool> hasPending(String userId) async {
    final pending = await readPending(userId);
    return pending != null;
  }

  Future<Map<String, dynamic>?> readPending(String userId) async {
    final prefs = await _storage;
    final raw = prefs.getString(PrefsKeys.pendingProfileUpdate);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['userId'] != userId) return null;
      return map;
    } catch (_) {
      return null;
    }
  }

  Future<void> enqueue({
    required String userId,
    required Map<String, dynamic> userMap,
    String? localPhotoPath,
    bool removePhoto = false,
  }) async {
    final prefs = await _storage;
    await prefs.setString(
      PrefsKeys.pendingProfileUpdate,
      jsonEncode({
        'userId': userId,
        'userMap': userMap,
        'localPhotoPath': localPhotoPath,
        'removePhoto': removePhoto,
        'queuedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<({Map<String, dynamic> userMap, String? localPhotoPath, bool removePhoto})?>
      dequeue(String userId) async {
    final pending = await readPending(userId);
    if (pending == null) return null;
    final prefs = await _storage;
    await prefs.remove(PrefsKeys.pendingProfileUpdate);
    return (
      userMap: Map<String, dynamic>.from(
        pending['userMap'] as Map<String, dynamic>,
      ),
      localPhotoPath: pending['localPhotoPath'] as String?,
      removePhoto: pending['removePhoto'] as bool? ?? false,
    );
  }

  Future<void> clear(String userId) async {
    final pending = await readPending(userId);
    if (pending == null) return;
    final prefs = await _storage;
    await prefs.remove(PrefsKeys.pendingProfileUpdate);
    final path = pending['localPhotoPath'] as String?;
    if (path != null && path.isNotEmpty) {
      try {
        final file = File(path);
        if (file.existsSync()) await file.delete();
      } catch (_) {}
    }
  }
}
