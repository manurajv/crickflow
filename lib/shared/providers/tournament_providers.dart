import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';
import '../../data/models/tournament/tournament_activity_model.dart';
import '../../data/models/tournament/tournament_group_model.dart';
import '../../data/models/tournament/tournament_member_model.dart';
import '../../data/models/tournament/tournament_official_model.dart';
import '../../data/models/tournament/tournament_points_table_model.dart';
import '../../data/models/tournament/tournament_round_model.dart';
import '../../data/models/tournament/tournament_rules_model.dart';
import '../../data/models/tournament/tournament_sponsor_model.dart';
import '../../data/models/tournament_model.dart';
import '../../domain/services/tournament_activity_service.dart';
import '../../domain/services/points_table_engine_service.dart';
import '../../domain/services/tournament_permission_service.dart';
import '../../domain/services/tournament_statistics_service.dart';
import '../../data/repositories/tournament_sub_repositories.dart';
import 'providers.dart';

final tournamentStatisticsServiceProvider =
    Provider((ref) => const TournamentStatisticsService());

final tournamentActivityServiceProvider =
    Provider((ref) => const TournamentActivityService());

final tournamentRecentActivityProvider =
    Provider.family<List<TournamentActivityItem>, String>((ref, tournamentId) {
  final tournament = ref.watch(tournamentProvider(tournamentId)).valueOrNull;
  if (tournament == null) return [];

  final matches =
      ref.watch(tournamentMatchesProvider(tournamentId)).valueOrNull ?? [];
  final groups =
      ref.watch(tournamentGroupsProvider(tournamentId)).valueOrNull ?? [];
  final officials =
      ref.watch(tournamentOfficialsProvider(tournamentId)).valueOrNull ?? [];
  final sponsors =
      ref.watch(tournamentSponsorsProvider(tournamentId)).valueOrNull ?? [];

  return ref.watch(tournamentActivityServiceProvider).buildRecentActivity(
        tournament: tournament,
        matches: matches,
        groups: groups,
        officials: officials,
        sponsors: sponsors,
      );
});

final tournamentOverviewStatsProvider =
    Provider.family<TournamentOverviewStats, String>((ref, tournamentId) {
  final tournament = ref.watch(tournamentProvider(tournamentId)).valueOrNull;
  final groups =
      ref.watch(tournamentGroupsProvider(tournamentId)).valueOrNull ?? [];
  final officials =
      ref.watch(tournamentOfficialsProvider(tournamentId)).valueOrNull ?? [];
  final sponsors =
      ref.watch(tournamentSponsorsProvider(tournamentId)).valueOrNull ?? [];
  final matches =
      ref.watch(tournamentMatchesProvider(tournamentId)).valueOrNull ?? [];

  final officialsByRole = <TournamentOfficialRole, int>{};
  for (final role in TournamentOfficialRole.values) {
    officialsByRole[role] = 0;
  }
  for (final official in officials) {
    officialsByRole[official.role] = (officialsByRole[official.role] ?? 0) + 1;
  }

  return TournamentOverviewStats(
    teamCount: tournament?.teamIds.length ?? 0,
    matchCount:
        matches.isNotEmpty ? matches.length : tournament?.matchIds.length ?? 0,
    groupCount: groups.length,
    officialCount: officials.length,
    sponsorCount: sponsors.length,
    officialsByRole: officialsByRole,
  );
});

class TournamentOverviewStats {
  const TournamentOverviewStats({
    required this.teamCount,
    required this.matchCount,
    required this.groupCount,
    required this.officialCount,
    required this.sponsorCount,
    required this.officialsByRole,
  });

  final int teamCount;
  final int matchCount;
  final int groupCount;
  final int officialCount;
  final int sponsorCount;
  final Map<TournamentOfficialRole, int> officialsByRole;
}

final tournamentGroupRepositoryProvider =
    Provider((ref) => TournamentGroupRepository());
final tournamentRoundRepositoryProvider =
    Provider((ref) => TournamentRoundRepository());
final tournamentMemberRepositoryProvider =
    Provider((ref) => TournamentMemberRepository());
final tournamentOfficialRepositoryProvider =
    Provider((ref) => TournamentOfficialRepository());
final tournamentSponsorRepositoryProvider =
    Provider((ref) => TournamentSponsorRepository());
final tournamentRulesRepositoryProvider =
    Provider((ref) => TournamentRulesRepository());
final tournamentPointsTableRepositoryProvider =
    Provider((ref) => TournamentPointsTableRepository());

final tournamentPermissionServiceProvider =
    Provider((ref) => const TournamentPermissionService());
final pointsTableEngineProvider =
    Provider((ref) => const PointsTableEngineService());

final tournamentProvider =
    StreamProvider.family<TournamentModel?, String>((ref, id) {
  return ref.watch(tournamentRepositoryProvider).watchTournament(id);
});

final tournamentMatchesProvider =
    StreamProvider.family<List<MatchModel>, String>((ref, tournamentId) {
  return ref.watch(tournamentRepositoryProvider).watchTournamentMatches(tournamentId);
});

final tournamentGroupsProvider =
    StreamProvider.family<List<TournamentGroupModel>, String>((ref, id) {
  return ref.watch(tournamentGroupRepositoryProvider).watchGroups(id);
});

final tournamentRoundsProvider =
    StreamProvider.family<List<TournamentRoundModel>, String>((ref, id) {
  return ref.watch(tournamentRoundRepositoryProvider).watchRounds(id);
});

final tournamentMembersProvider =
    StreamProvider.family<List<TournamentMemberModel>, String>((ref, id) {
  return ref.watch(tournamentMemberRepositoryProvider).watchMembers(id);
});

final tournamentOfficialsProvider =
    StreamProvider.family<List<TournamentOfficialModel>, String>((ref, id) {
  return ref.watch(tournamentOfficialRepositoryProvider).watchOfficials(id);
});

final tournamentSponsorsProvider =
    StreamProvider.family<List<TournamentSponsorModel>, String>((ref, id) {
  return ref.watch(tournamentSponsorRepositoryProvider).watchSponsors(id);
});

final tournamentRulesProvider =
    StreamProvider.family<TournamentRulesModel, String>((ref, id) {
  return ref.watch(tournamentRulesRepositoryProvider).watchRules(id);
});

final tournamentPointsTablesProvider =
    StreamProvider.family<List<TournamentPointsTableModel>, String>((ref, id) {
  return ref.watch(tournamentPointsTableRepositoryProvider).watchTables(id);
});

final tournamentMemberRoleProvider =
    Provider.family<TournamentRole, (String tournamentId, String? userId)>((ref, params) {
  final tournament = ref.watch(tournamentProvider(params.$1)).valueOrNull;
  if (tournament == null || params.$2 == null) return TournamentRole.viewer;

  final members = ref.watch(tournamentMembersProvider(params.$1)).valueOrNull ?? [];
  final membership = members.where((m) => m.userId == params.$2).firstOrNull;

  return ref.watch(tournamentPermissionServiceProvider).resolveRole(
        userId: params.$2,
        organizerId: tournament.effectiveOrganizerId,
        membership: membership,
      );
});

enum TournamentDiscoveryTab {
  myTournaments,
  participating,
  nearby,
  trending,
  upcoming,
  completed,
}

final tournamentDiscoveryTabProvider =
    StateProvider<TournamentDiscoveryTab>((ref) => TournamentDiscoveryTab.myTournaments);

final filteredTournamentsProvider =
    Provider.family<List<TournamentModel>, TournamentDiscoveryTab>((ref, tab) {
  final all = ref.watch(tournamentsProvider).valueOrNull ?? [];
  final uid = ref.watch(authStateProvider).value?.uid;
  final userTeams = ref.watch(teamsProvider).valueOrNull ?? [];
  final userTeamIds = userTeams.map((t) => t.id).toSet();
  final now = DateTime.now();

  List<TournamentModel> list = switch (tab) {
    TournamentDiscoveryTab.myTournaments => all.where((t) {
        if (uid == null) return false;
        return t.effectiveOrganizerId == uid;
      }).toList(),
    TournamentDiscoveryTab.participating => all.where((t) {
        if (uid == null && userTeamIds.isEmpty) return false;
        final teamOverlap = t.teamIds.any(userTeamIds.contains);
        return teamOverlap || t.effectiveOrganizerId == uid;
      }).toList(),
    TournamentDiscoveryTab.nearby => all,
    TournamentDiscoveryTab.trending => [...all]
      ..sort((a, b) => b.teamIds.length.compareTo(a.teamIds.length)),
    TournamentDiscoveryTab.upcoming => all
        .where((t) =>
            t.status == TournamentStatus.upcoming ||
            t.status == TournamentStatus.draft)
        .toList(),
    TournamentDiscoveryTab.completed => all
        .where((t) => t.status == TournamentStatus.completed)
        .toList(),
  };

  if (tab == TournamentDiscoveryTab.upcoming) {
    list.sort((a, b) {
      final aDate = a.startDate ?? a.createdAt ?? now;
      final bDate = b.startDate ?? b.createdAt ?? now;
      return aDate.compareTo(bDate);
    });
  }

  return list;
});

extension _MemberFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
