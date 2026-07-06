import 'package:equatable/equatable.dart';

/// One opening batter slot for the pre-scorebug pair overlay.
class OpeningBatterSlot extends Equatable {
  const OpeningBatterSlot({
    required this.playerId,
    required this.fallbackName,
    this.onStrike = false,
  });

  final String playerId;
  final String fallbackName;
  final bool onStrike;

  @override
  List<Object?> get props => [playerId, fallbackName, onStrike];
}

/// Striker + non-striker shown after the match introduction overlay.
class OpeningBatsmenSnapshot extends Equatable {
  const OpeningBatsmenSnapshot({
    required this.striker,
    required this.nonStriker,
    required this.matchTitle,
    this.crickflowLogoUrl = '',
  });

  final OpeningBatterSlot striker;
  final OpeningBatterSlot nonStriker;
  final String matchTitle;
  final String crickflowLogoUrl;

  bool get isValid =>
      striker.playerId.isNotEmpty && nonStriker.playerId.isNotEmpty;

  @override
  List<Object?> get props => [striker, nonStriker, matchTitle, crickflowLogoUrl];
}
