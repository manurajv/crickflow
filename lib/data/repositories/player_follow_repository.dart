import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/player_social_stats_model.dart';
import '../models/user_model.dart';
import 'notification_repository.dart';

/// Player-to-player follow graph and profile view tracking.
class PlayerFollowRepository {
  PlayerFollowRepository({
    FirebaseFirestore? firestore,
    NotificationRepository? notificationRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _notifications = notificationRepository;

  final FirebaseFirestore _firestore;
  final NotificationRepository? _notifications;

  CollectionReference<Map<String, dynamic>> get _follows =>
      _firestore.collection('playerFollows');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(AppConstants.usersCollection);

  DocumentReference<Map<String, dynamic>> _socialStats(String userId) =>
      _users.doc(userId).collection('social').doc('stats');

  CollectionReference<Map<String, dynamic>> _profileViews(String userId) =>
      _users.doc(userId).collection('profileViews');

  static String followDocId(String followerUserId, String followedUserId) =>
      '${followerUserId}_$followedUserId';

  Stream<bool> watchIsFollowing({
    required String followerUserId,
    required String followedUserId,
  }) {
    if (followerUserId.isEmpty || followedUserId.isEmpty) {
      return Stream.value(false);
    }
    return _follows
        .doc(followDocId(followerUserId, followedUserId))
        .snapshots()
        .map((snap) => snap.exists);
  }

  Stream<PlayerSocialStatsModel> watchSocialStats(String userId) {
    if (userId.isEmpty) {
      return Stream.value(const PlayerSocialStatsModel());
    }
    return _socialStats(userId).snapshots().map((doc) {
      if (!doc.exists) return const PlayerSocialStatsModel();
      return PlayerSocialStatsModel.fromMap(doc.data());
    });
  }

  Future<void> followPlayer({
    required String followerUserId,
    required String followedUserId,
    required String followerPlayerId,
    required String followedPlayerId,
    required String followerName,
  }) async {
    if (followerUserId.isEmpty ||
        followedUserId.isEmpty ||
        followerUserId == followedUserId) {
      return;
    }

    final followRef = _follows.doc(followDocId(followerUserId, followedUserId));
    var created = false;

    await _firestore.runTransaction((tx) async {
      final existing = await tx.get(followRef);
      if (existing.exists) return;

      tx.set(followRef, {
        'followerUserId': followerUserId,
        'followedUserId': followedUserId,
        'followerPlayerId': followerPlayerId,
        'followedPlayerId': followedPlayerId,
        'followerName': followerName,
        'createdAt': DateTime.now().toIso8601String(),
      });
      created = true;
    });

    if (!created) return;

    final followedStatsSnap =
        await _socialStats(followedUserId).get(const GetOptions(source: Source.server));
    final followersCount =
        PlayerSocialStatsModel.fromMap(followedStatsSnap.data()).followersCount + 1;

    await _notifications?.createNotification(
      userId: followedUserId,
      title: 'New Follower',
      body: '$followerName started following you.',
      playerId: followedPlayerId,
      type: 'player_follow',
      category: 'social',
      addedByUserId: followerUserId,
    );

    for (final milestone in const [100, 1000]) {
      if (followersCount == milestone) {
        await _notifications?.createNotification(
          userId: followedUserId,
          title: 'Follower Milestone',
          body: 'You reached $milestone followers.',
          playerId: followedPlayerId,
          type: 'follower_milestone',
          category: 'social',
        );
      }
    }
  }

  Future<void> unfollowPlayer({
    required String followerUserId,
    required String followedUserId,
  }) async {
    if (followerUserId.isEmpty ||
        followedUserId.isEmpty ||
        followerUserId == followedUserId) {
      return;
    }

    final followRef = _follows.doc(followDocId(followerUserId, followedUserId));

    await _firestore.runTransaction((tx) async {
      final existing = await tx.get(followRef);
      if (!existing.exists) return;

      tx.delete(followRef);
    });
  }

  /// Removes follows where this user is the follower (account deletion).
  Future<void> deleteAllFollowsByUser(String followerUserId) async {
    if (followerUserId.isEmpty) return;
    while (true) {
      final snap = await _follows
          .where('followerUserId', isEqualTo: followerUserId)
          .limit(100)
          .get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// One view per viewer per 24 hours; skips self views.
  Future<void> recordProfileView({
    required String profileUserId,
    required String viewerUserId,
  }) async {
    if (profileUserId.isEmpty ||
        viewerUserId.isEmpty ||
        profileUserId == viewerUserId) {
      return;
    }

    final viewRef = _profileViews(profileUserId).doc(viewerUserId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(viewRef);
      final now = DateTime.now();
      if (snap.exists) {
        final last = snap.data()?['lastViewedAt'];
        if (last is Timestamp) {
          if (now.difference(last.toDate()).inHours < 24) return;
        }
      }

      tx.set(viewRef, {'lastViewedAt': FieldValue.serverTimestamp()});
    });
  }

  Stream<List<UserModel>> watchFollowers({
    required String userId,
    int limit = 30,
  }) {
    return _follows
        .where('followedUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snap) async {
      final ids = snap.docs
          .map((d) => d.data()['followerUserId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      return _usersByIds(ids);
    });
  }

  Stream<List<UserModel>> watchFollowing({
    required String userId,
    int limit = 30,
  }) {
    return _follows
        .where('followerUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snap) async {
      final ids = snap.docs
          .map((d) => d.data()['followedUserId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      return _usersByIds(ids);
    });
  }

  Future<List<UserModel>> fetchFollowersPage({
    required String userId,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    var query = _follows
        .where('followedUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snap = await query.get();
    final ids = snap.docs
        .map((d) => d.data()['followerUserId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    return _usersByIds(ids);
  }

  Future<List<UserModel>> fetchFollowingPage({
    required String userId,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    var query = _follows
        .where('followerUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snap = await query.get();
    final ids = snap.docs
        .map((d) => d.data()['followedUserId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    return _usersByIds(ids);
  }

  Future<Set<String>> fetchFollowingUserIds(String userId) async {
    if (userId.isEmpty) return {};
    final snap = await _follows
        .where('followerUserId', isEqualTo: userId)
        .limit(500)
        .get();
    return snap.docs
        .map((d) => d.data()['followedUserId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<List<UserModel>> _usersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <UserModel>[];
    final order = {for (var i = 0; i < ids.length; i++) ids[i]: i};
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();
      final snap = await _users
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results.addAll(
        snap.docs.map((d) => UserModel.fromMap(d.id, d.data())),
      );
    }
    results.sort(
      (a, b) => (order[a.id] ?? 0).compareTo(order[b.id] ?? 0),
    );
    return results;
  }
}
