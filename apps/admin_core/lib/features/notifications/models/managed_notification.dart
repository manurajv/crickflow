import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'notification_enums.dart';

/// Admin-managed notification / campaign document.
///
/// Stored in `admin_notification_campaigns`. Never stores FCM tokens.
class ManagedNotificationCampaign extends Equatable {
  const ManagedNotificationCampaign({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.body = '',
    this.imageUrl = '',
    this.bannerUrl = '',
    this.actionButtonText = '',
    this.deepLink = '',
    this.type = ManagedNotificationType.system,
    this.status = ManagedNotificationStatus.draft,
    this.priority = ManagedNotificationPriority.normal,
    this.sound = ManagedNotificationSound.defaultSound,
    this.audience = ManagedNotificationAudience.everyone,
    this.audienceIds = const [],
    this.audienceLabel = '',
    this.country = '',
    this.stateProvince = '',
    this.city = '',
    this.platforms = const {
      ManagedPlatformTarget.android,
      ManagedPlatformTarget.ios,
    },
    this.scheduleMode = ManagedScheduleMode.immediate,
    this.scheduledAt,
    this.recurrence = ManagedRecurrence.none,
    this.timezone = 'UTC',
    this.campaignName = '',
    this.isCampaign = false,
    this.campaignStart,
    this.campaignEnd,
    this.sentCount = 0,
    this.deliveredCount = 0,
    this.openedCount = 0,
    this.clickedCount = 0,
    this.failedCount = 0,
    this.recipientCount = 0,
    this.createdByUid = '',
    this.createdByEmail = '',
    this.organizationId,
    this.tournamentId,
    this.matchId,
    this.teamId,
    this.templateId,
    this.createdAt,
    this.updatedAt,
    this.sentAt,
    this.deliveryNote = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final String body;
  final String imageUrl;
  final String bannerUrl;
  final String actionButtonText;
  final String deepLink;
  final ManagedNotificationType type;
  final ManagedNotificationStatus status;
  final ManagedNotificationPriority priority;
  final ManagedNotificationSound sound;
  final ManagedNotificationAudience audience;
  final List<String> audienceIds;
  final String audienceLabel;
  final String country;
  final String stateProvince;
  final String city;
  final Set<ManagedPlatformTarget> platforms;
  final ManagedScheduleMode scheduleMode;
  final DateTime? scheduledAt;
  final ManagedRecurrence recurrence;
  final String timezone;
  final String campaignName;
  final bool isCampaign;
  final DateTime? campaignStart;
  final DateTime? campaignEnd;
  final int sentCount;
  final int deliveredCount;
  final int openedCount;
  final int clickedCount;
  final int failedCount;
  final int recipientCount;
  final String createdByUid;
  final String createdByEmail;
  final String? organizationId;
  final String? tournamentId;
  final String? matchId;
  final String? teamId;
  final String? templateId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? sentAt;
  final String deliveryNote;

  double get deliveryRate {
    if (sentCount <= 0) return 0;
    return deliveredCount / sentCount;
  }

  double get openRate {
    if (deliveredCount <= 0) return 0;
    return openedCount / deliveredCount;
  }

  double get clickRate {
    if (deliveredCount <= 0) return 0;
    return clickedCount / deliveredCount;
  }

  String get displayTitle =>
      title.trim().isNotEmpty ? title.trim() : (campaignName.trim().isNotEmpty ? campaignName.trim() : 'Untitled');

  factory ManagedNotificationCampaign.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final platformsRaw = map['platforms'];
    final platforms = <ManagedPlatformTarget>{};
    if (platformsRaw is List) {
      for (final p in platformsRaw) {
        final name = p.toString();
        for (final v in ManagedPlatformTarget.values) {
          if (v.name == name) platforms.add(v);
        }
      }
    }
    if (platforms.isEmpty) {
      platforms.addAll([
        ManagedPlatformTarget.android,
        ManagedPlatformTarget.ios,
      ]);
    }

    return ManagedNotificationCampaign(
      id: id,
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      body: map['body'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      bannerUrl: map['bannerUrl'] as String? ?? '',
      actionButtonText: map['actionButtonText'] as String? ?? '',
      deepLink: map['deepLink'] as String? ?? '',
      type: ManagedNotificationType.parse(map['type'] as String?),
      status: ManagedNotificationStatus.parse(map['status'] as String?),
      priority: ManagedNotificationPriority.parse(map['priority'] as String?),
      sound: ManagedNotificationSound.parse(map['sound'] as String?),
      audience: ManagedNotificationAudience.parse(map['audience'] as String?),
      audienceIds: List<String>.from(map['audienceIds'] as List? ?? const []),
      audienceLabel: map['audienceLabel'] as String? ?? '',
      country: map['country'] as String? ?? '',
      stateProvince: map['stateProvince'] as String? ?? map['state'] as String? ?? '',
      city: map['city'] as String? ?? '',
      platforms: platforms,
      scheduleMode: ManagedScheduleMode.parse(map['scheduleMode'] as String?),
      scheduledAt: _parseDate(map['scheduledAt']),
      recurrence: ManagedRecurrence.parse(map['recurrence'] as String?),
      timezone: map['timezone'] as String? ?? 'UTC',
      campaignName: map['campaignName'] as String? ?? '',
      isCampaign: map['isCampaign'] as bool? ?? false,
      campaignStart: _parseDate(map['campaignStart']),
      campaignEnd: _parseDate(map['campaignEnd']),
      sentCount: (map['sentCount'] as num?)?.toInt() ?? 0,
      deliveredCount: (map['deliveredCount'] as num?)?.toInt() ?? 0,
      openedCount: (map['openedCount'] as num?)?.toInt() ?? 0,
      clickedCount: (map['clickedCount'] as num?)?.toInt() ?? 0,
      failedCount: (map['failedCount'] as num?)?.toInt() ?? 0,
      recipientCount: (map['recipientCount'] as num?)?.toInt() ?? 0,
      createdByUid: map['createdByUid'] as String? ?? '',
      createdByEmail: map['createdByEmail'] as String? ?? '',
      organizationId: map['organizationId'] as String?,
      tournamentId: map['tournamentId'] as String?,
      matchId: map['matchId'] as String?,
      teamId: map['teamId'] as String?,
      templateId: map['templateId'] as String?,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      sentAt: _parseDate(map['sentAt']),
      deliveryNote: map['deliveryNote'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestoreMap({bool forCreate = false}) {
    return {
      'title': title,
      'subtitle': subtitle,
      'body': body,
      'imageUrl': imageUrl,
      'bannerUrl': bannerUrl,
      'actionButtonText': actionButtonText,
      'deepLink': deepLink,
      'type': type.wireValue,
      'status': status.wireValue,
      'priority': priority.wireValue,
      'sound': sound.wireValue,
      'audience': audience.wireValue,
      'audienceIds': audienceIds,
      'audienceLabel': audienceLabel,
      'country': country,
      'stateProvince': stateProvince,
      'city': city,
      'platforms': platforms.map((p) => p.wireValue).toList(),
      'scheduleMode': scheduleMode.wireValue,
      if (scheduledAt != null) 'scheduledAt': scheduledAt!.toIso8601String(),
      'recurrence': recurrence.wireValue,
      'timezone': timezone,
      'campaignName': campaignName,
      'isCampaign': isCampaign,
      if (campaignStart != null)
        'campaignStart': campaignStart!.toIso8601String(),
      if (campaignEnd != null) 'campaignEnd': campaignEnd!.toIso8601String(),
      'sentCount': sentCount,
      'deliveredCount': deliveredCount,
      'openedCount': openedCount,
      'clickedCount': clickedCount,
      'failedCount': failedCount,
      'recipientCount': recipientCount,
      'createdByUid': createdByUid,
      'createdByEmail': createdByEmail,
      if (organizationId != null) 'organizationId': organizationId,
      if (tournamentId != null) 'tournamentId': tournamentId,
      if (matchId != null) 'matchId': matchId,
      if (teamId != null) 'teamId': teamId,
      if (templateId != null) 'templateId': templateId,
      'deliveryNote': deliveryNote,
      'updatedAt': DateTime.now().toIso8601String(),
      if (forCreate) 'createdAt': DateTime.now().toIso8601String(),
      if (sentAt != null) 'sentAt': sentAt!.toIso8601String(),
    };
  }

  ManagedNotificationCampaign copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? body,
    String? imageUrl,
    String? bannerUrl,
    String? actionButtonText,
    String? deepLink,
    ManagedNotificationType? type,
    ManagedNotificationStatus? status,
    ManagedNotificationPriority? priority,
    ManagedNotificationSound? sound,
    ManagedNotificationAudience? audience,
    List<String>? audienceIds,
    String? audienceLabel,
    String? country,
    String? stateProvince,
    String? city,
    Set<ManagedPlatformTarget>? platforms,
    ManagedScheduleMode? scheduleMode,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
    ManagedRecurrence? recurrence,
    String? timezone,
    String? campaignName,
    bool? isCampaign,
    DateTime? campaignStart,
    DateTime? campaignEnd,
    int? sentCount,
    int? deliveredCount,
    int? openedCount,
    int? clickedCount,
    int? failedCount,
    int? recipientCount,
    String? deliveryNote,
    DateTime? sentAt,
  }) {
    return ManagedNotificationCampaign(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      actionButtonText: actionButtonText ?? this.actionButtonText,
      deepLink: deepLink ?? this.deepLink,
      type: type ?? this.type,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      sound: sound ?? this.sound,
      audience: audience ?? this.audience,
      audienceIds: audienceIds ?? this.audienceIds,
      audienceLabel: audienceLabel ?? this.audienceLabel,
      country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      city: city ?? this.city,
      platforms: platforms ?? this.platforms,
      scheduleMode: scheduleMode ?? this.scheduleMode,
      scheduledAt:
          clearScheduledAt ? null : (scheduledAt ?? this.scheduledAt),
      recurrence: recurrence ?? this.recurrence,
      timezone: timezone ?? this.timezone,
      campaignName: campaignName ?? this.campaignName,
      isCampaign: isCampaign ?? this.isCampaign,
      campaignStart: campaignStart ?? this.campaignStart,
      campaignEnd: campaignEnd ?? this.campaignEnd,
      sentCount: sentCount ?? this.sentCount,
      deliveredCount: deliveredCount ?? this.deliveredCount,
      openedCount: openedCount ?? this.openedCount,
      clickedCount: clickedCount ?? this.clickedCount,
      failedCount: failedCount ?? this.failedCount,
      recipientCount: recipientCount ?? this.recipientCount,
      createdByUid: createdByUid,
      createdByEmail: createdByEmail,
      organizationId: organizationId,
      tournamentId: tournamentId,
      matchId: matchId,
      teamId: teamId,
      templateId: templateId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      sentAt: sentAt ?? this.sentAt,
      deliveryNote: deliveryNote ?? this.deliveryNote,
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

class ManagedNotificationTemplate extends Equatable {
  const ManagedNotificationTemplate({
    required this.id,
    required this.name,
    this.title = '',
    this.body = '',
    this.type = ManagedNotificationType.system,
    this.deepLink = '',
    this.createdAt,
    this.updatedAt,
    this.organizationId,
  });

  final String id;
  final String name;
  final String title;
  final String body;
  final ManagedNotificationType type;
  final String deepLink;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? organizationId;

  factory ManagedNotificationTemplate.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    return ManagedNotificationTemplate(
      id: id,
      name: map['name'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: ManagedNotificationType.parse(map['type'] as String?),
      deepLink: map['deepLink'] as String? ?? '',
      createdAt: ManagedNotificationCampaign._parseDate(map['createdAt']),
      updatedAt: ManagedNotificationCampaign._parseDate(map['updatedAt']),
      organizationId: map['organizationId'] as String?,
    );
  }

  Map<String, dynamic> toFirestoreMap({bool forCreate = false}) => {
        'name': name,
        'title': title,
        'body': body,
        'type': type.wireValue,
        'deepLink': deepLink,
        if (organizationId != null) 'organizationId': organizationId,
        'updatedAt': DateTime.now().toIso8601String(),
        if (forCreate) 'createdAt': DateTime.now().toIso8601String(),
      };

  @override
  List<Object?> get props => [id, name, updatedAt];
}

class ManagedNotificationSegment extends Equatable {
  const ManagedNotificationSegment({
    required this.id,
    required this.name,
    this.description = '',
    this.audience = ManagedNotificationAudience.everyone,
    this.filters = const {},
    this.estimatedCount = 0,
    this.createdAt,
    this.organizationId,
  });

  final String id;
  final String name;
  final String description;
  final ManagedNotificationAudience audience;
  final Map<String, dynamic> filters;
  final int estimatedCount;
  final DateTime? createdAt;
  final String? organizationId;

  factory ManagedNotificationSegment.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    return ManagedNotificationSegment(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      audience: ManagedNotificationAudience.parse(map['audience'] as String?),
      filters: Map<String, dynamic>.from(map['filters'] as Map? ?? const {}),
      estimatedCount: (map['estimatedCount'] as num?)?.toInt() ?? 0,
      createdAt: ManagedNotificationCampaign._parseDate(map['createdAt']),
      organizationId: map['organizationId'] as String?,
    );
  }

  Map<String, dynamic> toFirestoreMap({bool forCreate = false}) => {
        'name': name,
        'description': description,
        'audience': audience.wireValue,
        'filters': filters,
        'estimatedCount': estimatedCount,
        if (organizationId != null) 'organizationId': organizationId,
        if (forCreate) 'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  @override
  List<Object?> get props => [id, name];
}

/// Read-only view of a mobile inbox notification (auto / system).
class ManagedAutoNotification extends Equatable {
  const ManagedAutoNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type,
    this.category,
    this.matchId,
    this.tournamentId,
    this.teamId,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final String? type;
  final String? category;
  final String? matchId;
  final String? tournamentId;
  final String? teamId;
  final bool read;
  final DateTime? createdAt;

  factory ManagedAutoNotification.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    return ManagedAutoNotification(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? map['message'] as String? ?? '',
      type: map['type'] as String?,
      category: map['category'] as String?,
      matchId: map['matchId'] as String?,
      tournamentId: map['tournamentId'] as String?,
      teamId: map['teamId'] as String?,
      read: map['read'] as bool? ?? map['isRead'] as bool? ?? false,
      createdAt: ManagedNotificationCampaign._parseDate(map['createdAt']),
    );
  }

  @override
  List<Object?> get props => [id, userId, createdAt];
}

class ManagedAnnouncement extends Equatable {
  const ManagedAnnouncement({
    required this.id,
    required this.title,
    this.description = '',
    this.imageUrl = '',
    this.buttonText = '',
    this.redirectAction = 'none',
    this.redirectUrl = '',
    this.priority = 0,
    this.active = true,
    this.kind = 'announcement',
    this.expiresAt,
    this.createdAt,
    this.organizationId,
  });

  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String buttonText;
  final String redirectAction;
  final String redirectUrl;
  final int priority;
  final bool active;
  final String kind;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final String? organizationId;

  factory ManagedAnnouncement.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    return ManagedAnnouncement(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      buttonText: map['buttonText'] as String? ?? '',
      redirectAction: map['redirectAction'] as String? ?? 'none',
      redirectUrl: map['redirectUrl'] as String? ?? '',
      priority: (map['priority'] as num?)?.toInt() ?? 0,
      active: map['active'] as bool? ?? true,
      kind: map['kind'] as String? ?? 'announcement',
      expiresAt: ManagedNotificationCampaign._parseDate(map['expiresAt']),
      createdAt: ManagedNotificationCampaign._parseDate(map['createdAt']),
      organizationId: map['organizationId'] as String?,
    );
  }

  Map<String, dynamic> toFirestoreMap({bool forCreate = false}) => {
        'kind': kind,
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'buttonText': buttonText,
        'redirectAction': redirectAction,
        'redirectUrl': redirectUrl,
        'priority': priority,
        'active': active,
        if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
        if (organizationId != null) 'organizationId': organizationId,
        if (forCreate) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [id, title, active, priority];
}

class NotificationSummaryStats {
  const NotificationSummaryStats({
    this.sentToday = 0,
    this.scheduled = 0,
    this.delivered = 0,
    this.failed = 0,
    this.openRate = 0,
    this.clickRate = 0,
    this.activeCampaigns = 0,
    this.draftCampaigns = 0,
  });

  final int sentToday;
  final int scheduled;
  final int delivered;
  final int failed;
  final double openRate;
  final double clickRate;
  final int activeCampaigns;
  final int draftCampaigns;
}

class NotificationPageResult {
  const NotificationPageResult({
    required this.items,
    required this.hasMore,
    this.cursor,
  });

  final List<ManagedNotificationCampaign> items;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
}
