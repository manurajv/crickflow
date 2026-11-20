import '../../../core/constants/enums.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/series/series.dart';
import '../../../data/models/tournament_model.dart';
import '../points_table_engine_service.dart';
import 'org_competition_lists.dart';

/// Matches that count towards the org's tables and rankings: approved by the
/// org, a normal (non-quick) match, finished, and between two org teams.
bool countsForOrgStandings(MatchModel m) {
  if (!m.isOrgApproved || m.isQuickMatch) return false;
  if (m.status != MatchStatus.completed && m.status != MatchStatus.abandoned) {
    return false;
  }
  return (m.seriesClubAId ?? '').isNotEmpty &&
      (m.seriesClubBId ?? '').isNotEmpty;
}

/// Rows for the org points table, built the same way as a tournament's
/// ([PointsTableEngineService]) with the org's own points rules.
///
/// [tournamentFilter] narrows it to standalone matches or one org tournament;
/// [seedTeamIds] (a tournament's teams) lists teams that haven't played yet.
List<PointsTableEntry> buildOrgPointsTable({
  required List<SeriesClubModel> teams,
  required List<MatchModel> matches,
  SeriesRankingRulesModel rules = const SeriesRankingRulesModel(),
  String? tournamentFilter,
  Set<String>? seedTeamIds,
}) {
  final playable = playableTeams(teams);
  final nameByTeamId = {for (final t in playable) t.linkedTeamId!: t.name};
  final counted = matches
      .where(countsForOrgStandings)
      .where((m) => matchPassesTournamentFilter(m, tournamentFilter))
      .toList()
    ..sort((a, b) => _when(a).compareTo(_when(b)));

  final oneTournament = tournamentFilter != null &&
      tournamentFilter.isNotEmpty &&
      tournamentFilter != kOrgStandaloneFilter;
  final seedIds = !oneTournament
      ? nameByTeamId.keys.toSet()
      : (seedTeamIds ?? const <String>{})
          .where(nameByTeamId.containsKey)
          .toSet();
  final seed = [
    for (final id in seedIds)
      PointsTableEntry(teamId: id, teamName: nameByTeamId[id] ?? ''),
  ];

  final rebuilt = const PointsTableEngineService().rebuildFromMatches(
    seed: seed,
    matches: counted,
    winPts: rules.winPoints,
    tiePts: rules.tiePoints,
    lossPts: rules.lossPoints,
    noResultPts: rules.noResultPoints,
  );

  final named = [
    for (final r in rebuilt)
      r.copyWith(
        teamName: (nameByTeamId[r.teamId] ?? r.teamName).trim(),
      ),
  ];
  named.sort((a, b) {
    if (b.points != a.points) return b.points.compareTo(a.points);
    if (rules.useNetRunRate && b.netRunRate != a.netRunRate) {
      return b.netRunRate.compareTo(a.netRunRate);
    }
    if (b.won != a.won) return b.won.compareTo(a.won);
    return a.teamName.toLowerCase().compareTo(b.teamName.toLowerCase());
  });
  return [
    for (var i = 0; i < named.length; i++) named[i].copyWith(position: i + 1),
  ];
}

DateTime _when(MatchModel m) =>
    m.completedAt ??
    m.startedAt ??
    m.scheduledAt ??
    m.createdAt ??
    DateTime.fromMillisecondsSinceEpoch(0);

/// Approved org teams linked to a CrickFlow team.
List<SeriesClubModel> playableTeams(List<SeriesClubModel> teams) => teams
    .where((t) =>
        t.status == SeriesClubStatus.approved &&
        (t.linkedTeamId ?? '').isNotEmpty)
    .toList();

/// Completed org matches that feed player rankings.
List<MatchModel> orgRankingMatches(
  Iterable<MatchModel> matches, {
  String? tournamentFilter,
}) =>
    matches
        .where(countsForOrgStandings)
        .where((m) => matchPassesTournamentFilter(m, tournamentFilter))
        .toList();

/// The org's competitions that feed filter dropdowns.
List<TournamentModel> orgApprovedTournaments(Iterable<TournamentModel> all) =>
    all.where((t) => t.isOrgApproved).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
