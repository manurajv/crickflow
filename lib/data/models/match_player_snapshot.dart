import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'player_model.dart';

/// Frozen player data saved on the match document at setup time.
class MatchPlayerSnapshot extends Equatable {
  const MatchPlayerSnapshot({
    required this.id,
    required this.name,
    this.playerId,
    this.playingRole = '',
    this.battingStyle = '',
    this.bowlingStyle = '',
    this.jerseyNumber,
    this.photoUrl,
    this.isMatchOnlyPlayer = false,
    this.isRegisteredUser = true,
  });

  final String id;
  final String name;
  final String? playerId;
  final String playingRole;
  final String battingStyle;
  final String bowlingStyle;
  final int? jerseyNumber;
  final String? photoUrl;
  final bool isMatchOnlyPlayer;
  final bool isRegisteredUser;

  factory MatchPlayerSnapshot.fromPlayer(PlayerModel player) {
    return MatchPlayerSnapshot(
      id: player.id,
      name: player.name,
      playerId: player.playerId,
      playingRole: player.role,
      battingStyle: player.battingStyle,
      bowlingStyle: player.bowlingStyle,
      jerseyNumber: player.jerseyNumber,
      photoUrl: player.photoUrl,
      isMatchOnlyPlayer: false,
      isRegisteredUser: player.userId != null && player.userId!.isNotEmpty,
    );
  }

  factory MatchPlayerSnapshot.matchOnly({
    required String name,
    required String playingRole,
    required String battingStyle,
    required String bowlingStyle,
    int? jerseyNumber,
  }) {
    return MatchPlayerSnapshot(
      id: 'guest_${const Uuid().v4()}',
      name: name.trim(),
      playingRole: playingRole,
      battingStyle: battingStyle,
      bowlingStyle: bowlingStyle,
      jerseyNumber: jerseyNumber,
      isMatchOnlyPlayer: true,
      isRegisteredUser: false,
    );
  }

  factory MatchPlayerSnapshot.fromMap(Map<String, dynamic> map) {
    return MatchPlayerSnapshot(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      playerId: map['playerId'] as String?,
      playingRole: map['playingRole'] as String? ?? '',
      battingStyle: map['battingStyle'] as String? ?? '',
      bowlingStyle: map['bowlingStyle'] as String? ?? '',
      jerseyNumber: map['jerseyNumber'] as int?,
      photoUrl: map['photoUrl'] as String?,
      isMatchOnlyPlayer: map['isMatchOnlyPlayer'] as bool? ?? false,
      isRegisteredUser: map['isRegisteredUser'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        if (playerId != null) 'playerId': playerId,
        'playingRole': playingRole,
        'battingStyle': battingStyle,
        'bowlingStyle': bowlingStyle,
        if (jerseyNumber != null) 'jerseyNumber': jerseyNumber,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'isMatchOnlyPlayer': isMatchOnlyPlayer,
        'isRegisteredUser': isRegisteredUser,
      };

  @override
  List<Object?> get props => [id, name, playerId, isMatchOnlyPlayer];
}
