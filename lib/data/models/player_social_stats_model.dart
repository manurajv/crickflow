import 'package:equatable/equatable.dart';

/// Denormalized social counters on the user profile.
class PlayerSocialStatsModel extends Equatable {
  const PlayerSocialStatsModel({
    this.followersCount = 0,
    this.followingCount = 0,
    this.profileViewsCount = 0,
  });

  final int followersCount;
  final int followingCount;
  final int profileViewsCount;

  factory PlayerSocialStatsModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlayerSocialStatsModel();
    return PlayerSocialStatsModel(
      followersCount: _asInt(map['followersCount']),
      followingCount: _asInt(map['followingCount']),
      profileViewsCount: _asInt(map['profileViewsCount']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  Map<String, dynamic> toMap() => {
        'followersCount': followersCount,
        'followingCount': followingCount,
        'profileViewsCount': profileViewsCount,
      };

  PlayerSocialStatsModel copyWith({
    int? followersCount,
    int? followingCount,
    int? profileViewsCount,
  }) {
    return PlayerSocialStatsModel(
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      profileViewsCount: profileViewsCount ?? this.profileViewsCount,
    );
  }

  @override
  List<Object?> get props =>
      [followersCount, followingCount, profileViewsCount];
}
