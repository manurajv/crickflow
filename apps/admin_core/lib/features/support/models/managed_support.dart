import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'support_enums.dart';

DateTime? _ts(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

List<String> _stringList(dynamic v) {
  if (v is! List) return const [];
  return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
}

class ManagedSupportTicket extends Equatable {
  const ManagedSupportTicket({
    required this.id,
    required this.ticketNumber,
    required this.subject,
    this.description = '',
    this.kind = SupportTicketKind.support,
    this.category = SupportTicketCategory.support,
    this.priority = SupportTicketPriority.medium,
    this.status = SupportTicketStatus.open,
    this.createdByUid = '',
    this.createdByEmail = '',
    this.createdByName = '',
    this.assignedToUid,
    this.assignedToEmail,
    this.assignedToName,
    this.organizationId,
    this.organizationName,
    this.attachments = const [],
    this.screenshots = const [],
    this.deviceInfo = '',
    this.appVersion = '',
    this.os = '',
    this.platform = '',
    this.country = '',
    this.stateProvince = '',
    this.city = '',
    this.playerId = '',
    this.phone = '',
    this.stepsToReproduce = '',
    this.logs = '',
    this.severity = SupportTicketPriority.medium,
    this.featureStatus = FeatureRequestStatus.submitted,
    this.votes = 0,
    this.rating,
    this.createdAt,
    this.updatedAt,
    this.firstRespondedAt,
    this.resolvedAt,
    this.closedAt,
    this.responseTimeMs,
    this.resolutionTimeMs,
    this.slaDueAt,
    this.isOverdue = false,
    this.channel = 'admin',
  });

  final String id;
  final String ticketNumber;
  final String subject;
  final String description;
  final SupportTicketKind kind;
  final SupportTicketCategory category;
  final SupportTicketPriority priority;
  final SupportTicketStatus status;
  final String createdByUid;
  final String createdByEmail;
  final String createdByName;
  final String? assignedToUid;
  final String? assignedToEmail;
  final String? assignedToName;
  final String? organizationId;
  final String? organizationName;
  final List<String> attachments;
  final List<String> screenshots;
  final String deviceInfo;
  final String appVersion;
  final String os;
  final String platform;
  final String country;
  final String stateProvince;
  final String city;
  final String playerId;
  final String phone;
  final String stepsToReproduce;
  final String logs;
  final SupportTicketPriority severity;
  final FeatureRequestStatus featureStatus;
  final int votes;
  final int? rating;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? firstRespondedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final int? responseTimeMs;
  final int? resolutionTimeMs;
  final DateTime? slaDueAt;
  final bool isOverdue;
  final String channel;

  bool get isAssigned =>
      assignedToUid != null && assignedToUid!.trim().isNotEmpty;

  factory ManagedSupportTicket.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final priority = SupportTicketPriority.parse(map['priority'] as String?);
    final createdAt = _ts(map['createdAt']);
    final slaDueAt = _ts(map['slaDueAt']);
    final overdue = slaDueAt != null &&
        DateTime.now().isAfter(slaDueAt) &&
        !SupportTicketStatus.parse(map['status'] as String?).isTerminal;

    return ManagedSupportTicket(
      id: id,
      ticketNumber: (map['ticketNumber'] as String?) ?? id,
      subject: (map['subject'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      kind: SupportTicketKind.parse(map['kind'] as String?),
      category: SupportTicketCategory.parse(map['category'] as String?),
      priority: priority,
      status: SupportTicketStatus.parse(map['status'] as String?),
      createdByUid: (map['createdByUid'] as String?) ?? '',
      createdByEmail: (map['createdByEmail'] as String?) ?? '',
      createdByName: (map['createdByName'] as String?) ?? '',
      assignedToUid: map['assignedToUid'] as String?,
      assignedToEmail: map['assignedToEmail'] as String?,
      assignedToName: map['assignedToName'] as String?,
      organizationId: map['organizationId'] as String?,
      organizationName: map['organizationName'] as String?,
      attachments: _stringList(map['attachments']),
      screenshots: _stringList(map['screenshots']),
      deviceInfo: (map['deviceInfo'] as String?) ?? '',
      appVersion: (map['appVersion'] as String?) ?? '',
      os: (map['os'] as String?) ?? '',
      platform: (map['platform'] as String?) ?? '',
      country: (map['country'] as String?) ?? '',
      stateProvince: (map['stateProvince'] as String?) ??
          (map['state'] as String?) ??
          '',
      city: (map['city'] as String?) ?? '',
      playerId: (map['playerId'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      stepsToReproduce: (map['stepsToReproduce'] as String?) ?? '',
      logs: (map['logs'] as String?) ?? '',
      severity: SupportTicketPriority.parse(
        (map['severity'] as String?) ?? priority.wireValue,
      ),
      featureStatus:
          FeatureRequestStatus.parse(map['featureStatus'] as String?),
      votes: (map['votes'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toInt(),
      createdAt: createdAt,
      updatedAt: _ts(map['updatedAt']) ?? createdAt,
      firstRespondedAt: _ts(map['firstRespondedAt']),
      resolvedAt: _ts(map['resolvedAt']),
      closedAt: _ts(map['closedAt']),
      responseTimeMs: (map['responseTimeMs'] as num?)?.toInt(),
      resolutionTimeMs: (map['resolutionTimeMs'] as num?)?.toInt(),
      slaDueAt: slaDueAt,
      isOverdue: overdue || (map['isOverdue'] as bool? ?? false),
      channel: (map['channel'] as String?) ?? 'admin',
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'ticketNumber': ticketNumber,
        'subject': subject,
        'description': description,
        'kind': kind.wireValue,
        'category': category.wireValue,
        'priority': priority.wireValue,
        'status': status.wireValue,
        'createdByUid': createdByUid,
        'createdByEmail': createdByEmail,
        'createdByName': createdByName,
        if (assignedToUid != null) 'assignedToUid': assignedToUid,
        if (assignedToEmail != null) 'assignedToEmail': assignedToEmail,
        if (assignedToName != null) 'assignedToName': assignedToName,
        if (organizationId != null) 'organizationId': organizationId,
        if (organizationName != null) 'organizationName': organizationName,
        'attachments': attachments,
        'screenshots': screenshots,
        'deviceInfo': deviceInfo,
        'appVersion': appVersion,
        'os': os,
        'platform': platform,
        'country': country,
        'stateProvince': stateProvince,
        'city': city,
        'playerId': playerId,
        'phone': phone,
        'stepsToReproduce': stepsToReproduce,
        'logs': logs,
        'severity': severity.wireValue,
        'featureStatus': featureStatus.wireValue,
        'votes': votes,
        if (rating != null) 'rating': rating,
        'channel': channel,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'slaDueAt': Timestamp.fromDate(
          DateTime.now().add(_slaDuration(priority)),
        ),
      };

  static Duration _slaDuration(SupportTicketPriority p) => switch (p) {
        SupportTicketPriority.critical => const Duration(hours: 4),
        SupportTicketPriority.high => const Duration(hours: 12),
        SupportTicketPriority.medium => const Duration(hours: 48),
        SupportTicketPriority.low => const Duration(days: 5),
      };

  @override
  List<Object?> get props => [id, status, priority, updatedAt];
}

class SupportMessage extends Equatable {
  const SupportMessage({
    required this.id,
    required this.ticketId,
    required this.body,
    this.authorUid = '',
    this.authorEmail = '',
    this.authorName = '',
    this.authorType = SupportMessageAuthorType.agent,
    this.visibility = SupportMessageVisibility.public,
    this.attachments = const [],
    this.readByUser = false,
    this.readByAgent = false,
    this.createdAt,
  });

  final String id;
  final String ticketId;
  final String body;
  final String authorUid;
  final String authorEmail;
  final String authorName;
  final SupportMessageAuthorType authorType;
  final SupportMessageVisibility visibility;
  final List<String> attachments;
  final bool readByUser;
  final bool readByAgent;
  final DateTime? createdAt;

  bool get isInternal => visibility == SupportMessageVisibility.internal;

  factory SupportMessage.fromMap(
    String id,
    String ticketId,
    Map<String, dynamic> map,
  ) {
    return SupportMessage(
      id: id,
      ticketId: ticketId,
      body: (map['body'] as String?) ?? '',
      authorUid: (map['authorUid'] as String?) ?? '',
      authorEmail: (map['authorEmail'] as String?) ?? '',
      authorName: (map['authorName'] as String?) ?? '',
      authorType: SupportMessageAuthorType.parse(map['authorType'] as String?),
      visibility:
          SupportMessageVisibility.parse(map['visibility'] as String?),
      attachments: _stringList(map['attachments']),
      readByUser: map['readByUser'] as bool? ?? false,
      readByAgent: map['readByAgent'] as bool? ?? true,
      createdAt: _ts(map['createdAt']),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'body': body,
        'authorUid': authorUid,
        'authorEmail': authorEmail,
        'authorName': authorName,
        'authorType': authorType.wireValue,
        'visibility': visibility.wireValue,
        'attachments': attachments,
        'readByUser': readByUser,
        'readByAgent': readByAgent,
        'createdAt': FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [id, body, visibility, createdAt];
}

class SupportKbArticle extends Equatable {
  const SupportKbArticle({
    required this.id,
    required this.title,
    this.body = '',
    this.category = 'General',
    this.status = SupportContentStatus.draft,
    this.keywords = const [],
    this.updatedAt,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final SupportContentStatus status;
  final List<String> keywords;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  factory SupportKbArticle.fromMap(String id, Map<String, dynamic> map) {
    return SupportKbArticle(
      id: id,
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'General',
      status: SupportContentStatus.parse(map['status'] as String?),
      keywords: _stringList(map['keywords']),
      updatedAt: _ts(map['updatedAt']),
      createdAt: _ts(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap({bool creating = false}) => {
        'title': title,
        'body': body,
        'category': category,
        'status': status.wireValue,
        'keywords': keywords,
        'updatedAt': FieldValue.serverTimestamp(),
        if (creating) 'createdAt': FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [id, title, status];
}

class SupportFaqItem extends Equatable {
  const SupportFaqItem({
    required this.id,
    required this.question,
    this.answer = '',
    this.category = 'General',
    this.status = SupportContentStatus.draft,
    this.keywords = const [],
    this.updatedAt,
  });

  final String id;
  final String question;
  final String answer;
  final String category;
  final SupportContentStatus status;
  final List<String> keywords;
  final DateTime? updatedAt;

  factory SupportFaqItem.fromMap(String id, Map<String, dynamic> map) {
    return SupportFaqItem(
      id: id,
      question: (map['question'] as String?) ?? '',
      answer: (map['answer'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'General',
      status: SupportContentStatus.parse(map['status'] as String?),
      keywords: _stringList(map['keywords']),
      updatedAt: _ts(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool creating = false}) => {
        'question': question,
        'answer': answer,
        'category': category,
        'status': status.wireValue,
        'keywords': keywords,
        'updatedAt': FieldValue.serverTimestamp(),
        if (creating) 'createdAt': FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [id, question, status];
}

class SupportAnnouncement extends Equatable {
  const SupportAnnouncement({
    required this.id,
    required this.title,
    this.body = '',
    this.type = SupportAnnouncementType.general,
    this.status = SupportContentStatus.draft,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final SupportAnnouncementType type;
  final SupportContentStatus status;
  final DateTime? updatedAt;

  factory SupportAnnouncement.fromMap(String id, Map<String, dynamic> map) {
    return SupportAnnouncement(
      id: id,
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      type: SupportAnnouncementType.parse(map['type'] as String?),
      status: SupportContentStatus.parse(map['status'] as String?),
      updatedAt: _ts(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool creating = false}) => {
        'title': title,
        'body': body,
        'type': type.wireValue,
        'status': status.wireValue,
        'updatedAt': FieldValue.serverTimestamp(),
        if (creating) 'createdAt': FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [id, title, type, status];
}

class SupportSummaryStats extends Equatable {
  const SupportSummaryStats({
    this.open = 0,
    this.pending = 0,
    this.waitingForUser = 0,
    this.resolvedToday = 0,
    this.closed = 0,
    this.highPriority = 0,
    this.avgResponseMins = 0,
    this.avgResolutionMins = 0,
    this.csatAverage = 0,
    this.csatPositive = 0,
    this.csatNeutral = 0,
    this.csatNegative = 0,
    this.overdue = 0,
  });

  final int open;
  final int pending;
  final int waitingForUser;
  final int resolvedToday;
  final int closed;
  final int highPriority;
  final double avgResponseMins;
  final double avgResolutionMins;
  final double csatAverage;
  final int csatPositive;
  final int csatNeutral;
  final int csatNegative;
  final int overdue;

  @override
  List<Object?> get props => [open, pending, resolvedToday, csatAverage];
}

class SupportReportSnapshot extends Equatable {
  const SupportReportSnapshot({
    this.commonIssues = const [],
    this.agentActivity = const [],
    this.categoryDistribution = const [],
    this.trendPoints = const [],
  });

  final List<(String, int)> commonIssues;
  final List<(String, int)> agentActivity;
  final List<(String, int)> categoryDistribution;
  final List<double> trendPoints;

  @override
  List<Object?> get props => [commonIssues, agentActivity];
}

class SupportPageResult {
  const SupportPageResult({
    required this.items,
    required this.hasMore,
    this.lastDoc,
  });

  final List<ManagedSupportTicket> items;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
}
