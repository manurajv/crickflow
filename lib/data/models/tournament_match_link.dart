import '../../core/constants/enums.dart';
import 'match_model.dart';

/// Tournament fixture metadata resolved from a match doc or parent tournament.
class TournamentMatchLink {
  const TournamentMatchLink({
    required this.tournamentId,
    this.roundId,
    this.roundName,
    this.groupId,
    this.bracketRound,
    this.bracketSlot,
  });

  final String tournamentId;
  final String? roundId;
  final String? roundName;
  final String? groupId;
  final int? bracketRound;
  final int? bracketSlot;

  static TournamentMatchLink? fromMatch(MatchModel match) {
    final tournamentId = match.tournamentId?.trim();
    if (tournamentId == null || tournamentId.isEmpty) return null;
    return TournamentMatchLink(
      tournamentId: tournamentId,
      roundId: match.roundId,
      roundName: match.roundName,
      groupId: match.groupId,
      bracketRound: match.bracketRound,
      bracketSlot: match.bracketSlot,
    );
  }

  /// Match snapshot with tournament fields filled for UI when Firestore is incomplete.
  MatchModel applyTo(MatchModel match) {
    return MatchModel(
      id: match.id,
      title: match.title,
      matchType: MatchType.tournament,
      status: match.status,
      teamAId: match.teamAId,
      teamBId: match.teamBId,
      teamAName: match.teamAName,
      teamBName: match.teamBName,
      tournamentId: tournamentId,
      roundId: match.roundId ?? roundId,
      groupId: match.groupId ?? groupId,
      roundName: match.roundName ?? roundName,
      bracketRound: match.bracketRound ?? bracketRound,
      bracketSlot: match.bracketSlot ?? bracketSlot,
      rules: match.rules,
      innings: match.innings,
      currentInningsIndex: match.currentInningsIndex,
      location: match.location,
      venue: match.venue,
      scheduledAt: match.scheduledAt,
      startedAt: match.startedAt,
      completedAt: match.completedAt,
      createdBy: match.createdBy,
      scorerIds: match.scorerIds,
      scorer1UserId: match.scorer1UserId,
      scorer2UserId: match.scorer2UserId,
      currentScorerId: match.currentScorerId,
      currentScorerName: match.currentScorerName,
      currentScorerPhoto: match.currentScorerPhoto,
      scorerOwnershipToken: match.scorerOwnershipToken,
      lastScorerTransferAt: match.lastScorerTransferAt,
      scorerTransferHistory: match.scorerTransferHistory,
      winnerTeamId: match.winnerTeamId,
      resultSummary: match.resultSummary,
      matchHero: match.matchHero,
      playerOfMatchId: match.playerOfMatchId,
      badgeIds: match.badgeIds,
      stream: match.stream,
      overlayVersion: match.overlayVersion,
      mediaByCode: match.mediaByCode,
      createdAt: match.createdAt,
      setup: match.setup,
      overNotes: match.overNotes,
      overMetadata: match.overMetadata,
      targetState: match.targetState,
      activeMatchBreak: match.activeMatchBreak,
      matchBreakHistory: match.matchBreakHistory,
      publicMatchId: match.publicMatchId,
    );
  }

  /// Firestore patch for missing or wrong tournament fields on an existing match.
  Map<String, dynamic>? patchFor(MatchModel match) {
    final patch = <String, dynamic>{};
    if (match.matchType != MatchType.tournament) {
      patch['matchType'] = MatchType.tournament.name;
    }
    if (match.tournamentId == null || match.tournamentId!.trim().isEmpty) {
      patch['tournamentId'] = tournamentId;
    }
    if ((match.roundId == null || match.roundId!.isEmpty) &&
        roundId != null &&
        roundId!.isNotEmpty) {
      patch['roundId'] = roundId;
    }
    if ((match.roundName == null || match.roundName!.trim().isEmpty) &&
        roundName != null &&
        roundName!.trim().isNotEmpty) {
      patch['roundName'] = roundName!.trim();
    }
    if ((match.groupId == null || match.groupId!.isEmpty) &&
        groupId != null &&
        groupId!.isNotEmpty) {
      patch['groupId'] = groupId;
    }
    if (match.bracketRound == null && bracketRound != null) {
      patch['bracketRound'] = bracketRound;
    }
    if (match.bracketSlot == null && bracketSlot != null) {
      patch['bracketSlot'] = bracketSlot;
    }
    return patch.isEmpty ? null : patch;
  }
}
