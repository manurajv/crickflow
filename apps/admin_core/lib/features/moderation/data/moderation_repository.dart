import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/constants/admin_collections.dart';
import '../../../models/admin_user.dart';
import '../../users/models/admin_audit_log.dart';
import '../models/managed_moderation.dart';
import '../models/moderation_enums.dart';
import '../models/moderation_filters.dart';

/// Admin moderation reads/writes for community + discover.
///
/// Does not read private chat message bodies. Soft-moderates via additive /
/// existing status fields. Mobile create/feed flows are unchanged.
class ModerationRepository {
  ModerationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _community =>
      _db.collection(AdminCollections.communityPosts);
  CollectionReference<Map<String, dynamic>> get _discover =>
      _db.collection(AdminCollections.opportunityPosts);
  CollectionReference<Map<String, dynamic>> get _communityReports =>
      _db.collection(AdminCollections.communityPostReports);
  CollectionReference<Map<String, dynamic>> get _discoverReports =>
      _db.collection(AdminCollections.opportunityPostReports);
  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection(AdminCollections.chats);
  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  Future<ModerationPageResult> fetchCommunityPage({
    required AdminAppType appType,
    required AdminUser? actor,
    required ModerationListFilters filters,
    required ModerationSort sort,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    Query<Map<String, dynamic>> query = _community;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) {
        return const ModerationPageResult(posts: [], hasMore: false);
      }
      query = query.where('organizationId', isEqualTo: orgId);
    }
    if (filters.tournamentOnly) {
      // Client filter — not all docs have tournamentId indexed the same way.
    }
    query = query.orderBy('createdAt', descending: sort.descending);
    if (startAfter != null) query = query.startAfterDocument(startAfter);

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await query.limit(limit + 1).get();
    } on FirebaseException {
      snap = await _community
          .orderBy(FieldPath.documentId)
          .limit(limit + 1)
          .get();
    }

    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;
    var posts = pageDocs
        .map((d) => ManagedModerationPost.fromCommunity(id: d.id, map: d.data()))
        .toList();
    posts = _applyPostFilters(posts, filters, source: ModerationSource.community);
    _sortPosts(posts, sort);
    return ModerationPageResult(
      posts: posts,
      hasMore: hasMore,
      cursor: pageDocs.isEmpty ? null : pageDocs.last,
    );
  }

  Future<ModerationPageResult> fetchDiscoverPage({
    required AdminAppType appType,
    required AdminUser? actor,
    required ModerationListFilters filters,
    required ModerationSort sort,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    Query<Map<String, dynamic>> query = _discover;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) {
        return const ModerationPageResult(posts: [], hasMore: false);
      }
      query = query.where('organizationId', isEqualTo: orgId);
    }
    query = query.orderBy('createdAt', descending: sort.descending);
    if (startAfter != null) query = query.startAfterDocument(startAfter);

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await query.limit(limit + 1).get();
    } on FirebaseException {
      snap =
          await _discover.orderBy(FieldPath.documentId).limit(limit + 1).get();
    }

    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;
    var posts = pageDocs
        .map((d) => ManagedModerationPost.fromDiscover(id: d.id, map: d.data()))
        .toList();
    posts = _applyPostFilters(posts, filters, source: ModerationSource.discover);
    _sortPosts(posts, sort);
    return ModerationPageResult(
      posts: posts,
      hasMore: hasMore,
      cursor: pageDocs.isEmpty ? null : pageDocs.last,
    );
  }

  List<ManagedModerationPost> _applyPostFilters(
    List<ManagedModerationPost> list,
    ModerationListFilters filters, {
    required ModerationSource source,
  }) {
    Iterable<ManagedModerationPost> items = list;
    if (!filters.includeRemoved) {
      items = items.where(
        (p) =>
            p.status != ManagedPostAdminStatus.removed &&
            p.status != ManagedPostAdminStatus.hidden,
      );
    }
    if (filters.tournamentOnly) {
      items = items.where((p) => p.isTournamentPost);
    }
    if (filters.statuses.isNotEmpty) {
      items = items.where((p) => filters.statuses.contains(p.status));
    }
    if (filters.hasMedia == true) {
      items = items.where((p) => p.hasMedia);
    } else if (filters.hasMedia == false) {
      items = items.where((p) => !p.hasMedia);
    }
    if (filters.mediaType == 'video') {
      items = items.where((p) => p.hasVideo);
    } else if (filters.mediaType == 'image') {
      items = items.where((p) => p.hasMedia && !p.hasVideo);
    } else if (filters.mediaType == 'none') {
      items = items.where((p) => !p.hasMedia);
    }
    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((p) {
        return p.id.toLowerCase().contains(q) ||
            p.authorName.toLowerCase().contains(q) ||
            p.authorId.toLowerCase().contains(q) ||
            (p.authorPlayerId?.toLowerCase().contains(q) ?? false) ||
            p.displayTitle.toLowerCase().contains(q) ||
            p.body.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            (p.tournamentName?.toLowerCase().contains(q) ?? false) ||
            (p.tournamentId?.toLowerCase().contains(q) ?? false) ||
            p.tags.any((t) => t.toLowerCase().contains(q)) ||
            p.city.toLowerCase().contains(q) ||
            p.country.toLowerCase().contains(q);
      });
    }
    if (filters.country?.trim().isNotEmpty == true) {
      final c = filters.country!.trim().toLowerCase();
      items = items.where((p) => p.country.toLowerCase().contains(c));
    }
    if (filters.stateProvince?.trim().isNotEmpty == true) {
      final s = filters.stateProvince!.trim().toLowerCase();
      items = items.where((p) => p.stateProvince.toLowerCase().contains(s));
    }
    if (filters.city?.trim().isNotEmpty == true) {
      final c = filters.city!.trim().toLowerCase();
      items = items.where((p) => p.city.toLowerCase().contains(c));
    }
    if (filters.from != null) {
      items = items.where(
        (p) => p.createdAt != null && !p.createdAt!.isBefore(filters.from!),
      );
    }
    if (filters.to != null) {
      items = items.where(
        (p) => p.createdAt != null && !p.createdAt!.isAfter(filters.to!),
      );
    }
    return items.toList();
  }

  void _sortPosts(List<ManagedModerationPost> list, ModerationSort sort) {
    int cmp(ManagedModerationPost a, ManagedModerationPost b) {
      final r = switch (sort.field) {
        ModerationSortField.createdAt =>
          (a.createdAt ?? DateTime(1970)).compareTo(b.createdAt ?? DateTime(1970)),
        ModerationSortField.likes => a.likeCount.compareTo(b.likeCount),
        ModerationSortField.comments =>
          a.commentCount.compareTo(b.commentCount),
        ModerationSortField.reports => a.reportCount.compareTo(b.reportCount),
        ModerationSortField.author =>
          a.authorName.toLowerCase().compareTo(b.authorName.toLowerCase()),
      };
      return sort.descending ? -r : r;
    }

    list.sort(cmp);
  }

  Stream<ManagedModerationPost?> watchCommunityPost(String id) {
    return _community.doc(id).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return ManagedModerationPost.fromCommunity(id: snap.id, map: snap.data()!);
    });
  }

  Stream<ManagedModerationPost?> watchDiscoverPost(String id) {
    return _discover.doc(id).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return ManagedModerationPost.fromDiscover(id: snap.id, map: snap.data()!);
    });
  }

  Future<List<ManagedContentReport>> fetchReports({
    required bool usersOnly,
    int limit = 80,
  }) async {
    final out = <ManagedContentReport>[];
    try {
      final cSnap = await _communityReports
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      for (final d in cSnap.docs) {
        final r = ManagedContentReport.fromFirestore(
          id: d.id,
          map: d.data(),
          source: ModerationSource.community,
        );
        if (usersOnly) {
          if (r.targetType == ManagedReportTargetType.user) out.add(r);
        } else if (r.targetType != ManagedReportTargetType.user) {
          out.add(r);
        }
      }
    } catch (_) {}
    if (!usersOnly) {
      try {
        final dSnap = await _discoverReports
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
        for (final d in dSnap.docs) {
          out.add(
            ManagedContentReport.fromFirestore(
              id: d.id,
              map: d.data(),
              source: ModerationSource.discover,
            ),
          );
        }
      } catch (_) {}
    }
    out.sort(
      (a, b) => (b.createdAt ?? DateTime(1970))
          .compareTo(a.createdAt ?? DateTime(1970)),
    );
    return out;
  }

  /// Metadata-only chat list. Fails closed if rules deny admin access.
  Future<List<ManagedChatThread>> fetchChatMetadata({int limit = 40}) async {
    try {
      final snap =
          await _chats.orderBy('lastMessageAt', descending: true).limit(limit).get();
      return snap.docs
          .map((d) => ManagedChatThread.fromFirestore(id: d.id, map: d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<ModerationSummaryStats> fetchSummary({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    try {
      final todayStart = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      Query<Map<String, dynamic>> cQuery = _community;
      Query<Map<String, dynamic>> dQuery = _discover;
      if (appType == AdminAppType.organizationAdmin) {
        final orgId = actor?.organizationId;
        if (orgId == null || orgId.isEmpty) {
          return const ModerationSummaryStats();
        }
        cQuery = cQuery.where('organizationId', isEqualTo: orgId);
        dQuery = dQuery.where('organizationId', isEqualTo: orgId);
      }

      final cSnap = await cQuery.limit(400).get();
      final dSnap = await dQuery.limit(400).get();
      final community = cSnap.docs
          .map((d) => ManagedModerationPost.fromCommunity(id: d.id, map: d.data()))
          .toList();
      final discover = dSnap.docs
          .map((d) => ManagedModerationPost.fromDiscover(id: d.id, map: d.data()))
          .toList();

      var pending = 0;
      try {
        final r1 = await _communityReports
            .where('status', isEqualTo: 'pending')
            .limit(100)
            .get();
        final r2 = await _discoverReports
            .where('status', isEqualTo: 'pending')
            .limit(100)
            .get();
        pending = r1.docs.length + r2.docs.length;
      } catch (_) {}

      final removed = [
        ...community.where((p) => p.status == ManagedPostAdminStatus.removed),
        ...discover.where((p) => p.status == ManagedPostAdminStatus.removed),
      ].length;

      final postsToday = [
        ...community,
        ...discover,
      ]
          .where(
            (p) => p.createdAt != null && !p.createdAt!.isBefore(todayStart),
          )
          .length;

      final trending = [...community]
        ..sort((a, b) => b.likeCount.compareTo(a.likeCount));

      return ModerationSummaryStats(
        communityPosts: community.length,
        discoverPosts: discover.length,
        postsToday: postsToday,
        pendingReports: pending,
        removedPosts: removed,
        trendingPosts: trending.take(10).length,
        activeChats: 0,
        blockedUsers: 0,
      );
    } catch (_) {
      return const ModerationSummaryStats();
    }
  }

  Future<List<ManagedModerationPost>> fetchTrending({int limit = 20}) async {
    try {
      final snap =
          await _community.orderBy('likeCount', descending: true).limit(limit).get();
      return snap.docs
          .map((d) => ManagedModerationPost.fromCommunity(id: d.id, map: d.data()))
          .toList();
    } on FirebaseException {
      final snap = await _community.limit(80).get();
      final list = snap.docs
          .map((d) => ManagedModerationPost.fromCommunity(id: d.id, map: d.data()))
          .toList()
        ..sort((a, b) => b.likeCount.compareTo(a.likeCount));
      return list.take(limit).toList();
    }
  }

  Future<void> setCommunityStatus({
    required ManagedModerationPost target,
    required ManagedPostAdminStatus status,
    required AdminUser actor,
    String? reason,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _community.doc(target.id).set({
      'adminStatus': status.wireValue,
      'adminModeratedAt': now,
      'adminModeratedBy': actor.uid,
      if (reason != null) 'adminModerationNote': reason,
      'updatedAt': now,
    }, SetOptions(merge: true));
    final action = switch (status) {
      ManagedPostAdminStatus.hidden => AdminAuditActions.communityHidden,
      ManagedPostAdminStatus.removed => AdminAuditActions.communityRemoved,
      ManagedPostAdminStatus.published => AdminAuditActions.communityRestored,
      ManagedPostAdminStatus.archived => AdminAuditActions.communityArchived,
      ManagedPostAdminStatus.pending => AdminAuditActions.communityApproved,
      ManagedPostAdminStatus.reported => AdminAuditActions.communityHidden,
    };
    await _writeAudit(
      action: action,
      actor: actor,
      targetId: target.id,
      targetLabel: target.displayTitle,
      reason: reason,
      metadata: {'source': 'community', 'status': status.wireValue},
    );
  }

  Future<void> setCommunityFeatured({
    required ManagedModerationPost target,
    required bool featured,
    required AdminUser actor,
    String? reason,
  }) async {
    await _community.doc(target.id).set({
      'adminFeatured': featured,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: featured
          ? AdminAuditActions.communityFeatured
          : AdminAuditActions.communityUnfeatured,
      actor: actor,
      targetId: target.id,
      targetLabel: target.displayTitle,
      reason: reason,
    );
  }

  Future<void> setDiscoverStatus({
    required ManagedModerationPost target,
    required String status, // active | removed | expired
    required AdminUser actor,
    String? reason,
  }) async {
    await _discover.doc(target.id).set({
      'status': status,
      'adminModeratedAt': DateTime.now().toIso8601String(),
      'adminModeratedBy': actor.uid,
      if (reason != null) 'adminModerationNote': reason,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: status == 'removed'
          ? AdminAuditActions.discoverRemoved
          : AdminAuditActions.discoverRestored,
      actor: actor,
      targetId: target.id,
      targetLabel: target.displayTitle,
      reason: reason,
      metadata: {'source': 'discover', 'status': status},
    );
  }

  Future<void> setDiscoverFeatured({
    required ManagedModerationPost target,
    required bool featured,
    required AdminUser actor,
    String? reason,
  }) async {
    await _discover.doc(target.id).set({
      'isFeatured': featured,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: featured
          ? AdminAuditActions.discoverFeatured
          : AdminAuditActions.discoverUnfeatured,
      actor: actor,
      targetId: target.id,
      targetLabel: target.displayTitle,
      reason: reason,
    );
  }

  Future<void> setDiscoverPinned({
    required ManagedModerationPost target,
    required bool pinned,
    required AdminUser actor,
    String? reason,
  }) async {
    await _discover.doc(target.id).set({
      'isPinned': pinned,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: pinned
          ? AdminAuditActions.discoverPinned
          : AdminAuditActions.discoverUnpinned,
      actor: actor,
      targetId: target.id,
      targetLabel: target.displayTitle,
      reason: reason,
    );
  }

  Future<void> resolveReport({
    required ManagedContentReport report,
    required ManagedReportStatus status,
    required AdminUser actor,
    String? resolution,
    String? reason,
  }) async {
    final col = report.source == ModerationSource.community
        ? _communityReports
        : _discoverReports;
    await col.doc(report.id).set({
      'status': status.wireValue,
      'reviewedBy': actor.uid,
      'reviewedAt': DateTime.now().toIso8601String(),
      if (resolution != null) 'resolution': resolution,
      if (reason != null) 'reviewNote': reason,
    }, SetOptions(merge: true));
    await _writeAudit(
      action: status == ManagedReportStatus.dismissed
          ? AdminAuditActions.reportDismissed
          : AdminAuditActions.reportResolved,
      actor: actor,
      targetId: report.id,
      targetLabel: report.reason,
      reason: reason ?? resolution,
      metadata: {
        'source': report.source.name,
        'postId': report.postId,
        'status': status.wireValue,
      },
    );
  }

  Future<List<AdminAuditLogEntry>> fetchAudit({
    String? targetId,
    int limit = 40,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _audit;
      if (targetId != null) {
        q = q.where('targetUid', isEqualTo: targetId);
      }
      final snap =
          await q.orderBy('timestamp', descending: true).limit(limit).get();
      return snap.docs
          .map((d) => AdminAuditLogEntry.fromMap(d.id, d.data()))
          .where(
            (e) =>
                e.action.startsWith('community.') ||
                e.action.startsWith('discover.') ||
                e.action.startsWith('report.'),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeAudit({
    required String action,
    required AdminUser actor,
    required String targetId,
    required String targetLabel,
    String? reason,
    Map<String, dynamic> metadata = const {},
  }) async {
    final entry = AdminAuditLogEntry(
      id: '',
      action: action,
      actorUid: actor.uid,
      actorEmail: actor.email,
      targetUid: targetId,
      targetEmail: targetLabel,
      timestamp: DateTime.now(),
      reason: reason,
      metadata: {...metadata, 'entity': 'moderation'},
    );
    await _audit.add(entry.toMap());
  }
}
