import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';
import 'location_model.dart';

/// Single media attachment on a community post (backward-compatible).
class CommunityMediaItem extends Equatable {
  const CommunityMediaItem({
    required this.url,
    this.type = 'image',
    this.aspect = CommunityMediaAspect.square,
  });

  final String url;
  final String type; // image | video
  final CommunityMediaAspect aspect;

  factory CommunityMediaItem.fromMap(Map<String, dynamic> map) {
    return CommunityMediaItem(
      url: map['url'] as String? ?? '',
      type: map['type'] as String? ?? 'image',
      aspect: CommunityMediaAspectX.parse(
        map['aspect'] as String?,
        fallback: CommunityMediaAspect.square,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'url': url,
        'type': type,
        'aspect': aspect.name,
      };

  double get aspectRatio => aspect.displayRatio;

  @override
  List<Object?> get props => [url, type, aspect];
}

/// Denormalized tournament card payload for feed embeds.
class CommunityTournamentSnapshot extends Equatable {
  const CommunityTournamentSnapshot({
    this.tournamentId = '',
    this.name = '',
    this.organizer = '',
    this.thumbnailUrl,
    this.thumbnailAspect = CommunityMediaAspect.landscape16x9,
    this.locationLabel = '',
    this.startDate,
    this.endDate,
    this.entryFee,
    this.ballType = '',
    this.matchFormat = '',
    this.teamCount,
    this.registrationStatus = '',
    this.contactVisibility = CommunityContactVisibility.hide,
    this.contactPhone = '',
    this.contactWhatsApp = '',
    this.contactEmail = '',
    this.organizerUserId = '',
    this.organizerPlayerId = '',
    this.organizerPhotoUrl,
  });

  final String tournamentId;
  final String name;
  final String organizer;
  final String? thumbnailUrl;
  final CommunityMediaAspect thumbnailAspect;
  final String locationLabel;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? entryFee;
  final String ballType;
  final String matchFormat;
  final int? teamCount;
  final String registrationStatus;
  final CommunityContactVisibility contactVisibility;
  final String contactPhone;
  final String contactWhatsApp;
  final String contactEmail;
  /// Firebase uid of the organizer (for CrickFlow DM).
  final String organizerUserId;
  final String organizerPlayerId;
  final String? organizerPhotoUrl;

  factory CommunityTournamentSnapshot.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const CommunityTournamentSnapshot();
    return CommunityTournamentSnapshot(
      tournamentId: map['tournamentId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      organizer: map['organizer'] as String? ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String?,
      thumbnailAspect: CommunityMediaAspectX.parse(
        map['thumbnailAspect'] as String?,
      ),
      locationLabel: map['locationLabel'] as String? ?? '',
      startDate: DateTime.tryParse(map['startDate']?.toString() ?? ''),
      endDate: DateTime.tryParse(map['endDate']?.toString() ?? ''),
      entryFee: map['entryFee']?.toString(),
      ballType: map['ballType'] as String? ?? '',
      matchFormat: map['matchFormat'] as String? ?? '',
      teamCount: map['teamCount'] as int?,
      registrationStatus: map['registrationStatus'] as String? ?? '',
      contactVisibility: CommunityContactVisibility.values.firstWhere(
        (e) => e.name == map['contactVisibility'],
        orElse: () => CommunityContactVisibility.hide,
      ),
      contactPhone: map['contactPhone'] as String? ?? '',
      contactWhatsApp: map['contactWhatsApp'] as String? ?? '',
      contactEmail: map['contactEmail'] as String? ?? '',
      organizerUserId: map['organizerUserId'] as String? ?? '',
      organizerPlayerId: map['organizerPlayerId'] as String? ?? '',
      organizerPhotoUrl: map['organizerPhotoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'tournamentId': tournamentId,
        'name': name,
        'organizer': organizer,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        'thumbnailAspect': thumbnailAspect.name,
        'locationLabel': locationLabel,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        if (entryFee != null) 'entryFee': entryFee,
        'ballType': ballType,
        'matchFormat': matchFormat,
        if (teamCount != null) 'teamCount': teamCount,
        'registrationStatus': registrationStatus,
        'contactVisibility': contactVisibility.name,
        if (contactPhone.isNotEmpty) 'contactPhone': contactPhone,
        if (contactWhatsApp.isNotEmpty) 'contactWhatsApp': contactWhatsApp,
        if (contactEmail.isNotEmpty) 'contactEmail': contactEmail,
        if (organizerUserId.isNotEmpty) 'organizerUserId': organizerUserId,
        if (organizerPlayerId.isNotEmpty)
          'organizerPlayerId': organizerPlayerId,
        if (organizerPhotoUrl != null && organizerPhotoUrl!.isNotEmpty)
          'organizerPhotoUrl': organizerPhotoUrl,
      };

  @override
  List<Object?> get props =>
      [tournamentId, name, thumbnailUrl, thumbnailAspect, contactVisibility];
}

class CommunityPostModel extends Equatable {
  const CommunityPostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.body,
    this.category = CommunityPostCategory.general,
    this.postKind = CommunityPostKind.general,
    this.authorRole = '',
    this.authorPhotoUrl,
    this.authorPlayerId,
    this.authorVerified = false,
    this.location = const LocationModel(),
    this.tournamentId,
    this.matchId,
    this.teamId,
    this.media = const [],
    this.tournamentSnapshot,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.saveCount = 0,
    this.isPinned = false,
    this.isSponsored = false,
    this.isAdminPost = false,
    this.createdAt,
    this.updatedAt,
    this.editedAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String? authorPhotoUrl;
  final String? authorPlayerId;
  final bool authorVerified;
  final CommunityPostCategory category;
  final CommunityPostKind postKind;
  final String title;
  final String body;
  final LocationModel location;
  final String? tournamentId;
  final String? matchId;
  final String? teamId;
  final List<CommunityMediaItem> media;
  final CommunityTournamentSnapshot? tournamentSnapshot;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int saveCount;
  final bool isPinned;
  final bool isSponsored;
  final bool isAdminPost;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? editedAt;

  bool get isEdited => editedAt != null;

  bool get hasTournamentEmbed =>
      tournamentSnapshot != null &&
      (tournamentSnapshot!.name.isNotEmpty ||
          (tournamentId != null && tournamentId!.isNotEmpty));

  factory CommunityPostModel.fromMap(String id, Map<String, dynamic> map) {
    final mediaRaw = map['media'] as List? ?? const [];
    final media = <CommunityMediaItem>[
      ...mediaRaw
          .whereType<Map>()
          .map((e) => CommunityMediaItem.fromMap(Map<String, dynamic>.from(e)))
          .where((m) => m.url.isNotEmpty),
    ];

    // Legacy single-image fields
    final legacyUrl = map['imageUrl'] as String? ?? map['mediaUrl'] as String?;
    if (media.isEmpty && legacyUrl != null && legacyUrl.isNotEmpty) {
      media.add(CommunityMediaItem(url: legacyUrl));
    }

    return CommunityPostModel(
      id: id,
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      authorRole: map['authorRole'] as String? ?? '',
      authorPhotoUrl: map['authorPhotoUrl'] as String?,
      authorPlayerId: map['authorPlayerId'] as String?,
      authorVerified: map['authorVerified'] as bool? ?? false,
      category: _categoryFromString(map['category'] as String?),
      postKind: _kindFromString(map['postKind'] as String?) ??
          _kindFromCategory(_categoryFromString(map['category'] as String?)),
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      location: LocationModel.fromMap(map['location'] as Map<String, dynamic>?),
      tournamentId: map['tournamentId'] as String?,
      matchId: map['matchId'] as String?,
      teamId: map['teamId'] as String?,
      media: media,
      tournamentSnapshot: map['tournamentSnapshot'] is Map
          ? CommunityTournamentSnapshot.fromMap(
              Map<String, dynamic>.from(map['tournamentSnapshot'] as Map),
            )
          : null,
      likeCount: (map['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (map['commentCount'] as num?)?.toInt() ?? 0,
      shareCount: (map['shareCount'] as num?)?.toInt() ?? 0,
      saveCount: (map['saveCount'] as num?)?.toInt() ?? 0,
      isPinned: map['isPinned'] as bool? ?? false,
      isSponsored: map['isSponsored'] as bool? ?? false,
      isAdminPost: map['isAdminPost'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
      editedAt: DateTime.tryParse(map['editedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'authorName': authorName,
        if (authorRole.isNotEmpty) 'authorRole': authorRole,
        if (authorPhotoUrl != null) 'authorPhotoUrl': authorPhotoUrl,
        if (authorPlayerId != null) 'authorPlayerId': authorPlayerId,
        'authorVerified': authorVerified,
        'category': category.name,
        'postKind': postKind.name,
        'title': title,
        'body': body,
        'location': location.toMap(),
        if (tournamentId != null && tournamentId!.isNotEmpty)
          'tournamentId': tournamentId,
        if (matchId != null && matchId!.isNotEmpty) 'matchId': matchId,
        if (teamId != null && teamId!.isNotEmpty) 'teamId': teamId,
        if (media.isNotEmpty) 'media': media.map((m) => m.toMap()).toList(),
        if (tournamentSnapshot != null)
          'tournamentSnapshot': tournamentSnapshot!.toMap(),
        'likeCount': likeCount,
        'commentCount': commentCount,
        'shareCount': shareCount,
        'saveCount': saveCount,
        'isPinned': isPinned,
        'isSponsored': isSponsored,
        'isAdminPost': isAdminPost,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
      };

  static CommunityPostCategory _categoryFromString(String? raw) {
    return CommunityPostCategory.values.firstWhere(
      (c) => c.name == raw,
      orElse: () => CommunityPostCategory.general,
    );
  }

  static CommunityPostKind? _kindFromString(String? raw) {
    if (raw == null) return null;
    for (final k in CommunityPostKind.values) {
      if (k.name == raw) return k;
    }
    return null;
  }

  static CommunityPostKind _kindFromCategory(CommunityPostCategory c) {
    return switch (c) {
      CommunityPostCategory.tournamentNeed => CommunityPostKind.tournament,
      CommunityPostCategory.team => CommunityPostKind.team,
      CommunityPostCategory.achievement => CommunityPostKind.achievement,
      CommunityPostCategory.match => CommunityPostKind.match,
      _ => CommunityPostKind.general,
    };
  }

  @override
  List<Object?> get props =>
      [id, authorId, title, body, category, likeCount, editedAt, createdAt];
}
