import 'package:equatable/equatable.dart';

import '../../core/constants/player_profile_constants.dart';
import '../../core/utils/date_utils.dart';
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

  DateTime? get eventDateEnd {
    final raw = fields['matchDateEnd'];
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  /// Single day or "12 Jan – 15 Jan" for card / share.
  String? get eventDateLabel {
    final start = eventDate;
    if (start == null) return null;
    final end = eventDateEnd;
    if (end == null ||
        (end.year == start.year &&
            end.month == start.month &&
            end.day == start.day)) {
      return AppDateUtils.formatShort(start);
    }
    return '${AppDateUtils.formatShort(start)} – ${AppDateUtils.formatShort(end)}';
  }

  /// Sponsor: what the poster can offer the brand (card body, not a badge).
  String? get brandingOfferText {
    final raw = fields['brandingRequirements'];
    if (raw == null) return null;
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Photographer / videographer portfolio reference URL (if valid).
  String? get portfolioUrl {
    final raw = fields['portfolio'] ?? fields['portfolioUrl'];
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final normalized = s.startsWith('http://') || s.startsWith('https://')
        ? s
        : 'https://$s';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty || !uri.host.contains('.')) return null;
    return normalized;
  }

  /// Chips for every non-empty schema field (dates stay on the calendar row).
  /// `showOnCard` fields are listed first for visual priority.
  List<String> get cardChips {
    final defs = OpportunityFieldSchema.fieldsFor(category);
    final priority = <String>[];
    final chips = <String>[];
    final seen = <String>{};

    void addChip(String? label, {required bool highPriority}) {
      if (label == null || label.isEmpty) return;
      if (!seen.add(label)) return;
      if (highPriority) {
        priority.add(label);
      } else {
        chips.add(label);
      }
    }

    for (final def in defs) {
      if (def.type == OpportunityFieldType.date ||
          def.type == OpportunityFieldType.dateOrRange) {
        continue; // calendar row via eventDateLabel
      }
      // Valid portfolio URLs use the link row; skip chip for those.
      if (def.type == OpportunityFieldType.url || def.key == 'portfolio') {
        final asUrl = portfolioUrl;
        final raw = fields[def.key]?.toString().trim() ?? '';
        if (asUrl != null || raw.isEmpty) continue;
        // Legacy free-text portfolio note — fall through as a chip.
      }
      // Long offer copy — shown as bold body text on the card, not a chip.
      if (def.key == 'brandingRequirements') continue;
      final value = fields[def.key];
      if (value == null) continue;

      final highPriority = def.showOnCard ||
          def.key == 'payment' ||
          def.key == 'paymentAmount' ||
          def.key == 'requiredPlayers' ||
          def.key == 'numberRequired' ||
          def.key == 'battingHand' ||
          def.key == 'bowlingStyle' ||
          def.key == 'playerType';

      if (value is List) {
        for (final v in value) {
          addChip(
            _cardChipLabel(def, v.toString()),
            highPriority: highPriority,
          );
        }
        continue;
      }

      final raw = value.toString().trim();
      if (raw.isEmpty || raw == 'N/A') continue;

      if (def.type == OpportunityFieldType.yesNo) {
        addChip(_yesNoChip(def, raw), highPriority: highPriority);
      } else {
        addChip(_cardChipLabel(def, raw), highPriority: highPriority);
      }
    }
    return [...priority, ...chips];
  }

  static String? _yesNoChip(OpportunityFieldDef def, String raw) {
    final yes = raw == 'Yes' || raw.toLowerCase() == 'true';
    final no = raw == 'No' || raw.toLowerCase() == 'false';
    if (!yes && !no) return _truncateChip(raw);

    return switch (def.key) {
      'certified' => yes ? 'Certified' : 'Not certified',
      'digitalExperience' => yes ? 'Digital scoring' : 'No digital req.',
      'bookingAvailable' => yes ? 'Bookable' : 'Not bookable',
      'drone' => yes ? 'Drone' : 'No drone',
      'commentary' => yes ? 'Commentary' : 'No commentary',
      'liveGraphics' => yes ? 'Live graphics' : 'No live graphics',
      'replay' => yes ? 'Replay' : 'No replay',
      'highlightPackages' => yes ? 'Highlights' : 'No highlights',
      'liveProduction' => yes ? 'Live production' : 'No live production',
      _ => yes ? _shortFieldLabel(def.label) : 'No · ${_shortFieldLabel(def.label)}',
    };
  }

  /// Compact badge text for dense card chips.
  static String? _cardChipLabel(OpportunityFieldDef def, String raw) {
    final s = raw.trim();
    if (s.isEmpty || s == 'N/A') return null;

    if (def.key == 'requiredPlayers' || def.key == 'numberRequired') {
      return '$s needed';
    }
    if (def.key == 'overs') {
      return s == 'Any' ? 'Any overs' : '$s overs';
    }
    if (def.key == 'battingHand') {
      return switch (s) {
        'Right-hand' || 'Right' || 'Right Hand Batsman' => 'RHB',
        'Left-hand' || 'Left' || 'Left Hand Batsman' => 'LHB',
        _ => s,
      };
    }
    if (def.key == 'bowlingStyle') {
      final parsed = PlayerBowlingStyleLabels.fromStored(s);
      if (parsed != null) return parsed.shortLabel;
      return switch (s) {
        'Left Arm Spin' => 'LA Spin',
        'Leg Spinner' => 'Leg spin',
        _ => s,
      };
    }
    if (def.key == 'matchType') {
      return switch (s) {
        'Leather Ball' => 'Leather',
        'Tennis Ball' => 'Tennis',
        'Either' => 'Leather / Tennis',
        _ => s,
      };
    }
    if (def.key == 'experience') {
      return '$s exp.';
    }
    if (def.key == 'playingLevel') {
      return '$s level';
    }

    // Free-text / long values: keep readable, not paragraph-length.
    if (def.type == OpportunityFieldType.multiline ||
        def.type == OpportunityFieldType.text ||
        def.type == OpportunityFieldType.number) {
      return _truncateChip(s);
    }
    return s;
  }

  static String _shortFieldLabel(String label) {
    var s = label.trim();
    final lower = s.toLowerCase();
    for (final suffix in const [
      ' (optional)',
      ' preferred',
      ' required',
      ' needed',
    ]) {
      if (lower.endsWith(suffix)) {
        s = s.substring(0, s.length - suffix.length).trim();
        break;
      }
    }
    return _truncateChip(s) ?? s;
  }

  static String? _truncateChip(String raw, {int max = 36}) {
    final s = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return null;
    if (s.length <= max) return s;
    return '${s.substring(0, max - 1).trimRight()}…';
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
      location.placeName,
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
