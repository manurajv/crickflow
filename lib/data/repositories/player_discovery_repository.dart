import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/cf_player_id_format.dart';
import '../models/user_model.dart';
import 'player_follow_repository.dart';
import 'user_repository.dart';

enum FindCricketersFilter {
  all,
  popular,
  fromContacts,
  followers,
  following,
  teammates,
  nearby,
  recentlyJoined,
  suggested,
  mutualConnections,
}

/// Search and filter players for discovery screens.
class PlayerDiscoveryRepository {
  PlayerDiscoveryRepository({
    FirebaseFirestore? firestore,
    PlayerFollowRepository? followRepository,
    UserRepository? userRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _followRepository = followRepository ?? PlayerFollowRepository(),
        _userRepository = userRepository ?? UserRepository();

  final FirebaseFirestore _firestore;
  final PlayerFollowRepository _followRepository;
  final UserRepository _userRepository;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(AppConstants.usersCollection);

  CollectionReference<Map<String, dynamic>> get _players =>
      _firestore.collection(AppConstants.playersCollection);

  CollectionReference<Map<String, dynamic>> get _teams =>
      _firestore.collection(AppConstants.teamsCollection);

  /// Realtime search by player name or public player ID.
  Future<List<UserModel>> searchPlayers({
    required String query,
    required String? currentUserId,
    FindCricketersFilter filter = FindCricketersFilter.all,
    UserModel? currentUser,
    int limit = 40,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isNotEmpty && CfPlayerIdFormat.looksLikeCfPlayerId(trimmed)) {
      final user = await _lookupByPlayerId(trimmed);
      if (user == null) return [];
      if (user.id == currentUserId) return [];
      return [user];
    }

    // Text queries use prefix name search (users + players collections).
    if (trimmed.isNotEmpty && filter == FindCricketersFilter.all) {
      return _searchByName(
        trimmed,
        currentUserId: currentUserId,
        limit: limit,
      );
    }

    final base = await _fetchByFilter(
      filter: filter,
      currentUserId: currentUserId,
      currentUser: currentUser,
      limit: limit * 2,
    );

    if (trimmed.isEmpty) {
      return base.take(limit).toList();
    }

    final q = trimmed.toLowerCase();
    return base
        .where((user) {
          final name = user.effectiveName.toLowerCase();
          final display = user.displayName.toLowerCase();
          final legal = user.name.toLowerCase();
          final id = (user.playerId ?? '').toLowerCase();
          return name.contains(q) ||
              display.contains(q) ||
              legal.contains(q) ||
              id.contains(q);
        })
        .take(limit)
        .toList();
  }

  Future<List<UserModel>> _searchByName(
    String query, {
    required String? currentUserId,
    required int limit,
  }) async {
    final q = query.toLowerCase();
    final idUpper = CfPlayerIdFormat.normalize(query);
    final results = <UserModel>[];
    final seen = <String>{};

    void add(UserModel u) {
      if (u.id == currentUserId) return;
      if (!seen.add(u.id)) return;
      results.add(u);
    }

    // 1) Players collection — same approach as squad / directory search.
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _players.orderBy('name').limit(500).get();
      } on FirebaseException {
        snap = await _players.limit(500).get();
      }
      for (final d in snap.docs) {
        if (results.length >= limit) break;
        final data = d.data();
        final name = (data['name'] as String? ?? '').toLowerCase();
        final full = (data['fullName'] as String? ?? '').toLowerCase();
        final playerId = (data['playerId'] as String? ?? '').toUpperCase();
        final matchesName =
            name.contains(q) || full.contains(q) || name.split(' ').any((t) => t.startsWith(q));
        final matchesId =
            playerId.isNotEmpty && playerId.contains(idUpper);
        if (!matchesName && !matchesId) continue;

        final uid = (data['userId'] as String?)?.trim();
        final resolveId =
            (uid != null && uid.isNotEmpty) ? uid : d.id;

        UserModel? user;
        try {
          user = await _userRepository.getUser(resolveId);
        } catch (_) {
          user = null;
        }
        add(
          user ??
              UserModel(
                id: resolveId,
                email: '',
                name: (data['fullName'] as String? ?? '').trim().isNotEmpty
                    ? (data['fullName'] as String).trim()
                    : (data['name'] as String? ?? ''),
                displayName: data['name'] as String? ?? '',
                photoUrl: data['photoUrl'] as String?,
                playerId: data['playerId'] as String?,
                onboardingCompleted: true,
              ),
        );
      }
    } on FirebaseException {
      // Fall through to users scan.
    }

    // 2) Users collection — contains match on name fields.
    if (results.length < limit) {
      try {
        QuerySnapshot<Map<String, dynamic>> snap;
        try {
          snap = await _users.orderBy('name').limit(500).get();
        } on FirebaseException {
          snap = await _users.limit(500).get();
        }
        for (final d in snap.docs) {
          if (results.length >= limit) break;
          final u = UserModel.fromMap(d.id, d.data());
          final name = u.effectiveName.toLowerCase();
          final display = u.displayName.toLowerCase();
          final legal = u.name.toLowerCase();
          final playerId = (u.playerId ?? '').toUpperCase();
          final hit = name.contains(q) ||
              display.contains(q) ||
              legal.contains(q) ||
              name.split(RegExp(r'\s+')).any((t) => t.startsWith(q)) ||
              (playerId.isNotEmpty && playerId.contains(idUpper));
          if (!hit) continue;
          add(u);
        }
      } on FirebaseException {
        // Ignore.
      }
    }

    return results.take(limit).toList();
  }

  Future<List<UserModel>> _fetchByFilter({
    required FindCricketersFilter filter,
    required String? currentUserId,
    required UserModel? currentUser,
    required int limit,
  }) async {
    switch (filter) {
      case FindCricketersFilter.all:
        return _recentOnboarded(limit: limit, excludeUserId: currentUserId);
      case FindCricketersFilter.popular:
        return _popular(limit: limit, excludeUserId: currentUserId);
      case FindCricketersFilter.fromContacts:
        return const [];
      case FindCricketersFilter.followers:
        if (currentUserId == null) return [];
        return _followRepository.watchFollowers(userId: currentUserId).first;
      case FindCricketersFilter.following:
        if (currentUserId == null) return [];
        return _followRepository.watchFollowing(userId: currentUserId).first;
      case FindCricketersFilter.teammates:
        if (currentUserId == null) return [];
        return _teammates(currentUserId, limit: limit);
      case FindCricketersFilter.nearby:
        if (currentUser == null) return [];
        return _nearby(currentUser, limit: limit, excludeUserId: currentUserId);
      case FindCricketersFilter.recentlyJoined:
        return _recentOnboarded(limit: limit, excludeUserId: currentUserId);
      case FindCricketersFilter.suggested:
        if (currentUserId == null) return [];
        return _suggested(currentUserId, limit: limit);
      case FindCricketersFilter.mutualConnections:
        return const [];
    }
  }

  Future<UserModel?> _lookupByPlayerId(String playerId) async {
    final normalized = CfPlayerIdFormat.normalize(playerId);
    final snap = await _users
        .where('playerId', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return UserModel.fromMap(doc.id, doc.data());
  }

  Future<List<UserModel>> _recentOnboarded({
    required int limit,
    String? excludeUserId,
  }) async {
    final snap = await _users
        .where('onboardingCompleted', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return _mapUsers(snap, excludeUserId: excludeUserId);
  }

  Future<List<UserModel>> _popular({
    required int limit,
    String? excludeUserId,
  }) async {
    try {
      final snap = await _users
          .where('onboardingCompleted', isEqualTo: true)
          .orderBy('socialStats.followersCount', descending: true)
          .limit(limit)
          .get();
      return _mapUsers(snap, excludeUserId: excludeUserId);
    } on FirebaseException {
      final snap = await _users
          .where('onboardingCompleted', isEqualTo: true)
          .limit(limit * 3)
          .get();
      final users = _mapUsers(snap, excludeUserId: excludeUserId);
      users.sort(
        (a, b) => b.socialStats.followersCount
            .compareTo(a.socialStats.followersCount),
      );
      return users.take(limit).toList();
    }
  }

  Future<List<UserModel>> _nearby(
    UserModel currentUser, {
    required int limit,
    String? excludeUserId,
  }) async {
    final snap = await _users
        .where('onboardingCompleted', isEqualTo: true)
        .limit(limit * 4)
        .get();
    final users = _mapUsers(snap, excludeUserId: excludeUserId);
    final city = currentUser.location.city.toLowerCase();
    final state = currentUser.location.stateProvince.toLowerCase();
    final country = (currentUser.country.isNotEmpty
            ? currentUser.country
            : currentUser.location.country)
        .toLowerCase();

    int score(UserModel user) {
      var s = 0;
      if (city.isNotEmpty &&
          user.location.city.toLowerCase() == city) {
        s += 3;
      }
      if (state.isNotEmpty &&
          user.location.stateProvince.toLowerCase() == state) {
        s += 2;
      }
      final userCountry = (user.country.isNotEmpty
              ? user.country
              : user.location.country)
          .toLowerCase();
      if (country.isNotEmpty && userCountry == country) s += 1;
      return s;
    }

    users.sort((a, b) {
      final diff = score(b).compareTo(score(a));
      if (diff != 0) return diff;
      return b.socialStats.followersCount
          .compareTo(a.socialStats.followersCount);
    });

    return users.where((u) => score(u) > 0).take(limit).toList();
  }

  Future<List<UserModel>> _teammates(String userId, {required int limit}) async {
    final playerSnap = await _players.doc(userId).get();
    if (!playerSnap.exists) return [];

    final teamIds = List<String>.from(playerSnap.data()?['teamIds'] as List? ?? []);
    final legacy = playerSnap.data()?['teamId'] as String?;
    if (legacy != null && legacy.isNotEmpty) teamIds.add(legacy);
    if (teamIds.isEmpty) return [];

    final teammateIds = <String>{};
    for (final teamId in teamIds.take(10)) {
      final teamDoc = await _teams.doc(teamId).get();
      if (!teamDoc.exists) continue;
      final roster = List<String>.from(teamDoc.data()?['playerIds'] as List? ?? []);
      teammateIds.addAll(roster);
    }
    teammateIds.remove(userId);

    if (teammateIds.isEmpty) return [];

    final users = <UserModel>[];
    final ids = teammateIds.toList();
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();
      final playerDocs = await _players
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      final authIds = playerDocs.docs
          .map((d) => d.data()['userId'] as String? ?? d.id)
          .where((id) => id.isNotEmpty && id != userId)
          .toList();
      if (authIds.isEmpty) continue;
      for (var j = 0; j < authIds.length; j += 10) {
        final userChunk = authIds.skip(j).take(10).toList();
        final userSnap = await _users
            .where(FieldPath.documentId, whereIn: userChunk)
            .get();
        users.addAll(
          userSnap.docs.map((d) => UserModel.fromMap(d.id, d.data())),
        );
      }
    }

    users.sort((a, b) => a.effectiveName.compareTo(b.effectiveName));
    return users.take(limit).toList();
  }

  Future<List<UserModel>> _suggested(String userId, {required int limit}) async {
    final following = await _followRepository.fetchFollowingUserIds(userId);
    final popular = await _popular(limit: limit * 2, excludeUserId: userId);
    return popular
        .where((user) => !following.contains(user.id))
        .take(limit)
        .toList();
  }

  List<UserModel> _mapUsers(
    QuerySnapshot<Map<String, dynamic>> snap, {
    String? excludeUserId,
  }) {
    return snap.docs
        .map((d) => UserModel.fromMap(d.id, d.data()))
        .where((u) =>
            u.onboardingCompleted &&
            u.playerId != null &&
            u.playerId!.isNotEmpty &&
            u.id != excludeUserId)
        .toList();
  }
}
