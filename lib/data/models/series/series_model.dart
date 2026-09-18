import 'package:equatable/equatable.dart';

import 'series_enums.dart';

/// Configurable Series settings (registration fields, squad max, ranking rules).
class SeriesSettingsModel extends Equatable {
  const SeriesSettingsModel({
    this.maxSquadSize = 20,
    this.requireFullName = true,
    this.requireCrickFlowPlayerId = true,
    this.requireDateOfBirth = false,
    this.requireNationalId = false,
    this.requirePassport = false,
    this.requirePhoneNumber = false,
    this.requireAddress = false,
    this.requireProfilePhoto = false,
    this.customRequiredFields = const [],
    this.rankingRules = const SeriesRankingRulesModel(),
  });

  final int maxSquadSize;
  final bool requireFullName;
  final bool requireCrickFlowPlayerId;
  final bool requireDateOfBirth;
  final bool requireNationalId;
  final bool requirePassport;
  final bool requirePhoneNumber;
  final bool requireAddress;
  final bool requireProfilePhoto;
  final List<String> customRequiredFields;
  final SeriesRankingRulesModel rankingRules;

  factory SeriesSettingsModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const SeriesSettingsModel();
    return SeriesSettingsModel(
      maxSquadSize: (map['maxSquadSize'] as num?)?.toInt() ?? 20,
      requireFullName: map['requireFullName'] as bool? ?? true,
      requireCrickFlowPlayerId: map['requireCrickFlowPlayerId'] as bool? ?? true,
      requireDateOfBirth: map['requireDateOfBirth'] as bool? ?? false,
      requireNationalId: map['requireNationalId'] as bool? ?? false,
      requirePassport: map['requirePassport'] as bool? ?? false,
      requirePhoneNumber: map['requirePhoneNumber'] as bool? ?? false,
      requireAddress: map['requireAddress'] as bool? ?? false,
      requireProfilePhoto: map['requireProfilePhoto'] as bool? ?? false,
      customRequiredFields: List<String>.from(
        map['customRequiredFields'] as List? ?? const [],
      ),
      rankingRules: SeriesRankingRulesModel.fromMap(
        map['rankingRules'] is Map
            ? Map<String, dynamic>.from(map['rankingRules'] as Map)
            : null,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'maxSquadSize': maxSquadSize,
        'requireFullName': requireFullName,
        'requireCrickFlowPlayerId': requireCrickFlowPlayerId,
        'requireDateOfBirth': requireDateOfBirth,
        'requireNationalId': requireNationalId,
        'requirePassport': requirePassport,
        'requirePhoneNumber': requirePhoneNumber,
        'requireAddress': requireAddress,
        'requireProfilePhoto': requireProfilePhoto,
        'customRequiredFields': customRequiredFields,
        'rankingRules': rankingRules.toMap(),
      };

  @override
  List<Object?> get props => [
        maxSquadSize,
        requireFullName,
        requireCrickFlowPlayerId,
        requireDateOfBirth,
        requireNationalId,
        requirePassport,
        requirePhoneNumber,
        requireAddress,
        requireProfilePhoto,
        customRequiredFields,
        rankingRules,
      ];
}

class SeriesRankingRulesModel extends Equatable {
  const SeriesRankingRulesModel({
    this.winPoints = 2,
    this.lossPoints = 0,
    this.tiePoints = 1,
    this.noResultPoints = 1,
    this.bonusPointsEnabled = false,
    this.useNetRunRate = true,
    this.useRunDifference = false,
  });

  final int winPoints;
  final int lossPoints;
  final int tiePoints;
  final int noResultPoints;
  final bool bonusPointsEnabled;
  final bool useNetRunRate;
  final bool useRunDifference;

  factory SeriesRankingRulesModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const SeriesRankingRulesModel();
    return SeriesRankingRulesModel(
      winPoints: (map['winPoints'] as num?)?.toInt() ?? 2,
      lossPoints: (map['lossPoints'] as num?)?.toInt() ?? 0,
      tiePoints: (map['tiePoints'] as num?)?.toInt() ?? 1,
      noResultPoints: (map['noResultPoints'] as num?)?.toInt() ?? 1,
      bonusPointsEnabled: map['bonusPointsEnabled'] as bool? ?? false,
      useNetRunRate: map['useNetRunRate'] as bool? ?? true,
      useRunDifference: map['useRunDifference'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'winPoints': winPoints,
        'lossPoints': lossPoints,
        'tiePoints': tiePoints,
        'noResultPoints': noResultPoints,
        'bonusPointsEnabled': bonusPointsEnabled,
        'useNetRunRate': useNetRunRate,
        'useRunDifference': useRunDifference,
      };

  @override
  List<Object?> get props => [
        winPoints,
        lossPoints,
        tiePoints,
        noResultPoints,
        bonusPointsEnabled,
        useNetRunRate,
        useRunDifference,
      ];
}

/// Top-level Series (Competition Organization) document.
class SeriesModel extends Equatable {
  const SeriesModel({
    required this.id,
    required this.name,
    this.description = '',
    this.rulesText = '',
    this.kind = SeriesKind.series,
    this.status = SeriesStatus.draft,
    this.superAdminUserId,
    this.coverImageUrl,
    this.logoUrl,
    this.region = '',
    this.location = '',
    this.country = '',
    this.settings = const SeriesSettingsModel(),
    this.clubCount = 0,
    this.playerCount = 0,
    this.matchCount = 0,
    this.tournamentCount = 0,
    this.organizationId,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  /// Freeform rules / playing conditions shown to members.
  final String rulesText;
  final SeriesKind kind;
  final SeriesStatus status;
  final String? superAdminUserId;
  final String? coverImageUrl;
  final String? logoUrl;
  /// Zone / region label (e.g. North, West).
  final String region;
  /// City / district label (e.g. Jaipur, Chandigarh).
  final String location;
  /// Country name (e.g. India) — usually from creator profile.
  final String country;
  final SeriesSettingsModel settings;
  final int clubCount;
  final int playerCount;
  final int matchCount;
  final int tournamentCount;
  final String? organizationId;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get subtitleMeta {
    final parts = <String>[
      if (location.trim().isNotEmpty) location.trim(),
      if (region.trim().isNotEmpty) region.trim(),
      if (country.trim().isNotEmpty) country.trim(),
    ];
    if (parts.isNotEmpty) return parts.join(' · ');
    return kind.label;
  }

  /// Affiliated [series_clubs] tab — not My cricket Teams.
  String get memberUnitsTabLabel => switch (OrgFamily.forKind(kind)) {
        OrgFamily.clubs => 'Squads',
        OrgFamily.associations => 'Member clubs',
        OrgFamily.series => 'Participating clubs',
      };

  String get memberUnitsStatLabel => switch (OrgFamily.forKind(kind)) {
        OrgFamily.clubs => 'Squads',
        OrgFamily.associations => 'Member clubs',
        OrgFamily.series => 'Clubs',
      };

  String get memberUnitsSingular => switch (OrgFamily.forKind(kind)) {
        OrgFamily.clubs => 'Squad',
        _ => 'Club',
      };

  factory SeriesModel.fromMap(String id, Map<String, dynamic> map) {
    return SeriesModel(
      id: id,
      name: map['name'] as String? ?? 'Organization',
      description: map['description'] as String? ?? '',
      rulesText: map['rulesText'] as String? ?? '',
      kind: SeriesKind.parse(map['kind'] as String?),
      status: SeriesStatus.parse(map['status'] as String?),
      superAdminUserId: map['superAdminUserId'] as String?,
      coverImageUrl: map['coverImageUrl'] as String?,
      logoUrl: map['logoUrl'] as String?,
      region: map['region'] as String? ?? '',
      location: map['location'] as String? ?? '',
      country: map['country'] as String? ?? '',
      settings: SeriesSettingsModel.fromMap(
        map['settings'] is Map
            ? Map<String, dynamic>.from(map['settings'] as Map)
            : null,
      ),
      clubCount: (map['clubCount'] as num?)?.toInt() ?? 0,
      playerCount: (map['playerCount'] as num?)?.toInt() ?? 0,
      matchCount: (map['matchCount'] as num?)?.toInt() ?? 0,
      tournamentCount: (map['tournamentCount'] as num?)?.toInt() ?? 0,
      organizationId: map['organizationId'] as String?,
      createdBy: map['createdBy'] as String?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'rulesText': rulesText,
        'kind': kind.name,
        'status': status.name,
        if (superAdminUserId != null) 'superAdminUserId': superAdminUserId,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        if (logoUrl != null) 'logoUrl': logoUrl,
        'region': region,
        'location': location,
        'country': country,
        'settings': settings.toMap(),
        'clubCount': clubCount,
        'playerCount': playerCount,
        'matchCount': matchCount,
        'tournamentCount': tournamentCount,
        if (organizationId != null) 'organizationId': organizationId,
        if (createdBy != null) 'createdBy': createdBy,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, name, status, superAdminUserId, updatedAt];
}
