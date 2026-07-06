import 'package:flutter/material.dart' show Color;

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/tournament_match_stage_utils.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/match_rules_model.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../shared/providers/match_squads_provider.dart';
import '../data/models/match_introduction_snapshot.dart';

/// Builds [MatchIntroductionSnapshot] from match, squad, and tournament data.
class MatchIntroductionSnapshotBuilder {
  MatchIntroductionSnapshotBuilder._();

  static Future<MatchIntroductionSnapshot> build({
    required MatchModel match,
    required MatchDualSquads squads,
    required PlayerRepository playerRepo,
    String? tournamentName,
    String? tournamentRoundName,
    String? tournamentGroupName,
  }) async {
    final teamA = await _buildTeamSide(
      side: squads.teamA,
      fallbackName: match.teamAName,
      playerRepo: playerRepo,
      accent: const Color(0xFF1565C0),
    );
    final teamB = await _buildTeamSide(
      side: squads.teamB,
      fallbackName: match.teamBName,
      playerRepo: playerRepo,
      accent: const Color(0xFF0D47A1),
    );

    final schedule = _resolveSchedule(match);
    final location = match.location;

    return MatchIntroductionSnapshot(
      matchTitle: _resolveMatchTitle(match),
      matchTypeLabel: _matchTypeLabel(
        match,
        tournamentRoundName: tournamentRoundName,
        tournamentGroupName: tournamentGroupName,
      ),
      oversLabel: _oversLabel(match.rules),
      tournamentLabel: _tournamentLabel(match, tournamentName),
      teamA: teamA,
      teamB: teamB,
      venue: _nonEmpty(match.venue),
      city: _nonEmpty(location.city),
      stateProvince: _nonEmpty(location.stateProvince),
      country: _nonEmpty(location.country),
      dateLabel: schedule.$1,
      timeLabel: schedule.$2,
      crickflowLogoUrl: AppConstants.crickflowLogoUrl,
    );
  }

  static Future<MatchIntroductionTeamSide> _buildTeamSide({
    required MatchSquadSide side,
    required String fallbackName,
    required PlayerRepository playerRepo,
    required Color accent,
  }) async {
    final teamName =
        side.teamName.trim().isNotEmpty ? side.teamName.trim() : fallbackName;

    var captainName = '';
    String? captainPhotoUrl;
    final captainId = side.captainId;

    if (captainId != null && captainId.isNotEmpty) {
      for (final player in side.allPlayers) {
        if (player.id == captainId || player.playerId == captainId) {
          captainName = player.name;
          captainPhotoUrl = player.photoUrl;
          break;
        }
      }

      final player = await playerRepo.getPlayer(captainId);
      if (player != null) {
        if (player.name.trim().isNotEmpty) {
          captainName = player.name.trim();
        }
        if (player.photoUrl != null && player.photoUrl!.trim().isNotEmpty) {
          captainPhotoUrl = player.photoUrl;
        }
      }
    }

    return MatchIntroductionTeamSide(
      teamName: teamName,
      teamLogoUrl: side.teamLogoUrl,
      captainName: captainName.trim().isEmpty ? null : captainName.trim(),
      captainPhotoUrl: captainPhotoUrl,
      accentColor: accent,
    );
  }

  static String _resolveMatchTitle(MatchModel match) {
    final title = match.title.trim();
    if (title.isNotEmpty && title.toLowerCase() != 'match') {
      return title;
    }
    if (match.teamAName.isNotEmpty && match.teamBName.isNotEmpty) {
      return '${match.teamAName} vs ${match.teamBName}';
    }
    return title.isNotEmpty ? title : 'Live Match';
  }

  static String _matchTypeLabel(
    MatchModel match, {
    String? tournamentRoundName,
    String? tournamentGroupName,
  }) {
    if (match.isTournamentMatch || _hasTournamentFixtureFields(match)) {
      final storedRound = match.roundName?.trim();
      if (storedRound != null && storedRound.isNotEmpty) {
        return storedRound;
      }
      if (tournamentRoundName != null && tournamentRoundName.trim().isNotEmpty) {
        return tournamentRoundName.trim();
      }

      final round = tournamentMatchRoundLabel(
        match,
        roundName: tournamentRoundName,
        groupName: tournamentGroupName,
      );
      if (round != null && round.isNotEmpty) {
        if (round.startsWith('Round ') && match.bracketSlot != null) {
          return 'Match ${match.bracketSlot! + 1}';
        }
        return round;
      }

      if (match.bracketSlot != null) {
        return 'Match ${match.bracketSlot! + 1}';
      }

      final stageType = tournamentMatchTypeLabel(
        match,
        groupName: tournamentGroupName,
      );
      return switch (stageType) {
        'Knockout' => 'Knockout Match',
        'League' => 'League Match',
        'Group stage' => 'Group Stage',
        _ => stageType,
      };
    }

    final lower = match.title.toLowerCase();
    if (lower.contains('practice')) return 'Practice Match';
    if (lower.contains('friendly')) return 'Friendly Match';
    if (lower.contains('league')) return 'League Match';
    if (lower.contains('knockout')) return 'Knockout Match';
    if (lower.contains('semi final') || lower.contains('semifinal')) {
      return 'Semi Final';
    }
    if (lower.contains('quarter final') || lower.contains('quarterfinal')) {
      return 'Quarter Final';
    }
    if (lower.contains('final')) return 'Final';
    return 'Individual Match';
  }

  static String _oversLabel(MatchRulesModel rules) {
    if (rules.isTestMatch) return 'Test Match';
    return '${rules.totalOvers} Overs';
  }

  static String _tournamentLabel(MatchModel match, String? tournamentName) {
    if (match.isTournamentMatch &&
        tournamentName != null &&
        tournamentName.trim().isNotEmpty) {
      return tournamentName.trim();
    }
    return '';
  }

  static (String?, String?) _resolveSchedule(MatchModel match) {
    final dt = match.scheduledAt ?? match.startedAt ?? match.createdAt;
    if (dt == null) return (null, null);
    return (AppDateUtils.formatShortDay(dt), AppDateUtils.formatTime(dt));
  }

  static String? _nonEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _hasTournamentFixtureFields(MatchModel match) =>
      match.bracketRound != null ||
      (match.groupId != null && match.groupId!.isNotEmpty) ||
      (match.roundId != null && match.roundId!.isNotEmpty);
}
