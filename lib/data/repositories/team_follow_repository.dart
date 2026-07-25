import 'package:cloud_firestore/cloud_firestore.dart';

/// Social follow graph + profile views for teams.
class TeamFollowRepository {
  TeamFollowRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _followers =>
      _firestore.collection('teamFollowers');

  CollectionReference<Map<String, dynamic>> _profileViews(String teamId) =>
      _firestore.collection('teams').doc(teamId).collection('profileViews');

  static String docId(String teamId, String userId) => '${teamId}_$userId';

  Stream<bool> watchIsFollowing({
    required String teamId,
    required String userId,
  }) {
    if (teamId.isEmpty || userId.isEmpty) return Stream.value(false);
    return _followers
        .doc(docId(teamId, userId))
        .snapshots()
        .map((s) => s.exists);
  }

  Stream<int> watchFollowersCount(String teamId) {
    if (teamId.isEmpty) return Stream.value(0);
    return _followers
        .where('teamId', isEqualTo: teamId)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> followTeam({
    required String teamId,
    required String userId,
  }) async {
    if (teamId.isEmpty || userId.isEmpty) return;
    await _followers.doc(docId(teamId, userId)).set({
      'teamId': teamId,
      'userId': userId,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> unfollowTeam({
    required String teamId,
    required String userId,
  }) async {
    if (teamId.isEmpty || userId.isEmpty) return;
    await _followers.doc(docId(teamId, userId)).delete();
  }

  /// One view per viewer per 24 hours; skips team owner / self views.
  Future<void> recordProfileView({
    required String teamId,
    required String viewerUserId,
    String? teamOwnerUserId,
  }) async {
    if (teamId.isEmpty || viewerUserId.isEmpty) return;
    if (teamOwnerUserId != null &&
        teamOwnerUserId.isNotEmpty &&
        teamOwnerUserId == viewerUserId) {
      return;
    }

    final viewRef = _profileViews(teamId).doc(viewerUserId);

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

  Future<void> deleteAllForUser(String userId) async {
    if (userId.isEmpty) return;
    while (true) {
      final snap =
          await _followers.where('userId', isEqualTo: userId).limit(100).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
