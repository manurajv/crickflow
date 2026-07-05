import 'package:equatable/equatable.dart';

/// Cache key for player intro profile providers (batter / bowler cards).
class PlayerIntroLookup extends Equatable {
  const PlayerIntroLookup({
    required this.matchId,
    required this.playerId,
    required this.fallbackName,
  });

  final String matchId;
  final String playerId;
  final String fallbackName;

  @override
  List<Object?> get props => [matchId, playerId, fallbackName];
}
