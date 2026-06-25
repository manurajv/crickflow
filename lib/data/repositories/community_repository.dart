import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../models/community_post_model.dart';
import '../models/location_model.dart';

class CommunityRepository {
  CommunityRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.communityPostsCollection);

  Stream<List<CommunityPostModel>> watchFeed({
    CommunityPostCategory? category,
    String? city,
  }) {
    Query<Map<String, dynamic>> query = _col;

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    } else if (city != null && city.isNotEmpty) {
      query = query.where('location.city', isEqualTo: city);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => CommunityPostModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<String> createPost({
    required String authorId,
    required String authorName,
    required String authorRole,
    required String title,
    required String body,
    required CommunityPostCategory category,
    required LocationModel location,
    String? tournamentId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final doc = await _col.add({
      'authorId': authorId,
      'authorName': authorName,
      if (authorRole.isNotEmpty) 'authorRole': authorRole,
      'category': category.name,
      'title': title.trim(),
      'body': body.trim(),
      'location': location.toMap(),
      if (tournamentId != null && tournamentId.isNotEmpty)
        'tournamentId': tournamentId,
      'createdAt': now,
      'updatedAt': now,
    });
    return doc.id;
  }

  Future<void> deletePostsForTournament(
    String tournamentId, {
    String? authorId,
    String? tournamentName,
  }) async {
    final linked = await _col
        .where('tournamentId', isEqualTo: tournamentId)
        .get();
    for (final doc in linked.docs) {
      await doc.reference.delete();
    }

    if (authorId == null || authorId.isEmpty) return;

    final legacy = await _col
        .where('authorId', isEqualTo: authorId)
        .where('category', isEqualTo: CommunityPostCategory.tournamentNeed.name)
        .get();
    final nameKey = tournamentName?.trim().toLowerCase();
    for (final doc in legacy.docs) {
      if (doc.data()['tournamentId'] != null) continue;
      if (nameKey == null || nameKey.isEmpty) continue;
      final title = (doc.data()['title'] as String? ?? '').toLowerCase();
      final body = (doc.data()['body'] as String? ?? '').toLowerCase();
      if (title.contains(nameKey) || body.contains('tournament: $nameKey')) {
        await doc.reference.delete();
      }
    }
  }

  Future<void> deletePost(String postId) async {
    await _col.doc(postId).delete();
  }
}
