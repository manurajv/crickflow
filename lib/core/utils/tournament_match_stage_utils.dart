import '../constants/enums.dart';
import '../../data/models/match_model.dart';

/// Knockout-style round classifications (bracket / playoff rounds).
bool isKnockoutRoundType(RoundType type) {
  return switch (type) {
    RoundType.knockout ||
    RoundType.roundOf32 ||
    RoundType.roundOf16 ||
    RoundType.quarterFinal ||
    RoundType.semiFinal ||
    RoundType.final_ ||
    RoundType.qualifier1 ||
    RoundType.qualifier2 ||
    RoundType.eliminator ||
    RoundType.thirdPlace =>
      true,
    RoundType.groupStage || RoundType.league || RoundType.custom => false,
  };
}

/// Whether a manually scheduled match should be tagged as knockout
/// (`bracketRound` set) based on round + tournament format.
bool shouldTagTournamentMatchAsKnockout({
  required TournamentFormat tournamentFormat,
  RoundType? roundType,
  String? groupId,
}) {
  if (groupId != null && groupId.trim().isNotEmpty) return false;
  if (roundType == RoundType.league || roundType == RoundType.groupStage) {
    return false;
  }
  if (roundType != null && isKnockoutRoundType(roundType)) return true;
  return tournamentFormat == TournamentFormat.knockout;
}

/// Tournament fixture stage, e.g. Knockout, League, Group stage.
String tournamentMatchTypeLabel(
  MatchModel match, {
  String? groupName,
  RoundType? roundType,
  TournamentFormat? tournamentFormat,
}) {
  if (match.bracketRound != null) return 'Knockout';
  if (match.groupId != null && match.groupId!.isNotEmpty) {
    return 'Group stage';
  }
  if (roundType == RoundType.groupStage) return 'Group stage';
  if (roundType == RoundType.league) return 'League';
  if (roundType != null && isKnockoutRoundType(roundType)) return 'Knockout';

  if (tournamentFormat == TournamentFormat.knockout) return 'Knockout';
  if (tournamentFormat == TournamentFormat.league) return 'League';

  return 'League';
}

/// Round or group detail within a tournament stage.
String? tournamentMatchRoundLabel(
  MatchModel match, {
  String? roundName,
  String? groupName,
  RoundType? roundType,
}) {
  if (groupName != null && groupName.isNotEmpty) return groupName;
  if (match.roundName?.trim().isNotEmpty == true) {
    return match.roundName!.trim();
  }
  if (roundName != null && roundName.isNotEmpty) return roundName;
  if (roundType != null &&
      roundType != RoundType.custom &&
      roundType != RoundType.knockout &&
      roundType != RoundType.league &&
      roundType != RoundType.groupStage) {
    return roundType.defaultLabel();
  }
  if (match.bracketRound != null) {
    return 'Round ${match.bracketRound! + 1}';
  }
  return null;
}

/// Combined label for cards, e.g. `Knockout · Semi Final`.
String tournamentMatchStageLabel(
  MatchModel match, {
  String? roundName,
  String? groupName,
  RoundType? roundType,
  TournamentFormat? tournamentFormat,
}) {
  final type = tournamentMatchTypeLabel(
    match,
    groupName: groupName,
    roundType: roundType,
    tournamentFormat: tournamentFormat,
  );
  final round = tournamentMatchRoundLabel(
    match,
    roundName: roundName,
    groupName: groupName,
    roundType: roundType,
  );
  if (round != null && round.isNotEmpty) return '$type · $round';
  return type;
}
