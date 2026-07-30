import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'moderation_enums.dart';

class ManagedModerationPost extends Equatable {
  const ManagedModerationPost({
    required this.id,
    required this.source,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    this.authorPlayerId,
    this.title = '',
    this.body = '',
    this.category = '',
    this.postKind = '',
    this.thumbnailUrl,
    this.mediaUrls = const [],
    this.hasVideo = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.viewCount = 0,
    this.reportCount = 0,
    this.status = ManagedPostAdminStatus.published,
    this.featured = false,
    this.pinned = false,
    this.tournamentId,
    this.tournamentName,
    this.matchId,
    this.teamId,
    this.country = '',
    this.stateProvince = '',
    this.city = '',
    this.tags = const [],
    this.contactPhone = '',
    this.contactWhatsApp = '',
    this.createdAt,
    this.updatedAt,
    this.organizationId,
  });

  final String id;
  final ModerationSource source;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String? authorPlayerId;
  final String title;
  final String body;
  final String category;
  final String postKind;
  final String? thumbnailUrl;
  final List<String> mediaUrls;
  final bool hasVideo;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int viewCount;
  final int reportCount;
  final ManagedPostAdminStatus status;
  final bool featured;
  final bool pinned;
  final String? tournamentId;
  final String? tournamentName;
  final String? matchId;
  final String? teamId;
  final String country;
  final String stateProvince;
  final String city;
  final List<String> tags;
  final String contactPhone;
  final String contactWhatsApp;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? organizationId;

  bool get isTournamentPost =>
      (tournamentId != null && tournamentId!.isNotEmpty) ||
      postKind.toLowerCase().contains('tournament') ||
      category.toLowerCase().contains('tournament');

  bool get hasMedia => mediaUrls.isNotEmpty || (thumbnailUrl?.isNotEmpty ?? false);

  String get locationLabel {
    final parts = [
      if (city.isNotEmpty) city,
      if (stateProvince.isNotEmpty) stateProvince,
      if (country.isNotEmpty) country,
    ];
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    if (body.trim().isNotEmpty) {
      final t = body.trim();
      return t.length > 80 ? '${t.substring(0, 80)}…' : t;
    }
    return 'Untitled';
  }

  factory ManagedModerationPost.fromCommunity({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final location = map['location'];
    final loc =
        location is Map ? Map<String, dynamic>.from(location) : const {};
    final mediaRaw = map['media'];
    final mediaUrls = <String>[];
    var hasVideo = false;
    if (mediaRaw is List) {
      for (final item in mediaRaw) {
        if (item is Map) {
          final url = item['url'] as String? ?? '';
          if (url.isNotEmpty) mediaUrls.add(url);
          if ((item['type'] as String?) == 'video') hasVideo = true;
        } else if (item is String && item.isNotEmpty) {
          mediaUrls.add(item);
        }
      }
    }
    final legacyImage = map['imageUrl'] as String? ?? map['mediaUrl'] as String?;
    if (mediaUrls.isEmpty && legacyImage != null && legacyImage.isNotEmpty) {
      mediaUrls.add(legacyImage);
    }
    final snapshot = map['tournamentSnapshot'];
    final snap =
        snapshot is Map ? Map<String, dynamic>.from(snapshot) : const {};
    final adminStatus = map['adminStatus'] as String?;

    return ManagedModerationPost(
      id: id,
      source: ModerationSource.community,
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      authorPhotoUrl: map['authorPhotoUrl'] as String?,
      authorPlayerId: map['authorPlayerId'] as String?,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      category: map['category'] as String? ?? '',
      postKind: map['postKind'] as String? ?? '',
      thumbnailUrl: mediaUrls.isNotEmpty ? mediaUrls.first : null,
      mediaUrls: mediaUrls,
      hasVideo: hasVideo,
      likeCount: (map['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (map['commentCount'] as num?)?.toInt() ?? 0,
      shareCount: (map['shareCount'] as num?)?.toInt() ?? 0,
      status: ManagedPostAdminStatus.parse(adminStatus),
      featured: map['adminFeatured'] as bool? ?? false,
      pinned: map['isPinned'] as bool? ?? false,
      tournamentId: map['tournamentId'] as String?,
      tournamentName: snap['name'] as String?,
      matchId: map['matchId'] as String?,
      teamId: map['teamId'] as String?,
      country: loc['country'] as String? ?? '',
      stateProvince: (loc['stateProvince'] as String?) ??
          (loc['state'] as String?) ??
          '',
      city: loc['city'] as String? ?? '',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      organizationId: map['organizationId'] as String?,
    );
  }

  factory ManagedModerationPost.fromDiscover({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final location = map['location'];
    final loc =
        location is Map ? Map<String, dynamic>.from(location) : const {};
    final mediaUrls =
        List<String>.from(map['mediaUrls'] as List? ?? const []);
    final statusRaw = map['status'] as String?;

    return ManagedModerationPost(
      id: id,
      source: ModerationSource.discover,
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      authorPhotoUrl: map['authorPhotoUrl'] as String?,
      authorPlayerId: map['authorPlayerId'] as String?,
      title: map['title'] as String? ?? '',
      body: map['description'] as String? ?? '',
      category: map['category'] as String? ?? '',
      thumbnailUrl: mediaUrls.isNotEmpty ? mediaUrls.first : null,
      mediaUrls: mediaUrls,
      viewCount: (map['viewCount'] as num?)?.toInt() ?? 0,
      shareCount: (map['shareCount'] as num?)?.toInt() ?? 0,
      status: ManagedPostAdminStatus.parse(statusRaw),
      featured: map['isFeatured'] as bool? ?? false,
      pinned: map['isPinned'] as bool? ?? false,
      country: loc['country'] as String? ?? '',
      stateProvince: (loc['stateProvince'] as String?) ??
          (loc['state'] as String?) ??
          '',
      city: loc['city'] as String? ?? '',
      tags: List<String>.from(map['tags'] as List? ?? const []),
      contactPhone: map['contactPhone'] as String? ?? '',
      contactWhatsApp: map['contactWhatsApp'] as String? ?? '',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      organizationId: map['organizationId'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        raw > 9999999999 ? raw : raw * 1000,
      );
    }
    return null;
  }

  @override
  List<Object?> get props => [id, source, status, featured, updatedAt];
}

class ManagedContentReport extends Equatable {
  const ManagedContentReport({
    required this.id,
    required this.source,
    required this.reporterUserId,
    required this.reason,
    this.postId = '',
    this.authorId,
    this.commentId,
    this.targetType = ManagedReportTargetType.post,
    this.details = '',
    this.status = ManagedReportStatus.pending,
    this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
    this.resolution,
  });

  final String id;
  final ModerationSource source;
  final String reporterUserId;
  final String reason;
  final String postId;
  final String? authorId;
  final String? commentId;
  final ManagedReportTargetType targetType;
  final String details;
  final ManagedReportStatus status;
  final DateTime? createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? resolution;

  factory ManagedContentReport.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
    required ModerationSource source,
  }) {
    final typeRaw = map['type'] as String?;
    final commentId = map['commentId'] as String?;
    var target = ManagedReportTargetType.post;
    if (typeRaw == 'user') {
      target = ManagedReportTargetType.user;
    } else if (commentId != null && commentId.isNotEmpty) {
      target = ManagedReportTargetType.comment;
    }

    return ManagedContentReport(
      id: id,
      source: source,
      reporterUserId: map['reporterUserId'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      postId: map['postId'] as String? ?? '',
      authorId: map['authorId'] as String?,
      commentId: commentId,
      targetType: target,
      details: map['details'] as String? ?? '',
      status: ManagedReportStatus.parse(map['status'] as String?),
      createdAt: ManagedModerationPost._parseDate(map['createdAt']),
      reviewedBy: map['reviewedBy'] as String?,
      reviewedAt: ManagedModerationPost._parseDate(map['reviewedAt']),
      resolution: map['resolution'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, status, createdAt];
}

/// Chat thread metadata only — never includes message bodies.
class ManagedChatThread extends Equatable {
  const ManagedChatThread({
    required this.id,
    this.participantIds = const [],
    this.participantNames = const [],
    this.status = 'active',
    this.lastMessagePreview = '',
    this.lastMessageAt,
    this.createdAt,
    this.reported = false,
  });

  final String id;
  final List<String> participantIds;
  final List<String> participantNames;
  final String status;
  final String lastMessagePreview;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final bool reported;

  factory ManagedChatThread.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final participants = map['participants'];
    final names = <String>[];
    if (participants is Map) {
      for (final v in participants.values) {
        if (v is Map) {
          final n = v['name'] as String? ?? v['displayName'] as String? ?? '';
          if (n.isNotEmpty) names.add(n);
        }
      }
    }
    // Never surface private message bodies — metadata only.
    // Reported message content is loaded separately when a report exists.
    final reported = map['reported'] as bool? ??
        ((map['reportCount'] as num?)?.toInt() ?? 0) > 0;
    return ManagedChatThread(
      id: id,
      participantIds: List<String>.from(map['participantIds'] as List? ?? const []),
      participantNames: names,
      status: map['status'] as String? ?? 'active',
      lastMessagePreview: '',
      lastMessageAt: ManagedModerationPost._parseDate(map['lastMessageAt']),
      createdAt: ManagedModerationPost._parseDate(map['createdAt']),
      reported: reported,
    );
  }

  @override
  List<Object?> get props => [id, status, lastMessageAt];
}

class ModerationSummaryStats {
  const ModerationSummaryStats({
    this.communityPosts = 0,
    this.discoverPosts = 0,
    this.postsToday = 0,
    this.activeChats = 0,
    this.pendingReports = 0,
    this.removedPosts = 0,
    this.blockedUsers = 0,
    this.trendingPosts = 0,
  });

  final int communityPosts;
  final int discoverPosts;
  final int postsToday;
  final int activeChats;
  final int pendingReports;
  final int removedPosts;
  final int blockedUsers;
  final int trendingPosts;
}

class ModerationPageResult {
  const ModerationPageResult({
    required this.posts,
    required this.hasMore,
    this.cursor,
  });

  final List<ManagedModerationPost> posts;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
}
