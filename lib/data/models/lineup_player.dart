import 'package:equatable/equatable.dart';
import 'player_model.dart';

/// Player option for live scoring lineup dropdowns.
class LineupPlayer extends Equatable {
  const LineupPlayer({required this.id, required this.name});

  final String id;
  final String name;

  factory LineupPlayer.fromPlayer(PlayerModel player) {
    return LineupPlayer(id: player.id, name: player.name);
  }

  @override
  List<Object?> get props => [id, name];
}
