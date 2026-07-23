import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/cf_player_id_format.dart';
import '../models/user_model.dart';
import '../services/user_profile_cache_service.dart';

class UserRepository {
  UserRepository({
    FirebaseFirestore? firestore,
    UserProfileCacheService? profileCache,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _profileCache = profileCache ?? UserProfileCacheService();

  final FirebaseFirestore _firestore;
  final UserProfileCacheService _profileCache;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.usersCollection);

  DocumentReference<Map<String, dynamic>> get _playerIdCounter =>
      _firestore.collection('app_meta').doc('cf_player_ids');

  Future<UserModel?> getUser(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists) {
        return _profileCache.readCachedProfile(id);
      }
      final user = UserModel.fromMap(doc.id, doc.data()!);
      await _syncLocalCache(user);
      return user;
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'permission-denied') {
        try {
          final cached = await _col
              .doc(id)
              .get(const GetOptions(source: Source.cache));
          if (cached.exists) {
            final user = UserModel.fromMap(cached.id, cached.data()!);
            await _syncLocalCache(user);
            return user;
          }
        } catch (_) {
          // Fall through to SharedPreferences cache.
        }
        return _readOfflineProfile(id);
      }
      rethrow;
    }
  }

  Future<UserModel?> _readOfflineProfile(String id) async {
    final cached = await _profileCache.readCachedProfile(id);
    if (cached != null) return cached;
    final playerId = await _profileCache.readCachedPlayerId(id);
    if (playerId == null) return null;
    return UserModel(id: id, email: '', playerId: playerId);
  }

  Future<void> _syncLocalCache(UserModel user) async {
    final cachedId = await _profileCache.readCachedPlayerId(user.id);
    if (user.playerId != null &&
        user.playerId!.isNotEmpty &&
        cachedId != user.playerId) {
      await _profileCache.cacheProfile(user);
      return;
    }
    if (cachedId == null && user.onboardingCompleted) {
      await _profileCache.cacheProfile(user);
    }
  }

  Future<void> createUser(UserModel user) async {
    await _col.doc(user.id).set(user.toMap());
    await _profileCache.cacheProfile(user);
  }

  Future<void> upsertUser(UserModel user) async {
    await _col.doc(user.id).set(user.toMap(), SetOptions(merge: true));
    await _profileCache.cacheProfile(user);
  }

  Future<void> updateUser(UserModel user) async {
    await _col.doc(user.id).update(user.toMap());
    await _profileCache.cacheProfile(user);
  }

  Future<void> deleteUser(String id) async {
    await _col.doc(id).delete();
    await _profileCache.clear();
  }

  Stream<UserModel?> watchUser(String id) {
    return _col.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      final user = UserModel.fromMap(doc.id, doc.data()!);
      _profileCache.cacheProfile(user);
      return user;
    });
  }

  /// Allocates the next CF-prefixed public player ID (transaction-safe).
  Future<String?> allocatePlayerId() async {
    try {
      return await _firestore.runTransaction((tx) async {
        final snap = await tx.get(_playerIdCounter);
        final last = snap.data()?['lastNumber'] as int? ?? 0;
        final next = last + 1;
        tx.set(
          _playerIdCounter,
          {
            'lastNumber': next,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          SetOptions(merge: true),
        );
        return CfPlayerIdFormat.format(next);
      });
    } on FirebaseException catch (e) {
      debugPrint('allocatePlayerId skipped: ${e.code}');
      return null;
    } catch (e) {
      debugPrint('allocatePlayerId skipped: $e');
      return null;
    }
  }

  /// @deprecated Use [allocatePlayerId].
  Future<String?> allocateCfPlayerId() => allocatePlayerId();

  /// Completes onboarding: allocates [playerId] once, saves profile, caches locally.
  Future<UserModel> completeOnboarding(UserModel user) async {
    var profile = user;
    if (profile.playerId == null || profile.playerId!.isEmpty) {
      final id = await allocatePlayerId();
      if (id == null) {
        throw Exception(
          'Could not generate Player ID. Check your connection and try again.',
        );
      }
      profile = profile.copyWith(playerId: id);
    }
    profile = profile.copyWith(onboardingCompleted: true);
    await upsertUser(profile);
    return profile;
  }

  /// Ensures an existing user has a public player ID (lazy backfill for legacy accounts).
  Future<UserModel> ensurePlayerId(UserModel user) async {
    if (user.playerId != null && user.playerId!.isNotEmpty) return user;
    final id = await allocatePlayerId();
    if (id == null) return user;
    try {
      await _col.doc(user.id).set(
        {'playerId': id, 'updatedAt': DateTime.now().toIso8601String()},
        SetOptions(merge: true),
      );
      final updated = user.copyWith(playerId: id);
      await _profileCache.cacheProfile(updated);
      return updated;
    } on FirebaseException catch (e) {
      debugPrint('ensurePlayerId write skipped: ${e.code}');
      return user;
    }
  }

  /// @deprecated Use [ensurePlayerId].
  Future<UserModel> ensureCfPlayerId(UserModel user) => ensurePlayerId(user);

  /// Lookup by public player ID (e.g. CF000001).
  Future<UserModel?> getUserByPlayerId(String playerId) async {
    final normalized = CfPlayerIdFormat.normalize(playerId);
    final snap = await _col.where('playerId', isEqualTo: normalized).limit(1).get();
    if (snap.docs.isEmpty) {
      final legacy = await _col.where('cfPlayerId', isEqualTo: normalized).limit(1).get();
      if (legacy.docs.isEmpty) return null;
      return UserModel.fromMap(legacy.docs.first.id, legacy.docs.first.data());
    }
    return UserModel.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  Stream<UserModel?> watchUserByPlayerId(String playerId) {
    final normalized = CfPlayerIdFormat.normalize(playerId);
    return _col
        .where('playerId', isEqualTo: normalized)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final user = UserModel.fromMap(snap.docs.first.id, snap.docs.first.data());
      _profileCache.cacheProfile(user);
      return user;
    });
  }

  /// Search by player ID, email, or mobile number.
  Future<List<UserModel>> searchScorers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final results = <UserModel>[];
    final seen = <String>{};

    Future<void> addFrom(Query<Map<String, dynamic>> q) async {
      final snap = await q.limit(5).get();
      for (final doc in snap.docs) {
        if (seen.add(doc.id)) {
          results.add(UserModel.fromMap(doc.id, doc.data()));
        }
      }
    }

    if (CfPlayerIdFormat.looksLikeCfPlayerId(trimmed)) {
      final id = CfPlayerIdFormat.normalize(trimmed);
      await addFrom(_col.where('playerId', isEqualTo: id));
      if (results.isEmpty) {
        await addFrom(_col.where('cfPlayerId', isEqualTo: id));
      }
      return results;
    }

    if (trimmed.contains('@')) {
      await addFrom(_col.where('email', isEqualTo: trimmed.toLowerCase()));
      if (results.isEmpty) {
        await addFrom(_col.where('email', isEqualTo: trimmed));
      }
      return results;
    }

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isNotEmpty) {
      await addFrom(_col.where('mobile', isEqualTo: digits));
      if (results.isEmpty) {
        await addFrom(_col.where('phoneNumber', isEqualTo: digits));
      }
      if (results.isEmpty && digits != trimmed) {
        await addFrom(_col.where('mobile', isEqualTo: trimmed));
        await addFrom(_col.where('phoneNumber', isEqualTo: trimmed));
      }
    }

    return results;
  }

  /// Search users by display/legal name or public player ID (e.g. CF000042).
  Future<List<UserModel>> searchUsersByName(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final results = <UserModel>[];
    final seen = <String>{};

    void add(UserModel u) {
      if (seen.add(u.id)) results.add(u);
    }

    // Exact player-ID hit first (CF000042, cf000042, …).
    if (CfPlayerIdFormat.looksLikeCfPlayerId(trimmed)) {
      final byId = await getUserByPlayerId(trimmed);
      if (byId != null) add(byId);
    }

    final q = trimmed.toLowerCase();
    final prefixes = _namePrefixVariants(trimmed);

    // Prefix range queries — works beyond the first N alphabetically ordered docs.
    for (final field in ['displayName', 'name']) {
      for (final prefix in prefixes) {
        try {
          final snap = await _col
              .orderBy(field)
              .startAt([prefix])
              .endAt(['$prefix\uf8ff'])
              .limit(40)
              .get();
          for (final d in snap.docs) {
            add(UserModel.fromMap(d.id, d.data()));
          }
        } on FirebaseException {
          // Field/index issues — continue with other strategies.
        }
      }
    }

    // Players collection often holds the scorecard name used in search.
    try {
      final playerHits = await _searchPlayerDocsByName(trimmed, limit: 40);
      for (final uid in playerHits) {
        final user = await getUser(uid);
        if (user != null) add(user);
      }
    } on FirebaseException {
      // Ignore — users query above may still have hits.
    }

    // Supplemental contains scan for mid-name matches (e.g. last name).
    if (results.length < 40) {
      try {
        final recent = await _col
            .where('onboardingCompleted', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(250)
            .get();
        for (final d in recent.docs) {
          add(UserModel.fromMap(d.id, d.data()));
        }
      } on FirebaseException {
        try {
          final snap = await _col.limit(250).get();
          for (final d in snap.docs) {
            add(UserModel.fromMap(d.id, d.data()));
          }
        } on FirebaseException {
          // Give up supplemental scan.
        }
      }
    }

    // Keep only rows that actually match.
    final idUpper = CfPlayerIdFormat.normalize(trimmed);
    return results.where((u) {
      final name = u.effectiveName.toLowerCase();
      final display = u.displayName.toLowerCase();
      final legal = u.name.toLowerCase();
      final playerId = (u.playerId ?? '').toUpperCase();
      return name.contains(q) ||
          display.contains(q) ||
          legal.contains(q) ||
          (playerId.isNotEmpty && playerId.contains(idUpper));
    }).toList();
  }

  /// Case variants for Firestore string prefix ranges (case-sensitive).
  Set<String> _namePrefixVariants(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return const {};
    final lower = t.toLowerCase();
    final upper = t.toUpperCase();
    final title = lower.isEmpty
        ? t
        : '${lower[0].toUpperCase()}${lower.substring(1)}';
    final words = lower
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
    return {t, lower, upper, title, if (words.isNotEmpty) words};
  }

  Future<List<String>> _searchPlayerDocsByName(
    String query, {
    required int limit,
  }) async {
    final players = _firestore.collection(AppConstants.playersCollection);
    final prefixes = _namePrefixVariants(query);
    final uids = <String>{};
    final q = query.toLowerCase();

    for (final field in ['name', 'fullName']) {
      for (final prefix in prefixes) {
        try {
          final snap = await players
              .orderBy(field)
              .startAt([prefix])
              .endAt(['$prefix\uf8ff'])
              .limit(limit)
              .get();
          for (final d in snap.docs) {
            final data = d.data();
            final name = (data['name'] as String? ?? '').toLowerCase();
            final full = (data['fullName'] as String? ?? '').toLowerCase();
            if (!name.contains(q) && !full.contains(q)) continue;
            final uid = data['userId'] as String? ?? '';
            if (uid.isNotEmpty) uids.add(uid);
          }
        } on FirebaseException {
          // Continue.
        }
      }
    }
    return uids.take(limit).toList();
  }

  /// @deprecated Use [searchScorers].
  Future<List<UserModel>> searchByEmailOrPhone(String query) =>
      searchScorers(query);

  Future<void> clearLocalCache() => _profileCache.clear();
}
