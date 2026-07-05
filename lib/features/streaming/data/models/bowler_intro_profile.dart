import 'package:equatable/equatable.dart';

/// Career bowling snapshot for the broadcast bowler intro card.
class BowlerIntroProfile extends Equatable {
  const BowlerIntroProfile({
    required this.playerName,
    this.playerId = '',
    this.photoUrl,
    this.teamName = '',
    this.teamLogoUrl,
    this.formatLabel = '',
    this.bowlingStyle = '',
    this.matches = 0,
    this.wickets = 0,
    this.average = 0,
    this.fiveWicketHauls = 0,
    this.bestFigures = '—',
  });

  final String playerId;
  final String playerName;
  final String? photoUrl;
  final String teamName;
  final String? teamLogoUrl;
  final String formatLabel;
  final String bowlingStyle;
  final int matches;
  final int wickets;
  final double average;
  final int fiveWicketHauls;
  final String bestFigures;

  @override
  List<Object?> get props => [playerId, playerName, formatLabel];
}
