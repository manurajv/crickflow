import 'package:equatable/equatable.dart';

/// Career batting snapshot for the broadcast batter intro card.
class BatterIntroProfile extends Equatable {
  const BatterIntroProfile({
    required this.playerName,
    this.playerId = '',
    this.photoUrl,
    this.teamName = '',
    this.teamLogoUrl,
    this.formatLabel = '',
    this.battingStyle = '',
    this.matches = 0,
    this.average = 0,
    this.strikeRate = 0,
    this.bestScore = 0,
  });

  final String playerId;
  final String playerName;
  final String? photoUrl;
  final String teamName;
  final String? teamLogoUrl;
  final String formatLabel;
  final String battingStyle;
  final int matches;
  final double average;
  final double strikeRate;
  final int bestScore;

  @override
  List<Object?> get props => [playerId, playerName, formatLabel];
}
