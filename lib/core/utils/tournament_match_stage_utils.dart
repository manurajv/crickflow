import '../../data/models/match_model.dart';

/// Tournament fixture stage, e.g. Knockout, League, Group stage.
String tournamentMatchTypeLabel(
  MatchModel match, {
  String? groupName,
}) {
  if (match.bracketRound != null) return 'Knockout';
  if (match.groupId != null && match.groupId!.isNotEmpty) {
    return 'Group stage';
  }
  return 'League';
}

/// Round or group detail within a tournament stage.
String? tournamentMatchRoundLabel(
  MatchModel match, {
  String? roundName,
  String? groupName,
}) {
  if (match.bracketRound != null) {
    return 'Round ${match.bracketRound! + 1}';
  }
  if (groupName != null && groupName.isNotEmpty) return groupName;
  if (match.roundName?.trim().isNotEmpty == true) return match.roundName!.trim();
  if (roundName != null && roundName.isNotEmpty) return roundName;
  return null;
}

/// Combined label for cards, e.g. `Knockout · Round 1`.
String tournamentMatchStageLabel(
  MatchModel match, {
  String? roundName,
  String? groupName,
}) {
  final type = tournamentMatchTypeLabel(match, groupName: groupName);
  final round = tournamentMatchRoundLabel(
    match,
    roundName: roundName,
    groupName: groupName,
  );
  if (round != null && round.isNotEmpty) return '$type · $round';
  return type;
}
