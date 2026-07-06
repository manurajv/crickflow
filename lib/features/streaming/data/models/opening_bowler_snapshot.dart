import 'package:equatable/equatable.dart';

/// Opening bowler shown after the opening batsmen overlay, before normal scorebug.
class OpeningBowlerSnapshot extends Equatable {
  const OpeningBowlerSnapshot({
    required this.playerId,
    required this.fallbackName,
  });

  final String playerId;
  final String fallbackName;

  bool get isValid => playerId.isNotEmpty;

  @override
  List<Object?> get props => [playerId, fallbackName];
}
