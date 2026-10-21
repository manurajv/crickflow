import '../../../core/constants/enums.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/tournament_model.dart';

/// Tournament belongs to an org (orgs only allow normal matches).
bool isOrgTournament(TournamentModel? t) =>
    t != null &&
    (t.seriesId ?? '').isNotEmpty &&
    t.seriesOfficialStatus != 'rejected';

/// Client-side mirror of the `linkMatchToTournament` callable checks, used
/// to list candidate matches. The server re-validates on link.
abstract final class TournamentMatchLinkPolicy {
  /// Why [match] cannot be linked to a tournament with [teamIds], or null.
  static String? blockReason(
    MatchModel match,
    List<String> teamIds, {
    bool orgTournament = false,
  }) {
    if (orgTournament && match.matchMode == MatchMode.quick) {
      return 'Quick matches are not allowed in org tournaments';
    }
    final linked = match.tournamentId?.trim() ?? '';
    if (linked.isNotEmpty) return 'Already in a tournament';
    final series = match.seriesId?.trim() ?? '';
    if (series.isNotEmpty) return 'Series match';
    final a = match.teamAId ?? '';
    final b = match.teamBId ?? '';
    if (a.isEmpty || b.isEmpty) return 'Teams are not registered teams';
    if (!teamIds.contains(a) || !teamIds.contains(b)) {
      return 'Teams are not in this tournament';
    }
    return null;
  }

  /// Matches that can be added, newest first.
  static List<MatchModel> linkable(
    Iterable<MatchModel> matches,
    List<String> teamIds, {
    bool orgTournament = false,
  }) {
    final seen = <String>{};
    final out = [
      for (final m in matches)
        if (seen.add(m.id) &&
            blockReason(m, teamIds, orgTournament: orgTournament) == null)
          m,
    ];
    out.sort((x, y) {
      final dx = x.completedAt ?? x.scheduledAt ?? x.createdAt;
      final dy = y.completedAt ?? y.scheduledAt ?? y.createdAt;
      if (dx == null && dy == null) return 0;
      if (dx == null) return 1;
      if (dy == null) return -1;
      return dy.compareTo(dx);
    });
    return out;
  }
}
