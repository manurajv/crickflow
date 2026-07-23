import 'package:equatable/equatable.dart';

import '../../features/discover/domain/opportunity_category.dart';
import '../../features/discover/domain/opportunity_field_schema.dart';
import 'location_model.dart';

/// Cricket opportunity marketplace listing.
class OpportunityPostModel extends Equatable {
  const OpportunityPostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.category,
    required this.title,
    required this.description,
    this.authorPhotoUrl,
    this.authorPlayerId,
    this.authorVerified = false,
    this.location = const LocationModel(),
    this.fields = const {},
    this.tags = const [],
    this.searchText = '',
    this.contactMethods = const [OpportunityContactMethod.chat],
    this.contactPhone = '',
    this.contactWhatsApp = '',
    this.mediaUrls = const [],
    this.status = OpportunityPostStatus.active,
    this.expiryDays = 7,
    this.expiresAt,
    this.viewCount = 0,
    this.shareCount = 0,
    this.saveCount = 0,
    this.applicationCount = 0,
    this.isPinned = false,
    this.isFeatured = false,
    this.isPremium = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String? authorPlayerId;
  final bool authorVerified;
  final OpportunityCategory category;
  final String title;
  final String description;
  final LocationModel location;

  /// Category-specific dynamic fields (string / list values).
  final Map<String, dynamic> fields;
  final List<String> tags;

  /// Lowercased haystack for client/search indexing.
  final String searchText;
  final List<OpportunityContactMethod> contactMethods;
  final String contactPhone;
  final String contactWhatsApp;
  final List<String> mediaUrls;
  final OpportunityPostStatus status;
  final int expiryDays;
  final DateTime? expiresAt;
  final int viewCount;
  final int shareCount;
  final int saveCount;
  final int applicationCount;
  final bool isPinned;
  final bool isFeatured;
  final bool isPremium;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isExpired {
    if (status == OpportunityPostStatus.expired ||
        status == OpportunityPostStatus.removed) {
      return true;
    }
    final exp = expiresAt;
    if (exp == null) return false;
    return DateTime.now().toUtc().isAfter(exp.toUtc());
  }

  bool get isActive => status == OpportunityPostStatus.active && !isExpired;

  String get locationLabel => location.displayLabel;

  DateTime? get eventDate {
    final raw = fields['matchDate'] ?? fields['registrationDeadline'];
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  /// Chips shown on the feed card (from schema `showOnCard` fields).
  List<String> get cardChips {
    final defs = OpportunityFieldSchema.fieldsFor(category);
    final chips = <String>[];
    for (final def in defs) {
      if (!def.showOnCard) continue;
      final value = fields[def.key];
      if (value == null) continue;
      if (value is List) {
        for (final v in value) {
          final s = v.toString().trim();
          if (s.isNotEmpty) chips.add(s);
        }
      } else {
        final s = value.toString().trim();
        if (s.isEmpty || s == 'N/A') continue;
        if (def.type == OpportunityFieldType.yesNo) {
          if (s == 'Yes') chips.add(def.label);
        } else {
          chips.add(s);
        }
      }
    }
    return chips.take(5).toList();
  }

  factory OpportunityPostModel.fromMap(String id, Map<String, dynamic> map) {
    final category = OpportunityCategoryX.tryParse(map['category'] as String?) ??
        OpportunityCategory.findPlayer;
    final methodsRaw = map['contactMethods'];
    final methods = <OpportunityContactMethod>[];
    if (methodsRaw is List) {
      for (final m in methodsRaw) {
        final name = m.toString();
        for (final e in OpportunityContactMethod.values) {
          if (e.name == name) {
            methods.add(e);
            break;
          }
        }
      }
    }
    if (methods.isEmpty) methods.add(OpportunityContactMethod.chat);

    final fieldsRaw = map['fields'];
    final fields = <String, dynamic>{};
    if (fieldsRaw is Map) {
      fieldsRaw.forEach((k, v) => fields[k.toString()] = v);
    }

    final tagsRaw = map['tags'];
    final tags = tagsRaw is List
        ? tagsRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    final mediaRaw = map['mediaUrls'];
    final media = mediaRaw is List
        ? mediaRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    return OpportunityPostModel(
      id: id,
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      authorPhotoUrl: map['authorPhotoUrl'] as String?,
      authorPlayerId: map['authorPlayerId'] as String?,
      authorVerified: map['authorVerified'] as bool? ?? false,
      category: category,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      location: LocationModel.fromMap(map['location'] as Map<String, dynamic>?),
      fields: fields,
      tags: tags,
      searchText: map['searchText'] as String? ?? '',
      contactMethods: methods,
      contactPhone: map['contactPhone'] as String? ?? '',
      contactWhatsApp: map['contactWhatsApp'] as String? ?? '',
      mediaUrls: media,
      status: OpportunityPostStatusX.tryParse(map['status'] as String?) ??
          OpportunityPostStatus.active,
      expiryDays: (map['expiryDays'] as num?)?.toInt() ?? 7,
      expiresAt: DateTime.tryParse(map['expiresAt']?.toString() ?? ''),
      viewCount: (map['viewCount'] as num?)?.toInt() ?? 0,
      shareCount: (map['shareCount'] as num?)?.toInt() ?? 0,
      saveCount: (map['saveCount'] as num?)?.toInt() ?? 0,
      applicationCount: (map['applicationCount'] as num?)?.toInt() ?? 0,
      isPinned: map['isPinned'] as bool? ?? false,
      isFeatured: map['isFeatured'] as bool? ?? false,
      isPremium: map['isPremium'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'authorName': authorName,
        if (authorPhotoUrl != null) 'authorPhotoUrl': authorPhotoUrl,
        if (authorPlayerId != null) 'authorPlayerId': authorPlayerId,
        'authorVerified': authorVerified,
        'category': category.name,
        'title': title,
        'description': description,
        'location': location.toMap(),
        'fields': fields,
        'tags': tags,
        'searchText': searchText,
        'contactMethods': contactMethods.map((e) => e.name).toList(),
        'contactPhone': contactPhone,
        'contactWhatsApp': contactWhatsApp,
        'mediaUrls': mediaUrls,
        'status': status.name,
        'expiryDays': expiryDays,
        if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
        'viewCount': viewCount,
        'shareCount': shareCount,
        'saveCount': saveCount,
        'applicationCount': applicationCount,
        'isPinned': isPinned,
        'isFeatured': isFeatured,
        'isPremium': isPremium,
        if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
      };

  /// Builds searchable text from title, description, location, and fields.
  static String buildSearchText({
    required String title,
    required String description,
    required LocationModel location,
    required Map<String, dynamic> fields,
    required String authorName,
  }) {
    final parts = <String>[
      title,
      description,
      authorName,
      location.displayLabel,
      location.city,
      location.district,
      location.stateProvince,
      location.country,
    ];
    fields.forEach((key, value) {
      parts.add(key);
      if (value is List) {
        parts.addAll(value.map((e) => e.toString()));
      } else if (value != null) {
        parts.add(value.toString());
      }
    });
    return parts
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .join(' ');
  }

  OpportunityPostModel copyWith({
    String? title,
    String? description,
    Map<String, dynamic>? fields,
    OpportunityPostStatus? status,
    bool? isPinned,
    bool? isFeatured,
    int? viewCount,
    int? shareCount,
    int? saveCount,
  }) {
    return OpportunityPostModel(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl,
      authorPlayerId: authorPlayerId,
      authorVerified: authorVerified,
      category: category,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location,
      fields: fields ?? this.fields,
      tags: tags,
      searchText: searchText,
      contactMethods: contactMethods,
      contactPhone: contactPhone,
      contactWhatsApp: contactWhatsApp,
      mediaUrls: mediaUrls,
      status: status ?? this.status,
      expiryDays: expiryDays,
      expiresAt: expiresAt,
      viewCount: viewCount ?? this.viewCount,
      shareCount: shareCount ?? this.shareCount,
      saveCount: saveCount ?? this.saveCount,
      applicationCount: applicationCount,
      isPinned: isPinned ?? this.isPinned,
      isFeatured: isFeatured ?? this.isFeatured,
      isPremium: isPremium,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, updatedAt, status, viewCount, saveCount];
}

enum OpportunityPostStatus { active, expired, removed }

extension OpportunityPostStatusX on OpportunityPostStatus {
  static OpportunityPostStatus? tryParse(String? raw) {
    if (raw == null) return null;
    for (final e in OpportunityPostStatus.values) {
      if (e.name == raw) return e;
    }
    return null;
  }
}
