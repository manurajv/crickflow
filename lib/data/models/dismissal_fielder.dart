import 'package:equatable/equatable.dart';

/// One assisting fielder on a dismissal (multi-fielder ready).
class DismissalFielder extends Equatable {
  const DismissalFielder({
    required this.playerId,
    this.playerName = '',
  });

  final String playerId;
  final String playerName;

  factory DismissalFielder.fromMap(Map<String, dynamic> map) {
    return DismissalFielder(
      playerId: map['playerId'] as String? ?? '',
      playerName: map['playerName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'playerId': playerId,
        if (playerName.isNotEmpty) 'playerName': playerName,
      };

  @override
  List<Object?> get props => [playerId, playerName];
}
