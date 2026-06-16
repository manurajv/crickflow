import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/prefs_keys.dart';
import '../models/user_model.dart';

/// Read-only local cache of the signed-in user's profile (Firestore is source of truth).
class UserProfileCacheService {
  UserProfileCacheService({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _storage async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> cacheProfile(UserModel user) async {
    final prefs = await _storage;
    final payload = <String, dynamic>{
      'uid': user.id,
      'playerId': user.playerId,
      'name': user.name,
      'displayName': user.displayName,
      'photoUrl': user.photoUrl,
      'country': user.country,
      'countryCode': user.countryCode,
      'mobile': user.mobile ?? user.phoneNumber,
      'onboardingCompleted': user.onboardingCompleted,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(PrefsKeys.cachedUserProfile, jsonEncode(payload));
    if (user.playerId != null && user.playerId!.isNotEmpty) {
      await prefs.setString(PrefsKeys.cachedPlayerId, user.playerId!);
      await prefs.setString(PrefsKeys.cachedPlayerIdUid, user.id);
    }
  }

  Future<UserModel?> readCachedProfile(String uid) async {
    final prefs = await _storage;
    final raw = prefs.getString(PrefsKeys.cachedUserProfile);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['uid'] != uid) return null;
      return UserModel.fromMap(uid, map);
    } catch (_) {
      return null;
    }
  }

  Future<String?> readCachedPlayerId(String uid) async {
    final prefs = await _storage;
    final cachedUid = prefs.getString(PrefsKeys.cachedPlayerIdUid);
    if (cachedUid != uid) return null;
    return prefs.getString(PrefsKeys.cachedPlayerId);
  }

  Future<void> clear() async {
    final prefs = await _storage;
    await prefs.remove(PrefsKeys.cachedUserProfile);
    await prefs.remove(PrefsKeys.cachedPlayerId);
    await prefs.remove(PrefsKeys.cachedPlayerIdUid);
  }
}
