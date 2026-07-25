import '../../../core/constants/enums.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/tournament_model.dart';
import 'team_profile_models.dart';

/// Derives team trophies from tournament podium / champion fields + final wins.
class TeamTrophyService {
  const TeamTrophyService();

  List<TeamTrophy> compute({
    required String teamId,
    required List<TournamentModel> tournaments,
    List<MatchModel> teamMatches = const [],
  }) {
    final byKey = <String, TeamTrophy>{};

    for (final t in tournaments) {
      if (!t.teamIds.contains(teamId) &&
          t.championTeamId != teamId &&
          t.runnerUpTeamId != teamId &&
          t.thirdPlaceTeamId != teamId &&
          !t.effectivePodiumPlaces.any((p) => p.teamId == teamId)) {
        continue;
      }

      for (final place in t.effectivePodiumPlaces) {
        if (place.teamId != teamId) continue;
        final kind = switch (place.place) {
          1 => TeamTrophyKind.tournamentWinner,
          2 => TeamTrophyKind.runnerUp,
          _ => TeamTrophyKind.special,
        };
        final id = 'podium_${t.id}_${place.place}';
        byKey[id] = TeamTrophy(
          id: id,
          kind: kind,
          title: t.name,
          season: _seasonLabel(t),
          date: t.updatedAt ?? t.createdAt,
          description: place.place == 1
              ? 'Tournament champions'
              : TournamentPodiumPlace.labelFor(place.place),
          tournamentId: t.id,
        );
      }
    }

    // Fallback: won a final match in a tournament without podium fields yet.
    for (final match in teamMatches) {
      if (match.status != MatchStatus.completed) continue;
      if (match.winnerTeamId != teamId) continue;
      if (!match.isTournamentMatch) continue;
      if (!_isFinalMatch(match)) continue;
      final tid = match.tournamentId!;
      final id = 'final_win_$tid';
      if (byKey.containsKey(id) ||
          byKey.keys.any((k) => k.startsWith('podium_$tid'))) {
        continue;
      }
      byKey[id] = TeamTrophy(
        id: id,
        kind: TeamTrophyKind.tournamentWinner,
        title: match.roundName?.isNotEmpty == true
            ? '${match.title} · ${match.roundName}'
            : match.title,
        season: match.completedAt?.year.toString() ??
            match.scheduledAt?.year.toString() ??
            '',
        date: match.completedAt ?? match.scheduledAt,
        description: 'Final winners',
        tournamentId: tid,
      );
    }

    final list = byKey.values.toList()
      ..sort((a, b) {
        final da = a.date ?? DateTime(1970);
        final db = b.date ?? DateTime(1970);
        return db.compareTo(da);
      });
    return list;
  }

  String _seasonLabel(TournamentModel t) {
    final y = t.updatedAt?.year ?? t.createdAt?.year;
    return y?.toString() ?? '';
  }

  bool _isFinalMatch(MatchModel match) {
    final name = (match.roundName ?? '').toLowerCase().trim();
    if (name.isEmpty) return false;
    if (name.contains('semi') ||
        name.contains('quarter') ||
        name.contains('qualifier') ||
        name.contains('eliminator')) {
      return false;
    }
    return name == 'final' ||
        name.contains('final') ||
        name.contains('championship');
  }
}
