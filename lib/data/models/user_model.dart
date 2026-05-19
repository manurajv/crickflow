import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';
import 'location_model.dart';

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
    this.displayName = '',
    this.phoneNumber,
    this.photoUrl,
    this.role = UserRole.organizer,
    this.location = const LocationModel(),
    this.stats = const UserStatsModel(),
    this.badgeIds = const [],
    this.achievementIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String? phoneNumber;
  final String? photoUrl;
  final UserRole role;
  final LocationModel location;
  final UserStatsModel stats;
  final List<String> badgeIds;
  final List<String> achievementIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String?,
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
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'role': role.name,
        'location': location.toMap(),
        'stats': stats.toMap(),
        'badgeIds': badgeIds,
        'achievementIds': achievementIds,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  UserModel copyWith({
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    UserRole? role,
    LocationModel? location,
    UserStatsModel? stats,
    List<String>? badgeIds,
  }) {
    return UserModel(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      location: location ?? this.location,
      stats: stats ?? this.stats,
      badgeIds: badgeIds ?? this.badgeIds,
      achievementIds: achievementIds,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, email, displayName, role];
}
