import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../models/community_comment_model.dart';
import '../models/community_post_model.dart';
import '../models/location_model.dart';
import 'notification_repository.dart';

class CommunityRepository {
  CommunityRepository({
    FirebaseFirestore? firestore,
    NotificationRepository? notificationRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _notifications = notificationRepository;

  final FirebaseFirestore _firestore;
  final NotificationRepository? _notifications;

  static const int pageSize = 20;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.communityPostsCollection);

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection(AppConstants.communityPostReportsCollection);

  /// Live first page (newest). Optional category server filter.
  Stream<List<CommunityPostModel>> watchFeedHead({
    CommunityPostCategory? category,
    int limit = pageSize,
  }) {
    Query<Map<String, dynamic>> query = _col;
    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => CommunityPostModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<List<CommunityPostModel>> fetchPage({
    CommunityPostCategory? category,
    String? startAfterCreatedAt,
    int limit = pageSize,
  }) async {
    Query<Map<String, dynamic>> query = _col;
    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }
    query = query.orderBy('createdAt', descending: true).limit(limit);
    if (startAfterCreatedAt != null && startAfterCreatedAt.isNotEmpty) {
      query = query.startAfter([startAfterCreatedAt]);
    }
    final snap = await query.get();
    return snap.docs
        .map((d) => CommunityPostModel.fromMap(d.id, d.data()))
        .toList();
  }

  Future<CommunityPostModel?> getPost(String postId) async {
    final doc = await _col.doc(postId).get();
    if (!doc.exists || doc.data() == null) return null;
    return CommunityPostModel.fromMap(doc.id, doc.data()!);
  }

  Stream<CommunityPostModel?> watchPost(String postId) {
    return _col.doc(postId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return CommunityPostModel.fromMap(doc.id, doc.data()!);
    });
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
    String? matchId,
    String? teamId,
    String? authorPhotoUrl,
    String? authorPlayerId,
    bool authorVerified = false,
    CommunityPostKind postKind = CommunityPostKind.general,
    List<CommunityMediaItem> media = const [],
    CommunityTournamentSnapshot? tournamentSnapshot,
    bool isPinned = false,
    bool isSponsored = false,
    bool isAdminPost = false,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final doc = await _col.add({
      'authorId': authorId,
      'authorName': authorName,
      if (authorRole.isNotEmpty) 'authorRole': authorRole,
      if (authorPhotoUrl != null) 'authorPhotoUrl': authorPhotoUrl,
      if (authorPlayerId != null) 'authorPlayerId': authorPlayerId,
      'authorVerified': authorVerified,
      'category': category.name,
      'postKind': postKind.name,
      'title': title.trim(),
      'body': body.trim(),
      'location': location.toMap(),
      if (tournamentId != null && tournamentId.isNotEmpty)
        'tournamentId': tournamentId,
      if (matchId != null && matchId.isNotEmpty) 'matchId': matchId,
      if (teamId != null && teamId.isNotEmpty) 'teamId': teamId,
      if (media.isNotEmpty) 'media': media.map((m) => m.toMap()).toList(),
      if (tournamentSnapshot != null)
        'tournamentSnapshot': tournamentSnapshot.toMap(),
      'likeCount': 0,
      'commentCount': 0,
      'shareCount': 0,
      'saveCount': 0,
      'isPinned': isPinned,
      'isSponsored': isSponsored,
      'isAdminPost': isAdminPost,
      'createdAt': now,
      'updatedAt': now,
    });
    return doc.id;
  }

  Future<void> updatePost({
    required String postId,
    required String title,
    required String body,
    required CommunityPostCategory category,
    required CommunityPostKind postKind,
    required LocationModel location,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _col.doc(postId).update({
      'title': title.trim(),
      'body': body.trim(),
      'category': category.name,
      'postKind': postKind.name,
      'location': location.toMap(),
      'updatedAt': now,
      'editedAt': now,
    });
  }

  Future<List<CommunityPostModel>> searchPosts(String query, {int limit = 40}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final snap = await _col.orderBy('createdAt', descending: true).limit(120).get();
    final tagQuery = q.startsWith('#') ? q : '#$q';
    final hits = <CommunityPostModel>[];
    for (final doc in snap.docs) {
      final post = CommunityPostModel.fromMap(doc.id, doc.data());
      final title = post.title.toLowerCase();
      final body = post.body.toLowerCase();
      final author = post.authorName.toLowerCase();
      final hay = '$title $body $author';
      if (hay.contains(q) ||
          body.contains(tagQuery) ||
          title.contains(tagQuery) ||
          (q.startsWith('#') && hay.contains(q))) {
        hits.add(post);
      }
      if (hits.length >= limit) break;
    }
    return hits;
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
    final likes = await _col.doc(postId).collection('likes').limit(200).get();
    for (final d in likes.docs) {
      await d.reference.delete();
    }
    final comments =
        await _col.doc(postId).collection('comments').limit(200).get();
    for (final d in comments.docs) {
      await d.reference.delete();
    }
    final saves = await _col.doc(postId).collection('saves').limit(200).get();
    for (final d in saves.docs) {
      await d.reference.delete();
    }
    await _col.doc(postId).delete();
  }

  // ── Likes ──────────────────────────────────────────────────────────────

  Stream<bool> watchLiked({required String postId, required String userId}) {
    return _col
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((d) => d.exists);
  }

  Future<void> toggleLike({
    required String postId,
    required String userId,
    String? actorName,
  }) async {
    final likeRef = _col.doc(postId).collection('likes').doc(userId);
    final postRef = _col.doc(postId);
    var liked = false;
    String? authorId;
    String? title;
    await _firestore.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      final postSnap = await tx.get(postRef);
      authorId = postSnap.data()?['authorId'] as String?;
      title = postSnap.data()?['title'] as String?;
      if (likeSnap.exists) {
        tx.delete(likeRef);
        tx.update(postRef, {
          'likeCount': FieldValue.increment(-1),
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        liked = true;
        tx.set(likeRef, {
          'userId': userId,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        });
        tx.update(postRef, {
          'likeCount': FieldValue.increment(1),
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });
      }
    });
    if (liked &&
        authorId != null &&
        authorId!.isNotEmpty &&
        authorId != userId) {
      final notifications = _notifications;
      if (notifications != null) {
        final who = (actorName != null && actorName.isNotEmpty)
            ? actorName
            : 'Someone';
        await notifications.createNotification(
          userId: authorId!,
          title: 'New like',
          body:
              '$who liked your post${title != null && title!.isNotEmpty ? ': $title' : ''}',
          type: 'community_like',
          category: 'community',
          addedByUserId: userId,
          requestId: postId,
        );
      }
    } else if (!liked &&
        authorId != null &&
        authorId!.isNotEmpty &&
        authorId != userId) {
      // Unlike — remove the like notification from the author's inbox.
      await _notifications?.deleteCommunityEngagementNotifications(
        type: 'community_like',
        requestId: postId,
        addedByUserId: userId,
      );
    }
  }

  // ── Saves ──────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _userSavedPosts(String userId) =>
      _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection('saved_community_posts');

  Stream<bool> watchSaved({required String postId, required String userId}) {
    return _col
        .doc(postId)
        .collection('saves')
        .doc(userId)
        .snapshots()
        .map((d) => d.exists);
  }

  /// Post IDs the user has saved — user subcollection (realtime, rules-safe).
  Stream<List<String>> watchSavedPostIds(String userId) {
    if (userId.isEmpty) return Stream.value(const []);
    return _userSavedPosts(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList())
        .transform(
          StreamTransformer<List<String>, List<String>>.fromHandlers(
            handleData: (data, sink) => sink.add(data),
            handleError: (Object _, StackTrace __, EventSink<List<String>> sink) {
              sink.add(const []);
            },
          ),
        );
  }

  Future<List<CommunityPostModel>> fetchPostsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final posts = <CommunityPostModel>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snaps = await Future.wait(chunk.map((id) => _col.doc(id).get()));
      for (final snap in snaps) {
        if (!snap.exists || snap.data() == null) continue;
        posts.add(CommunityPostModel.fromMap(snap.id, snap.data()!));
      }
    }
    // Preserve saved order when ids are already newest-first.
    final byId = {for (final p in posts) p.id: p};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<void> toggleSave({
    required String postId,
    required String userId,
  }) async {
    final saveRef = _col.doc(postId).collection('saves').doc(userId);
    final postRef = _col.doc(postId);
    final userSaveRef = _userSavedPosts(userId).doc(postId);
    final now = DateTime.now().toUtc().toIso8601String();

    var nowSaved = false;
    await _firestore.runTransaction((tx) async {
      final saveSnap = await tx.get(saveRef);
      if (saveSnap.exists) {
        tx.delete(saveRef);
        tx.update(postRef, {
          'saveCount': FieldValue.increment(-1),
          'updatedAt': now,
        });
        nowSaved = false;
      } else {
        tx.set(saveRef, {
          'userId': userId,
          'createdAt': now,
        });
        tx.update(postRef, {
          'saveCount': FieldValue.increment(1),
          'updatedAt': now,
        });
        nowSaved = true;
      }
    });

    // Keep Saved-filter index in sync outside the post transaction so a
    // missing/denied user-index rule cannot block bookmarking.
    try {
      if (nowSaved) {
        await userSaveRef.set({
          'userId': userId,
          'postId': postId,
          'createdAt': now,
        });
      } else {
        await userSaveRef.delete();
      }
    } catch (_) {}
  }

  // ── Comments ───────────────────────────────────────────────────────────

  Stream<List<CommunityCommentModel>> watchComments(String postId) {
    return _col
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .limit(200)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => CommunityCommentModel.fromMap(
                  d.id,
                  d.data(),
                  postId: postId,
                ),
              )
              .toList(),
        );
  }

  Future<String> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    required String text,
    String? authorPhotoUrl,
    String? parentId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final ref = _col.doc(postId).collection('comments').doc();
    String? postAuthorId;
    String? title;
    await _firestore.runTransaction((tx) async {
      final postSnap = await tx.get(_col.doc(postId));
      postAuthorId = postSnap.data()?['authorId'] as String?;
      title = postSnap.data()?['title'] as String?;
      tx.set(ref, {
        'authorId': authorId,
        'authorName': authorName,
        if (authorPhotoUrl != null) 'authorPhotoUrl': authorPhotoUrl,
        'text': text.trim(),
        if (parentId != null) 'parentId': parentId,
        'likeCount': 0,
        'createdAt': now,
      });
      tx.update(_col.doc(postId), {
        'commentCount': FieldValue.increment(1),
        'updatedAt': now,
      });
    });
    if (postAuthorId != null &&
        postAuthorId!.isNotEmpty &&
        postAuthorId != authorId) {
      final notifications = _notifications;
      if (notifications != null) {
        final preview = text.trim();
        final short =
            preview.length > 80 ? '${preview.substring(0, 80)}…' : preview;
        await notifications.createNotification(
          userId: postAuthorId!,
          title: 'New comment',
          body:
              '$authorName commented${title != null && title!.isNotEmpty ? ' on $title' : ''}: $short',
          type: 'community_comment',
          category: 'community',
          addedByUserId: authorId,
          requestId: postId,
          // Reuse reportId to store commentId for revocation on delete.
          reportId: ref.id,
        );
      }
    }
    return ref.id;
  }

  Future<void> deleteComment({
    required String postId,
    required String commentId,
    String? authorId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    String? resolvedAuthorId = authorId;
    await _firestore.runTransaction((tx) async {
      final commentRef =
          _col.doc(postId).collection('comments').doc(commentId);
      if (resolvedAuthorId == null || resolvedAuthorId!.isEmpty) {
        final snap = await tx.get(commentRef);
        resolvedAuthorId = snap.data()?['authorId'] as String?;
      }
      tx.delete(commentRef);
      tx.update(_col.doc(postId), {
        'commentCount': FieldValue.increment(-1),
        'updatedAt': now,
      });
    });
    if (resolvedAuthorId != null && resolvedAuthorId!.isNotEmpty) {
      await _notifications?.deleteCommunityEngagementNotifications(
        type: 'community_comment',
        requestId: postId,
        addedByUserId: resolvedAuthorId!,
        reportId: commentId,
      );
    }
  }

  Future<void> updateComment({
    required String postId,
    required String commentId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Comment cannot be empty');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await _col.doc(postId).collection('comments').doc(commentId).update({
      'text': trimmed,
      'editedAt': now,
    });
  }

  Future<void> toggleCommentLike({
    required String postId,
    required String commentId,
    required String userId,
  }) async {
    final likeRef = _col
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('likes')
        .doc(userId);
    final commentRef =
        _col.doc(postId).collection('comments').doc(commentId);
    await _firestore.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      if (likeSnap.exists) {
        tx.delete(likeRef);
        tx.update(commentRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {
          'userId': userId,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        });
        tx.update(commentRef, {'likeCount': FieldValue.increment(1)});
      }
    });
  }

  Future<void> incrementShareCount(String postId) async {
    await _col.doc(postId).update({
      'shareCount': FieldValue.increment(1),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> reportPost({
    required String postId,
    required String reporterUserId,
    required String reason,
    String? authorId,
    String? commentId,
  }) async {
    await _reports.add({
      'postId': postId,
      if (authorId != null) 'authorId': authorId,
      if (commentId != null) 'commentId': commentId,
      'reporterUserId': reporterUserId,
      'reason': reason.trim(),
      'status': 'pending',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> reportUser({
    required String reportedUserId,
    required String reporterUserId,
    required String reason,
  }) async {
    await _reports.add({
      'postId': '',
      'authorId': reportedUserId,
      'reporterUserId': reporterUserId,
      'reason': reason.trim(),
      'status': 'pending',
      'type': 'user',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Stream<bool> watchCommentLiked({
    required String postId,
    required String commentId,
    required String userId,
  }) {
    return _col
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((d) => d.exists);
  }
}
