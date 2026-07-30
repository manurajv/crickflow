import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'ads_enums.dart';

class ManagedAdCampaign extends Equatable {
  const ManagedAdCampaign({
    required this.id,
    required this.title,
    this.description = '',
    this.campaignName = '',
    this.mediaType = ManagedAdMediaType.image,
    this.thumbnailUrl = '',
    this.bannerUrl = '',
    this.videoUrl = '',
    this.destinationUrl = '',
    this.buttonText = 'Learn more',
    this.status = ManagedAdStatus.draft,
    this.campaignType = ManagedAdCampaignType.brand,
    this.placements = const {ManagedAdPlacement.home},
    this.priority = 0,
    this.weight = 1,
    this.startDate,
    this.endDate,
    this.advertiserId,
    this.advertiserName = '',
    this.country = '',
    this.stateProvince = '',
    this.city = '',
    this.language = '',
    this.matchType = '',
    this.ballType = '',
    this.tournamentId,
    this.featured = false,
    this.impressions = 0,
    this.clicks = 0,
    this.estimatedRevenue = 0,
    this.homePromotionId,
    this.createdByUid = '',
    this.createdByEmail = '',
    this.organizationId,
    this.rejectionReason = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final String campaignName;
  final ManagedAdMediaType mediaType;
  final String thumbnailUrl;
  final String bannerUrl;
  final String videoUrl;
  final String destinationUrl;
  final String buttonText;
  final ManagedAdStatus status;
  final ManagedAdCampaignType campaignType;
  final Set<ManagedAdPlacement> placements;
  final int priority;
  final int weight;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? advertiserId;
  final String advertiserName;
  final String country;
  final String stateProvince;
  final String city;
  final String language;
  final String matchType;
  final String ballType;
  final String? tournamentId;
  final bool featured;
  final int impressions;
  final int clicks;
  final double estimatedRevenue;
  final String? homePromotionId;
  final String createdByUid;
  final String createdByEmail;
  final String? organizationId;
  final String rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayTitle =>
      title.trim().isNotEmpty ? title.trim() : (campaignName.trim().isNotEmpty ? campaignName.trim() : 'Untitled ad');

  double get ctr => impressions <= 0 ? 0 : clicks / impressions;

  String get placementLabel =>
      placements.map((p) => p.label).join(', ').isEmpty
          ? '—'
          : placements.map((p) => p.label).join(', ');

  factory ManagedAdCampaign.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final placements = <ManagedAdPlacement>{};
    final raw = map['placements'];
    if (raw is List) {
      for (final p in raw) {
        placements.add(ManagedAdPlacement.parse(p.toString()));
      }
    }
    if (placements.isEmpty) placements.add(ManagedAdPlacement.home);

    return ManagedAdCampaign(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      campaignName: map['campaignName'] as String? ?? '',
      mediaType: ManagedAdMediaType.parse(map['mediaType'] as String?),
      thumbnailUrl: map['thumbnailUrl'] as String? ?? '',
      bannerUrl: map['bannerUrl'] as String? ?? map['imageUrl'] as String? ?? '',
      videoUrl: map['videoUrl'] as String? ?? '',
      destinationUrl:
          map['destinationUrl'] as String? ?? map['redirectUrl'] as String? ?? '',
      buttonText: map['buttonText'] as String? ?? 'Learn more',
      status: ManagedAdStatus.parse(map['status'] as String?),
      campaignType: ManagedAdCampaignType.parse(map['campaignType'] as String?),
      placements: placements,
      priority: (map['priority'] as num?)?.toInt() ?? 0,
      weight: (map['weight'] as num?)?.toInt() ?? 1,
      startDate: _parseDate(map['startDate']),
      endDate: _parseDate(map['endDate']),
      advertiserId: map['advertiserId'] as String?,
      advertiserName: map['advertiserName'] as String? ?? '',
      country: map['country'] as String? ?? '',
      stateProvince:
          map['stateProvince'] as String? ?? map['state'] as String? ?? '',
      city: map['city'] as String? ?? '',
      language: map['language'] as String? ?? '',
      matchType: map['matchType'] as String? ?? '',
      ballType: map['ballType'] as String? ?? '',
      tournamentId: map['tournamentId'] as String?,
      featured: map['featured'] as bool? ?? false,
      impressions: (map['impressions'] as num?)?.toInt() ?? 0,
      clicks: (map['clicks'] as num?)?.toInt() ?? 0,
      estimatedRevenue: (map['estimatedRevenue'] as num?)?.toDouble() ?? 0,
      homePromotionId: map['homePromotionId'] as String?,
      createdByUid: map['createdByUid'] as String? ?? '',
      createdByEmail: map['createdByEmail'] as String? ?? '',
      organizationId: map['organizationId'] as String?,
      rejectionReason: map['rejectionReason'] as String? ?? '',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap({bool forCreate = false}) => {
        'title': title,
        'description': description,
        'campaignName': campaignName,
        'mediaType': mediaType.wireValue,
        'thumbnailUrl': thumbnailUrl,
        'bannerUrl': bannerUrl,
        'videoUrl': videoUrl,
        'destinationUrl': destinationUrl,
        'buttonText': buttonText,
        'status': status.wireValue,
        'campaignType': campaignType.wireValue,
        'placements': placements.map((p) => p.wireValue).toList(),
        'priority': priority,
        'weight': weight,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        if (advertiserId != null) 'advertiserId': advertiserId,
        'advertiserName': advertiserName,
        'country': country,
        'stateProvince': stateProvince,
        'city': city,
        'language': language,
        'matchType': matchType,
        'ballType': ballType,
        if (tournamentId != null) 'tournamentId': tournamentId,
        'featured': featured,
        'impressions': impressions,
        'clicks': clicks,
        'estimatedRevenue': estimatedRevenue,
        if (homePromotionId != null) 'homePromotionId': homePromotionId,
        'createdByUid': createdByUid,
        'createdByEmail': createdByEmail,
        if (organizationId != null) 'organizationId': organizationId,
        'rejectionReason': rejectionReason,
        'updatedAt': DateTime.now().toIso8601String(),
        if (forCreate) 'createdAt': DateTime.now().toIso8601String(),
      };

  ManagedAdCampaign copyWith({
    String? id,
    String? title,
    String? description,
    String? campaignName,
    ManagedAdMediaType? mediaType,
    String? thumbnailUrl,
    String? bannerUrl,
    String? videoUrl,
    String? destinationUrl,
    String? buttonText,
    ManagedAdStatus? status,
    ManagedAdCampaignType? campaignType,
    Set<ManagedAdPlacement>? placements,
    int? priority,
    int? weight,
    DateTime? startDate,
    DateTime? endDate,
    String? advertiserId,
    String? advertiserName,
    String? country,
    String? stateProvince,
    String? city,
    String? language,
    String? matchType,
    String? ballType,
    String? tournamentId,
    bool? featured,
    int? impressions,
    int? clicks,
    double? estimatedRevenue,
    String? homePromotionId,
    String? rejectionReason,
  }) {
    return ManagedAdCampaign(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      campaignName: campaignName ?? this.campaignName,
      mediaType: mediaType ?? this.mediaType,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      destinationUrl: destinationUrl ?? this.destinationUrl,
      buttonText: buttonText ?? this.buttonText,
      status: status ?? this.status,
      campaignType: campaignType ?? this.campaignType,
      placements: placements ?? this.placements,
      priority: priority ?? this.priority,
      weight: weight ?? this.weight,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      advertiserId: advertiserId ?? this.advertiserId,
      advertiserName: advertiserName ?? this.advertiserName,
      country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      city: city ?? this.city,
      language: language ?? this.language,
      matchType: matchType ?? this.matchType,
      ballType: ballType ?? this.ballType,
      tournamentId: tournamentId ?? this.tournamentId,
      featured: featured ?? this.featured,
      impressions: impressions ?? this.impressions,
      clicks: clicks ?? this.clicks,
      estimatedRevenue: estimatedRevenue ?? this.estimatedRevenue,
      homePromotionId: homePromotionId ?? this.homePromotionId,
      createdByUid: createdByUid,
      createdByEmail: createdByEmail,
      organizationId: organizationId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  @override
  List<Object?> get props => [id, status, updatedAt, title];
}

class ManagedAdvertiser extends Equatable {
  const ManagedAdvertiser({
    required this.id,
    required this.companyName,
    this.logoUrl = '',
    this.contactPerson = '',
    this.email = '',
    this.phone = '',
    this.website = '',
    this.activeAds = 0,
    this.campaignCount = 0,
    this.estimatedRevenue = 0,
    this.organizationId,
    this.createdAt,
  });

  final String id;
  final String companyName;
  final String logoUrl;
  final String contactPerson;
  final String email;
  final String phone;
  final String website;
  final int activeAds;
  final int campaignCount;
  final double estimatedRevenue;
  final String? organizationId;
  final DateTime? createdAt;

  factory ManagedAdvertiser.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    return ManagedAdvertiser(
      id: id,
      companyName: map['companyName'] as String? ?? '',
      logoUrl: map['logoUrl'] as String? ?? '',
      contactPerson: map['contactPerson'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      website: map['website'] as String? ?? '',
      activeAds: (map['activeAds'] as num?)?.toInt() ?? 0,
      campaignCount: (map['campaignCount'] as num?)?.toInt() ?? 0,
      estimatedRevenue: (map['estimatedRevenue'] as num?)?.toDouble() ?? 0,
      organizationId: map['organizationId'] as String?,
      createdAt: ManagedAdCampaign._parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap({bool forCreate = false}) => {
        'companyName': companyName,
        'logoUrl': logoUrl,
        'contactPerson': contactPerson,
        'email': email,
        'phone': phone,
        'website': website,
        'activeAds': activeAds,
        'campaignCount': campaignCount,
        'estimatedRevenue': estimatedRevenue,
        if (organizationId != null) 'organizationId': organizationId,
        'updatedAt': DateTime.now().toIso8601String(),
        if (forCreate) 'createdAt': DateTime.now().toIso8601String(),
      };

  @override
  List<Object?> get props => [id, companyName];
}

class ManagedSponsoredContent extends Equatable {
  const ManagedSponsoredContent({
    required this.id,
    required this.entityType,
    required this.entityId,
    this.entityLabel = '',
    this.sponsorName = '',
    this.campaignId,
    this.campaignName = '',
    this.startDate,
    this.endDate,
    this.priority = 0,
    this.featuredBadge = true,
    this.status = ManagedAdStatus.active,
    this.organizationId,
    this.createdAt,
  });

  final String id;
  final ManagedSponsoredEntityType entityType;
  final String entityId;
  final String entityLabel;
  final String sponsorName;
  final String? campaignId;
  final String campaignName;
  final DateTime? startDate;
  final DateTime? endDate;
  final int priority;
  final bool featuredBadge;
  final ManagedAdStatus status;
  final String? organizationId;
  final DateTime? createdAt;

  factory ManagedSponsoredContent.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    return ManagedSponsoredContent(
      id: id,
      entityType:
          ManagedSponsoredEntityType.parse(map['entityType'] as String?),
      entityId: map['entityId'] as String? ?? '',
      entityLabel: map['entityLabel'] as String? ?? '',
      sponsorName: map['sponsorName'] as String? ?? '',
      campaignId: map['campaignId'] as String?,
      campaignName: map['campaignName'] as String? ?? '',
      startDate: ManagedAdCampaign._parseDate(map['startDate']),
      endDate: ManagedAdCampaign._parseDate(map['endDate']),
      priority: (map['priority'] as num?)?.toInt() ?? 0,
      featuredBadge: map['featuredBadge'] as bool? ?? true,
      status: ManagedAdStatus.parse(map['status'] as String?),
      organizationId: map['organizationId'] as String?,
      createdAt: ManagedAdCampaign._parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap({bool forCreate = false}) => {
        'entityType': entityType.wireValue,
        'entityId': entityId,
        'entityLabel': entityLabel,
        'sponsorName': sponsorName,
        if (campaignId != null) 'campaignId': campaignId,
        'campaignName': campaignName,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        'priority': priority,
        'featuredBadge': featuredBadge,
        'status': status.wireValue,
        if (organizationId != null) 'organizationId': organizationId,
        'updatedAt': DateTime.now().toIso8601String(),
        if (forCreate) 'createdAt': DateTime.now().toIso8601String(),
      };

  @override
  List<Object?> get props => [id, entityType, entityId];
}

/// Admin mirror of AdMob placement settings. Does not alter mobile AdMobConfig.
class ManagedAdmobPlacementConfig extends Equatable {
  const ManagedAdmobPlacementConfig({
    required this.format,
    this.enabled = true,
    this.androidUnitId = '',
    this.iosUnitId = '',
    this.refreshRateSeconds = 60,
    this.frequencyCap = 0,
  });

  final ManagedAdmobFormat format;
  final bool enabled;
  final String androidUnitId;
  final String iosUnitId;
  final int refreshRateSeconds;
  final int frequencyCap;

  Map<String, dynamic> toMap() => {
        'format': format.wireValue,
        'enabled': enabled,
        'androidUnitId': androidUnitId,
        'iosUnitId': iosUnitId,
        'refreshRateSeconds': refreshRateSeconds,
        'frequencyCap': frequencyCap,
      };

  factory ManagedAdmobPlacementConfig.fromMap(Map<String, dynamic> map) {
    return ManagedAdmobPlacementConfig(
      format: ManagedAdmobFormat.values.firstWhere(
        (f) => f.name == map['format'],
        orElse: () => ManagedAdmobFormat.banner,
      ),
      enabled: map['enabled'] as bool? ?? true,
      androidUnitId: map['androidUnitId'] as String? ?? '',
      iosUnitId: map['iosUnitId'] as String? ?? '',
      refreshRateSeconds: (map['refreshRateSeconds'] as num?)?.toInt() ?? 60,
      frequencyCap: (map['frequencyCap'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [format, enabled, androidUnitId, iosUnitId];
}

class ManagedAdmobConfig extends Equatable {
  const ManagedAdmobConfig({
    this.testMode = true,
    this.placements = const [],
    this.updatedAt,
    this.updatedBy = '',
  });

  final bool testMode;
  final List<ManagedAdmobPlacementConfig> placements;
  final DateTime? updatedAt;
  final String updatedBy;

  factory ManagedAdmobConfig.defaults() {
    return ManagedAdmobConfig(
      testMode: true,
      placements: [
        for (final f in ManagedAdmobFormat.values)
          ManagedAdmobPlacementConfig(
            format: f,
            enabled: f == ManagedAdmobFormat.banner,
          ),
      ],
    );
  }

  factory ManagedAdmobConfig.fromFirestore(Map<String, dynamic> map) {
    final raw = map['placements'];
    final list = <ManagedAdmobPlacementConfig>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          list.add(
            ManagedAdmobPlacementConfig.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }
    if (list.isEmpty) return ManagedAdmobConfig.defaults();
    return ManagedAdmobConfig(
      testMode: map['testMode'] as bool? ?? true,
      placements: list,
      updatedAt: ManagedAdCampaign._parseDate(map['updatedAt']),
      updatedBy: map['updatedBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestoreMap({required String updatedBy}) => {
        'testMode': testMode,
        'placements': placements.map((p) => p.toMap()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
        'updatedBy': updatedBy,
        // Never store publisher secrets / OAuth here.
      };

  @override
  List<Object?> get props => [testMode, placements, updatedAt];
}

class AdsSummaryStats {
  const AdsSummaryStats({
    this.activeCampaigns = 0,
    this.scheduledCampaigns = 0,
    this.totalAds = 0,
    this.sponsoredTournaments = 0,
    this.sponsoredTeams = 0,
    this.sponsoredCommunityPosts = 0,
    this.totalImpressions = 0,
    this.estimatedRevenue = 0,
  });

  final int activeCampaigns;
  final int scheduledCampaigns;
  final int totalAds;
  final int sponsoredTournaments;
  final int sponsoredTeams;
  final int sponsoredCommunityPosts;
  final int totalImpressions;
  final double estimatedRevenue;
}

class AdsPageResult {
  const AdsPageResult({
    required this.items,
    required this.hasMore,
    this.cursor,
  });

  final List<ManagedAdCampaign> items;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
}
