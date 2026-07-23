import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../features/discover/domain/opportunity_category.dart';
import '../models/location_model.dart';
import '../models/opportunity_post_model.dart';

class OpportunityRepository {
  OpportunityRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int pageSize = 20;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.opportunityPostsCollection);

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection(AppConstants.opportunityPostReportsCollection);

  CollectionReference<Map<String, dynamic>> _userSaved(String userId) =>
      _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.savedOpportunityPostsSubcollection);

  /// Live first page of active posts (newest). Optional category filter.
  Stream<List<OpportunityPostModel>> watchFeedHead({
    OpportunityCategory? category,
    int limit = pageSize,
  }) {
    Query<Map<String, dynamic>> query =
        _col.where('status', isEqualTo: OpportunityPostStatus.active.name);
    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => OpportunityPostModel.fromMap(d.id, d.data()))
              .where((p) => !p.isExpired)
              .toList(),
        );
  }

  Future<List<OpportunityPostModel>> fetchPage({
    OpportunityCategory? category,
    String? startAfterCreatedAt,
    int limit = pageSize,
  }) async {
    Query<Map<String, dynamic>> query =
        _col.where('status', isEqualTo: OpportunityPostStatus.active.name);
    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }
    query = query.orderBy('createdAt', descending: true).limit(limit);
    if (startAfterCreatedAt != null && startAfterCreatedAt.isNotEmpty) {
      query = query.startAfter([startAfterCreatedAt]);
    }
    final snap = await query.get();
    return snap.docs
        .map((d) => OpportunityPostModel.fromMap(d.id, d.data()))
        .where((p) => !p.isExpired)
        .toList();
  }

  Future<OpportunityPostModel?> getPost(String postId) async {
    final doc = await _col.doc(postId).get();
    if (!doc.exists || doc.data() == null) return null;
    return OpportunityPostModel.fromMap(doc.id, doc.data()!);
  }

  Stream<OpportunityPostModel?> watchPost(String postId) {
    return _col.doc(postId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return OpportunityPostModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<String> createPost({
    required String authorId,
    required String authorName,
    required OpportunityCategory category,
    required String title,
    required String description,
    required LocationModel location,
    required Map<String, dynamic> fields,
    required List<OpportunityContactMethod> contactMethods,
    required int expiryDays,
    String? authorPhotoUrl,
    String? authorPlayerId,
    bool authorVerified = false,
    String contactPhone = '',
    String contactWhatsApp = '',
    List<String> mediaUrls = const [],
    List<String> tags = const [],
  }) async {
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(Duration(days: expiryDays));
    final searchText = OpportunityPostModel.buildSearchText(
      title: title,
      description: description,
      location: location,
      fields: fields,
      authorName: authorName,
    );
    final doc = await _col.add({
      'authorId': authorId,
      'authorName': authorName.trim(),
      'authorPhotoUrl': ?authorPhotoUrl,
      'authorPlayerId': ?authorPlayerId,
      'authorVerified': authorVerified,
      'category': category.name,
      'title': title.trim(),
      'description': description.trim(),
      'location': location.toMap(),
      'fields': fields,
      'tags': tags,
      'searchText': searchText,
      'contactMethods': contactMethods.map((e) => e.name).toList(),
      'contactPhone': contactPhone.trim(),
      'contactWhatsApp': contactWhatsApp.trim(),
      'mediaUrls': mediaUrls,
      'status': OpportunityPostStatus.active.name,
      'expiryDays': expiryDays,
      'expiresAt': expiresAt.toIso8601String(),
      'viewCount': 0,
      'shareCount': 0,
      'saveCount': 0,
      'applicationCount': 0,
      'isPinned': false,
      'isFeatured': false,
      'isPremium': false,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });
    return doc.id;
  }

  Future<void> updatePost({
    required String postId,
    required String title,
    required String description,
    required LocationModel location,
    required Map<String, dynamic> fields,
    required List<OpportunityContactMethod> contactMethods,
    String contactPhone = '',
    String contactWhatsApp = '',
    List<String> mediaUrls = const [],
  }) async {
    final existing = await getPost(postId);
    if (existing == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final searchText = OpportunityPostModel.buildSearchText(
      title: title,
      description: description,
      location: location,
      fields: fields,
      authorName: existing.authorName,
    );
    await _col.doc(postId).update({
      'title': title.trim(),
      'description': description.trim(),
      'location': location.toMap(),
      'fields': fields,
      'searchText': searchText,
      'contactMethods': contactMethods.map((e) => e.name).toList(),
      'contactPhone': contactPhone.trim(),
      'contactWhatsApp': contactWhatsApp.trim(),
      'mediaUrls': mediaUrls,
      'updatedAt': now,
    });
  }

  Future<void> deletePost(String postId) async {
    await _col.doc(postId).delete();
  }

  Future<void> softRemovePost(String postId) async {
    await _col.doc(postId).update({
      'status': OpportunityPostStatus.removed.name,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> markExpiredIfNeeded(OpportunityPostModel post) async {
    if (!post.isExpired || post.status == OpportunityPostStatus.expired) {
      return;
    }
    try {
      await _col.doc(post.id).update({
        'status': OpportunityPostStatus.expired.name,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> setPinned({
    required String postId,
    required bool pinned,
  }) async {
    await _col.doc(postId).update({
      'isPinned': pinned,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> setFeatured({
    required String postId,
    required bool featured,
  }) async {
    await _col.doc(postId).update({
      'isFeatured': featured,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> incrementViewCount(String postId) async {
    await _col.doc(postId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  Future<void> incrementShareCount(String postId) async {
    await _col.doc(postId).update({
      'shareCount': FieldValue.increment(1),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Stream<bool> watchSaved({
    required String postId,
    required String userId,
  }) {
    return _col
        .doc(postId)
        .collection('saves')
        .doc(userId)
        .snapshots()
        .map((d) => d.exists);
  }

  Stream<List<String>> watchSavedPostIds(String userId) {
    return _userSaved(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }

  Future<List<OpportunityPostModel>> fetchPostsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final posts = <OpportunityPostModel>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snaps = await Future.wait(chunk.map((id) => _col.doc(id).get()));
      for (final snap in snaps) {
        if (!snap.exists || snap.data() == null) continue;
        posts.add(OpportunityPostModel.fromMap(snap.id, snap.data()!));
      }
    }
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
    final userSaveRef = _userSaved(userId).doc(postId);
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

  Future<void> reportPost({
    required String postId,
    required String reporterUserId,
    required String reason,
    String? authorId,
    String details = '',
  }) async {
    await _reports.add({
      'postId': postId,
      'authorId': ?authorId,
      'reporterUserId': reporterUserId,
      'reason': reason.trim(),
      if (details.isNotEmpty) 'details': details.trim(),
      'status': 'pending',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Client-side search over a recent window (indexed via [searchText]).
  Future<List<OpportunityPostModel>> searchPosts(
    String query, {
    OpportunityCategory? category,
    int limit = 40,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    Query<Map<String, dynamic>> firestoreQuery =
        _col.where('status', isEqualTo: OpportunityPostStatus.active.name);
    if (category != null) {
      firestoreQuery =
          firestoreQuery.where('category', isEqualTo: category.name);
    }
    final snap = await firestoreQuery
        .orderBy('createdAt', descending: true)
        .limit(150)
        .get();

    final hits = <OpportunityPostModel>[];
    for (final doc in snap.docs) {
      final post = OpportunityPostModel.fromMap(doc.id, doc.data());
      if (post.isExpired) continue;
      final hay = post.searchText.isNotEmpty
          ? post.searchText
          : OpportunityPostModel.buildSearchText(
              title: post.title,
              description: post.description,
              location: post.location,
              fields: post.fields,
              authorName: post.authorName,
            );
      if (hay.contains(q)) {
        hits.add(post);
      }
      if (hits.length >= limit) break;
    }
    return hits;
  }

  Future<List<OpportunityPostModel>> fetchByAuthor(
    String authorId, {
    int limit = 20,
  }) async {
    final snap = await _col
        .where('authorId', isEqualTo: authorId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => OpportunityPostModel.fromMap(d.id, d.data()))
        .toList();
  }

  /// Watches platform admin UIDs from `app_meta/platform_admins`.
  Stream<Set<String>> watchPlatformAdminIds() {
    return _firestore
        .collection('app_meta')
        .doc('platform_admins')
        .snapshots()
        .map((doc) {
      final raw = doc.data()?['uids'];
      if (raw is! List) return <String>{};
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet();
    });
  }
}
