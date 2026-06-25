import '../../core/constants/enums.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/tournament_match_link.dart';

/// Keeps tournament metadata and innings history when persisting match updates.
abstract final class MatchUpdateMerge {
  static MatchModel merge(MatchModel existing, MatchModel incoming) {
    return MatchModel.fromMap(
      existing.id,
      mergeMap(existing, incoming.toMap()),
    );
  }

  static Map<String, dynamic> mergeMap(
    MatchModel existing,
    Map<String, dynamic> incoming,
  ) {
    final patch = Map<String, dynamic>.from(incoming);
    _preserveTournamentFields(existing, patch);
    _preserveAuditFields(existing, patch);
    if (_isInningsRegression(existing.innings, patch['innings'])) {
      patch['innings'] = existing.innings.map((i) => i.toMap()).toList();
      patch['currentInningsIndex'] = existing.currentInningsIndex;
    }
    return patch;
  }

  static MatchModel mergeTournamentLink(
    MatchModel match,
    TournamentMatchLink link,
  ) {
    return link.applyTo(match);
  }

  static void _preserveTournamentFields(
    MatchModel existing,
    Map<String, dynamic> patch,
  ) {
    if (!existing.isTournamentMatch) return;

    if (patch['matchType'] == MatchType.single.name) {
      patch['matchType'] = MatchType.tournament.name;
    }

    for (final field in const [
      'tournamentId',
      'roundId',
      'groupId',
      'roundName',
      'bracketRound',
      'bracketSlot',
    ]) {
      final existingValue = existing.toMap()[field];
      if (existingValue == null) continue;
      final incomingValue = patch[field];
      if (incomingValue == null ||
          (incomingValue is String && incomingValue.trim().isEmpty)) {
        patch[field] = existingValue;
      }
    }
  }

  static void _preserveAuditFields(
    MatchModel existing,
    Map<String, dynamic> patch,
  ) {
    if (existing.createdAt != null && !patch.containsKey('createdAt')) {
      patch['createdAt'] = existing.createdAt!.toIso8601String();
    }
    if (existing.createdBy != null &&
        existing.createdBy!.isNotEmpty &&
        (patch['createdBy'] == null ||
            (patch['createdBy'] as String?)?.isEmpty == true)) {
      patch['createdBy'] = existing.createdBy;
    }
    if (existing.scheduledAt != null && patch['scheduledAt'] == null) {
      patch['scheduledAt'] = existing.scheduledAt!.toIso8601String();
    }
    final incomingScorers = patch['scorerIds'];
    if (existing.scorerIds.isNotEmpty &&
        (incomingScorers == null ||
            (incomingScorers is List && incomingScorers.isEmpty))) {
      patch['scorerIds'] = existing.scorerIds;
    }
  }

  static bool _isInningsRegression(
    List<InningsModel> existing,
    Object? incomingRaw,
  ) {
    if (existing.isEmpty || incomingRaw is! List) return false;

    final incoming = incomingRaw
        .map((e) => InningsModel.fromMap(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();

    if (incoming.isEmpty) return true;

    final existingProgress = existing.any(
      (i) =>
          i.legalBalls > 0 ||
          i.status == InningsStatus.completed ||
          i.status == InningsStatus.inProgress,
    );
    if (!existingProgress) return false;

    if (incoming.length < existing.length) return true;

    if (incoming.length == 1 &&
        incoming.first.status == InningsStatus.notStarted &&
        incoming.first.legalBalls == 0 &&
        existing.any(
          (i) =>
              i.legalBalls > 0 || i.status == InningsStatus.completed,
        )) {
      return true;
    }

    return false;
  }
}
