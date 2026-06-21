import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/player_profile_constants.dart';
import 'location_model.dart';
import 'player_social_stats_model.dart';

class UserStatsModel extends Equatable {
  const UserStatsModel({
    this.matchesPlayed = 0,
    this.matchesScored = 0,
    this.tournamentsOrganized = 0,
  });

  final int matchesPlayed;
  final int matchesScored;
  final int tournamentsOrganized;

  factory UserStatsModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const UserStatsModel();
    return UserStatsModel(
      matchesPlayed: map['matchesPlayed'] as int? ?? 0,
      matchesScored: map['matchesScored'] as int? ?? 0,
      tournamentsOrganized: map['tournamentsOrganized'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'matchesPlayed': matchesPlayed,
        'matchesScored': matchesScored,
        'tournamentsOrganized': tournamentsOrganized,
      };

  @override
  List<Object?> get props =>
      [matchesPlayed, matchesScored, tournamentsOrganized];
}

class UserModel extends Equatable {
  const UserModel({
    required this.id,
    required this.email,
    this.name = '',
    this.displayName = '',
    this.phoneNumber,
    this.mobile,
    this.photoUrl,
    this.role = UserRole.organizer,
    this.location = const LocationModel(),
    this.stats = const UserStatsModel(),
    this.badgeIds = const [],
    this.achievementIds = const [],
    this.country = '',
    this.countryCode = '',
    this.countryFlag = '',
    this.dateOfBirth,
    this.gender,
    this.playerRole,
    this.battingStyle,
    this.bowlingStyle,
    this.jerseyNumber,
    this.primaryPosition,
    this.strongHand,
    this.favoriteTeam = '',
    this.bio = '',
    this.onboardingCompleted = true,
    this.playerId,
    this.socialStats = const PlayerSocialStatsModel(),
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  /// Legal / full name (required after onboarding).
  final String name;
  /// Public scorecard name (optional).
  final String displayName;
  final String? phoneNumber;
  final String? mobile;
  final String? photoUrl;
  final UserRole role;
  final LocationModel location;
  final UserStatsModel stats;
  final List<String> badgeIds;
  final List<String> achievementIds;
  final String country;
  /// ISO country code (e.g. LK, IN).
  final String countryCode;
  final String countryFlag;
  final DateTime? dateOfBirth;
  final PlayerGender? gender;
  final PlayerPlayingRole? playerRole;
  final PlayerBattingStyle? battingStyle;
  final PlayerBowlingStyle? bowlingStyle;
  final int? jerseyNumber;
  final PlayerPrimaryPosition? primaryPosition;
  final PlayerStrongHand? strongHand;
  final String favoriteTeam;
  final String bio;
  final bool onboardingCompleted;
  /// Public sequential ID (e.g. CF000001). Immutable after onboarding.
  final String? playerId;
  final PlayerSocialStatsModel socialStats;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Legacy alias — prefer [playerId].
  String? get cfPlayerId => playerId;

  String get effectiveName =>
      name.isNotEmpty ? name : (displayName.isNotEmpty ? displayName : 'CrickFlow User');

  String get effectiveMobile => mobile ?? phoneNumber ?? '';

  String get effectivePlayerIdDisplay =>
      playerId != null && playerId!.isNotEmpty ? playerId! : '';

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String?,
      mobile: map['mobile'] as String? ?? map['phoneNumber'] as String?,
      photoUrl: map['photoUrl'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.organizer,
      ),
      location: LocationModel.fromMap(map['location'] as Map<String, dynamic>?),
      stats: UserStatsModel.fromMap(map['stats'] as Map<String, dynamic>?),
      badgeIds: List<String>.from(map['badgeIds'] as List? ?? []),
      achievementIds:
          List<String>.from(map['achievementIds'] as List? ?? []),
      country: map['country'] as String? ?? '',
      countryCode: map['countryCode'] as String? ?? '',
      countryFlag: map['countryFlag'] as String? ?? '',
      dateOfBirth: _parseDate(map['dob'] ?? map['dateOfBirth']),
      gender: enumFromName(PlayerGender.values, map['gender'] as String?),
      playerRole: enumFromName(
        PlayerPlayingRole.values,
        map['playingRole'] as String? ?? map['playerRole'] as String?,
      ),
      battingStyle: enumFromName(
        PlayerBattingStyle.values,
        map['battingStyle'] as String?,
      ),
      bowlingStyle: enumFromName(
        PlayerBowlingStyle.values,
        map['bowlingStyle'] as String?,
      ),
      jerseyNumber: _parseJersey(map['jerseyNumber']),
      primaryPosition: enumFromName(
        PlayerPrimaryPosition.values,
        map['primaryPosition'] as String?,
      ),
      strongHand: enumFromName(
        PlayerStrongHand.values,
        map['strongHand'] as String?,
      ),
      favoriteTeam: map['favoriteTeam'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      onboardingCompleted: map['onboardingCompleted'] as bool? ?? true,
      playerId: map['playerId'] as String? ?? map['cfPlayerId'] as String?,
      socialStats: PlayerSocialStatsModel.fromMap(
        map['socialStats'] as Map<String, dynamic>?,
      ),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static int? _parseJersey(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String && value.isEmpty) return null;
    return int.tryParse(value.toString());
  }

  /// Full profile map — writes every onboarding field (null/empty when skipped).
  Map<String, dynamic> toMap() => {
        'uid': id,
        'email': email,
        'name': name,
        'displayName': displayName.isNotEmpty ? displayName : name,
        'photoUrl': photoUrl,
        'country': country,
        'countryCode': countryCode,
        'countryFlag': countryFlag,
        'mobile': mobile,
        'phoneNumber': phoneNumber ?? mobile,
        'dob': dateOfBirth?.toIso8601String(),
        'gender': gender?.name,
        'playingRole': playerRole?.name,
        'playerRole': playerRole?.name,
        'battingStyle': battingStyle?.name,
        'bowlingStyle': bowlingStyle?.name,
        'jerseyNumber': jerseyNumber,
        'primaryPosition': primaryPosition?.name,
        'strongHand': strongHand?.name,
        'favoriteTeam': favoriteTeam,
        'bio': bio,
        'onboardingCompleted': onboardingCompleted,
        'playerId': playerId,
        'socialStats': socialStats.toMap(),
        'role': role.name,
        'location': location.toMap(),
        'stats': stats.toMap(),
        'badgeIds': badgeIds,
        'achievementIds': achievementIds,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  UserModel copyWith({
    String? email,
    String? name,
    String? displayName,
    String? phoneNumber,
    String? mobile,
    String? photoUrl,
    bool clearPhotoUrl = false,
    UserRole? role,
    LocationModel? location,
    UserStatsModel? stats,
    List<String>? badgeIds,
    String? country,
    String? countryCode,
    String? countryFlag,
    DateTime? dateOfBirth,
    PlayerGender? gender,
    PlayerPlayingRole? playerRole,
    PlayerBattingStyle? battingStyle,
    PlayerBowlingStyle? bowlingStyle,
    int? jerseyNumber,
    PlayerPrimaryPosition? primaryPosition,
    PlayerStrongHand? strongHand,
    String? favoriteTeam,
    String? bio,
    bool? onboardingCompleted,
    String? playerId,
    PlayerSocialStatsModel? socialStats,
  }) {
    return UserModel(
      id: id,
      email: email ?? this.email,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      mobile: mobile ?? this.mobile,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      role: role ?? this.role,
      location: location ?? this.location,
      stats: stats ?? this.stats,
      badgeIds: badgeIds ?? this.badgeIds,
      achievementIds: achievementIds,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      countryFlag: countryFlag ?? this.countryFlag,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      playerRole: playerRole ?? this.playerRole,
      battingStyle: battingStyle ?? this.battingStyle,
      bowlingStyle: bowlingStyle ?? this.bowlingStyle,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      primaryPosition: primaryPosition ?? this.primaryPosition,
      strongHand: strongHand ?? this.strongHand,
      favoriteTeam: favoriteTeam ?? this.favoriteTeam,
      bio: bio ?? this.bio,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      playerId: playerId ?? this.playerId,
      socialStats: socialStats ?? this.socialStats,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, email, displayName, role, onboardingCompleted, playerId];
}
