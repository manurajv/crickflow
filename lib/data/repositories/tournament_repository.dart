import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../core/utils/tournament_code.dart';
import '../../data/models/bracket_models.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_rules_model.dart';
import '../../data/models/tournament/tournament_group_model.dart';
import '../../data/models/tournament/tournament_member_model.dart';
import '../../data/models/tournament/tournament_points_table_model.dart';
import '../../data/models/tournament/tournament_round_model.dart';
import '../../data/models/tournament_model.dart';
import '../../domain/services/fixture_generator_service.dart';
import 'match_repository.dart';
import 'team_repository.dart';
import 'tournament_sub_repositories.dart';

class TournamentRepository {
  TournamentRepository({
    FirebaseFirestore? firestore,
    MatchRepository? matchRepository,
    TeamRepository? teamRepository,
    FixtureGeneratorService? fixtureGenerator,
    TournamentGroupRepository? groupRepository,
    TournamentRoundRepository? roundRepository,
    TournamentMemberRepository? memberRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _matchRepository = matchRepository ?? MatchRepository(),
        _teamRepository = teamRepository ?? TeamRepository(),
        _fixtureGenerator = fixtureGenerator ?? FixtureGeneratorService(),
        _groupRepository = groupRepository ?? TournamentGroupRepository(),
        _roundRepository = roundRepository ?? TournamentRoundRepository(),
        _memberRepository = memberRepository ?? TournamentMemberRepository(),
        _uuid = const Uuid();

  final FirebaseFirestore _firestore;
  final MatchRepository _matchRepository;
  final TeamRepository _teamRepository;
  final FixtureGeneratorService _fixtureGenerator;
  final TournamentGroupRepository _groupRepository;
  final TournamentRoundRepository _roundRepository;
  final TournamentMemberRepository _memberRepository;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.tournamentsCollection);

  Future<String> createTournament({
    required TournamentModel tournament,
    String? ownerDisplayName,
  }) async {
    final id = tournament.id.isEmpty ? _uuid.v4() : tournament.id;
    final code = tournament.tournamentCode ?? generateTournamentCode();
    final doc = tournament.copyWith(tournamentCode: code);
    await _col.doc(id).set(doc.toMap());

    final organizerId = doc.effectiveOrganizerId;
    if (organizerId.isNotEmpty) {
      try {
        await _memberRepository.upsertMember(
          TournamentMemberModel(
            id: '${id}_$organizerId',
            tournamentId: id,
            userId: organizerId,
            role: TournamentRole.owner,
            displayName: ownerDisplayName ?? '',
          ),
        );
      } catch (_) {
        // Owner is recorded on the tournament doc; member row is optional.
      }
    }
    return id;
  }

  Future<void> updateTournament(TournamentModel tournament) async {
    await _col.doc(tournament.id).update(tournament.toMap());
  }

  Future<TournamentModel?> getTournament(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return TournamentModel.fromMap(doc.id, doc.data()!);
  }

  Future<TournamentModel?> findByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    final snap = await _col
        .where('tournamentCode', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return TournamentModel.fromMap(doc.id, doc.data());
  }

  Stream<TournamentModel?> watchTournament(String id) {
    return _col.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return TournamentModel.fromMap(doc.id, doc.data()!);
    });
  }

  Stream<List<TournamentModel>> watchTournaments() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TournamentModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<TournamentModel>> watchOrganizerTournaments(String organizerId) {
    return _col
        .where('organizerId', isEqualTo: organizerId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TournamentModel.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) =>
              (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0))));
  }

  Stream<List<MatchModel>> watchTournamentMatches(String tournamentId) {
    return _matchRepository.watchMatches().map((matches) => matches
        .where((m) => m.tournamentId == tournamentId)
        .toList()
      ..sort((a, b) =>
          (a.scheduledAt ?? DateTime(0)).compareTo(b.scheduledAt ?? DateTime(0))));
  }

  Future<void> addTeamToTournament({
    required String tournamentId,
    required String teamId,
    required String teamName,
  }) async {
    final t = await getTournament(tournamentId);
    if (t == null) return;

    final teamIds = List<String>.from(t.teamIds);
    if (!teamIds.contains(teamId)) teamIds.add(teamId);

    final pointsTable = List<PointsTableEntry>.from(t.pointsTable);
    if (!pointsTable.any((e) => e.teamId == teamId)) {
      pointsTable.add(PointsTableEntry(teamId: teamId, teamName: teamName));
    }

    await updateTournament(t.copyWith(
      teamIds: teamIds,
      pointsTable: pointsTable,
    ));
  }

  /// Used when team leadership accepts a tournament invitation — Firestore rules
  /// require [leadershipRosterTeamId] on the write to authorize the roster add.
  Future<void> addTeamToTournamentViaLeadershipAccept({
    required String tournamentId,
    required String teamId,
    required String teamName,
  }) async {
    final t = await getTournament(tournamentId);
    if (t == null) return;

    final teamIds = List<String>.from(t.teamIds);
    if (!teamIds.contains(teamId)) teamIds.add(teamId);

    final pointsTable = List<PointsTableEntry>.from(t.pointsTable);
    if (!pointsTable.any((e) => e.teamId == teamId)) {
      pointsTable.add(PointsTableEntry(teamId: teamId, teamName: teamName));
    }

    await _col.doc(tournamentId).update({
      'teamIds': teamIds,
      'pointsTable': pointsTable.map((e) => e.toMap()).toList(),
      'leadershipRosterTeamId': teamId,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeTeamFromTournament({
    required String tournamentId,
    required String teamId,
  }) async {
    final t = await getTournament(tournamentId);
    if (t == null) return;

    await updateTournament(t.copyWith(
      teamIds: t.teamIds.where((id) => id != teamId).toList(),
      pointsTable: t.pointsTable.where((e) => e.teamId != teamId).toList(),
    ));
  }

  Future<List<({String id, String name})>> _resolveTeams(
    TournamentModel tournament,
  ) async {
    final teams = <({String id, String name})>[];
    for (final teamId in tournament.teamIds) {
      final team = await _teamRepository.getTeam(teamId);
      final entry =
          tournament.pointsTable.where((e) => e.teamId == teamId).firstOrNull;
      teams.add((
        id: teamId,
        name: team?.name ?? entry?.teamName ?? 'Team',
      ));
    }
    return teams;
  }

  MatchRulesModel _rulesFor(TournamentModel tournament) {
    return tournament.defaultRules.toMatchRules();
  }

  /// Round-robin league fixtures for all teams in tournament.
  Future<List<String>> generateLeagueFixtures({
    required String tournamentId,
    required String createdBy,
    MatchRulesModel? rules,
    String? roundId,
    String? roundName,
  }) async {
    final tournament = await getTournament(tournamentId);
    if (tournament == null) throw StateError('Tournament not found');
    if (tournament.teamIds.length < 2) {
      throw StateError('Add at least 2 teams first');
    }

    final teams = await _resolveTeams(tournament);
    final matchRules = rules ?? _rulesFor(tournament);

    final matches = _fixtureGenerator.buildLeagueMatches(
      tournament: tournament,
      teams: teams,
      createdBy: createdBy,
      rules: matchRules,
      roundId: roundId,
      roundName: roundName,
    );

    return _persistMatches(tournament, matches);
  }

  /// Group-stage round robin using [tournament_groups] documents.
  Future<List<String>> generateGroupStageFixtures({
    required String tournamentId,
    required String createdBy,
    String? roundId,
    String? roundName,
  }) async {
    final tournament = await getTournament(tournamentId);
    if (tournament == null) throw StateError('Tournament not found');

    final groups = await _groupRepository
        .watchGroups(tournamentId)
        .first
        .timeout(const Duration(seconds: 10));

    if (groups.isEmpty) throw StateError('Create groups first');

    final groupPayload =
        <String, ({String id, String name, List<({String id, String name})> teams})>{};

    for (final group in groups) {
      if (group.teamIds.length < 2) continue;
      final teams = <({String id, String name})>[];
      for (final teamId in group.teamIds) {
        final team = await _teamRepository.getTeam(teamId);
        teams.add((id: teamId, name: team?.name ?? 'Team'));
      }
      groupPayload[group.id] = (id: group.id, name: group.name, teams: teams);
    }

    if (groupPayload.isEmpty) {
      throw StateError('Each group needs at least 2 teams');
    }

    final matches = _fixtureGenerator.buildGroupStageMatches(
      tournament: tournament,
      groups: groupPayload,
      createdBy: createdBy,
      rules: _rulesFor(tournament),
      roundId: roundId,
      roundName: roundName,
    );

    return _persistMatches(tournament, matches);
  }

  Future<List<String>> _persistMatches(
    TournamentModel tournament,
    List<MatchModel> matches,
  ) async {
    final matchIds = <String>[];
    for (final m in matches) {
      final id = await _matchRepository.createMatch(m);
      matchIds.add(id);
    }

    await updateTournament(tournament.copyWith(
      matchIds: [...tournament.matchIds, ...matchIds],
      status: TournamentStatus.upcoming,
    ));

    return matchIds;
  }

  /// Single-elimination bracket: creates round 1 matches + TBD skeleton for later rounds.
  Future<List<String>> generateKnockoutBracket({
    required String tournamentId,
    required String createdBy,
    MatchRulesModel? rules,
    String? roundId,
    String? roundName,
  }) async {
    final tournament = await getTournament(tournamentId);
    if (tournament == null) throw StateError('Tournament not found');
    if (tournament.teamIds.length < 2) {
      throw StateError('Add at least 2 teams first');
    }

    final teams = await _resolveTeams(tournament);
    final matchRules = rules ?? _rulesFor(tournament);

    final rawMatches = _fixtureGenerator.buildKnockoutRoundOneMatches(
      tournament: tournament,
      teams: teams,
      createdBy: createdBy,
      rules: matchRules,
    );

    final matches = rawMatches
        .map(
          (m) => MatchModel(
            id: m.id,
            title: m.title,
            matchType: m.matchType,
            status: m.status,
            teamAId: m.teamAId,
            teamBId: m.teamBId,
            teamAName: m.teamAName,
            teamBName: m.teamBName,
            tournamentId: m.tournamentId,
            roundId: roundId,
            roundName: roundName,
            bracketRound: m.bracketRound,
            bracketSlot: m.bracketSlot,
            winnerTeamId: m.winnerTeamId,
            resultSummary: m.resultSummary,
            rules: m.rules,
            location: m.location,
            scheduledAt: m.scheduledAt,
            createdBy: m.createdBy,
          ),
        )
        .toList();

    final roundOneSlots = <BracketSlotModel>[];
    final matchIds = <String>[];

    for (final m in matches) {
      final id = await _matchRepository.createMatch(m);
      matchIds.add(id);
      roundOneSlots.add(BracketSlotModel(
        matchId: id,
        teamAId: m.teamAId,
        teamBId: m.teamBId,
        teamAName: m.teamAName,
        teamBName: m.teamBName,
        winnerTeamId: m.winnerTeamId,
        winnerTeamName: m.winnerTeamId != null ? m.teamAName : '',
      ));
    }

    final bracketRounds = _fixtureGenerator.buildBracketSkeleton(
      teamCount: teams.length,
      roundOneSlots: roundOneSlots,
    );

    await updateTournament(tournament.copyWith(
      matchIds: [...tournament.matchIds, ...matchIds],
      bracketRounds: bracketRounds,
      status: TournamentStatus.upcoming,
    ));

    return matchIds;
  }

  Future<TournamentRoundModel> ensureDefaultRound({
    required String tournamentId,
    required RoundType roundType,
    String? customName,
  }) async {
    final existing = await _roundRepository.watchRounds(tournamentId).first;
    final match = existing.where((r) => r.roundType == roundType).firstOrNull;
    if (match != null) return match;

    final round = TournamentRoundModel(
      id: '',
      tournamentId: tournamentId,
      name: customName ?? roundType.defaultLabel(),
      roundType: roundType,
      sortOrder: existing.length,
    );
    final id = await _roundRepository.createRound(round);
    return round.copyWithId(id);
  }

  Future<TournamentGroupModel> createGroup({
    required String tournamentId,
    required String name,
    List<String> teamIds = const [],
  }) async {
    final group = TournamentGroupModel(
      id: '',
      tournamentId: tournamentId,
      name: name,
      teamIds: teamIds,
    );
    final id = await _groupRepository.createGroup(group);
    final saved = group.copyWith(id: id);
    await _syncPointsTableForGroup(saved);
    return saved;
  }

  /// After a knockout match completes, record the winner and fill the next bracket slot.
  Future<void> advanceKnockoutFromMatch(MatchModel match) async {
    if (match.tournamentId == null ||
        match.bracketRound == null ||
        match.bracketSlot == null ||
        match.winnerTeamId == null) {
      return;
    }

    final tournament = await getTournament(match.tournamentId!);
    if (tournament == null || tournament.bracketRounds.isEmpty) return;

    final round = match.bracketRound!;
    final slot = match.bracketSlot!;
    final winnerId = match.winnerTeamId!;
    final winnerName = winnerId == match.teamAId
        ? match.teamAName
        : winnerId == match.teamBId
            ? match.teamBName
            : 'Winner';

    final rounds = tournament.bracketRounds
        .map((r) => List<BracketSlotModel>.from(r))
        .toList();
    if (round >= rounds.length || slot >= rounds[round].length) return;

    final current = rounds[round][slot];
    rounds[round][slot] = BracketSlotModel(
      matchId: current.matchId,
      teamAId: current.teamAId,
      teamBId: current.teamBId,
      teamAName: current.teamAName,
      teamBName: current.teamBName,
      winnerTeamId: winnerId,
      winnerTeamName: winnerName,
    );

    var extraMatchIds = <String>[];

    if (round + 1 < rounds.length) {
      final nextRound = round + 1;
      final nextSlot = slot ~/ 2;
      final fillsTeamA = slot.isEven;
      final next = rounds[nextRound][nextSlot];
      rounds[nextRound][nextSlot] = BracketSlotModel(
        matchId: next.matchId,
        teamAId: fillsTeamA ? winnerId : next.teamAId,
        teamBId: fillsTeamA ? next.teamBId : winnerId,
        teamAName: fillsTeamA ? winnerName : next.teamAName,
        teamBName: fillsTeamA ? next.teamBName : winnerName,
        winnerTeamId: next.winnerTeamId,
        winnerTeamName: next.winnerTeamName,
      );

      final createdId = await _maybeCreateKnockoutMatch(
        tournament: tournament,
        rounds: rounds,
        round: nextRound,
        slot: nextSlot,
        createdBy: match.createdBy ?? '',
        roundId: match.roundId,
        roundName: match.roundName,
      );
      if (createdId != null) extraMatchIds.add(createdId);
    }

    await updateTournament(tournament.copyWith(
      matchIds: [...tournament.matchIds, ...extraMatchIds],
      bracketRounds: rounds,
    ));
  }

  Future<String?> _maybeCreateKnockoutMatch({
    required TournamentModel tournament,
    required List<List<BracketSlotModel>> rounds,
    required int round,
    required int slot,
    required String createdBy,
    String? roundId,
    String? roundName,
  }) async {
    if (createdBy.isEmpty) return null;

    final s = rounds[round][slot];
    if (s.matchId != null) return null;
    final aId = s.teamAId;
    final bId = s.teamBId;
    if (aId == null || bId == null) return null;
    if (s.teamAName == 'TBD' ||
        s.teamBName == 'TBD' ||
        s.teamAName.isEmpty ||
        s.teamBName.isEmpty) {
      return null;
    }

    final m = MatchModel(
      id: '',
      title: '${tournament.name} — ${s.teamAName} vs ${s.teamBName}',
      matchType: MatchType.tournament,
      status: MatchStatus.scheduled,
      teamAId: aId,
      teamBId: bId,
      teamAName: s.teamAName,
      teamBName: s.teamBName,
      tournamentId: tournament.id,
      roundId: roundId,
      roundName: roundName,
      bracketRound: round,
      bracketSlot: slot,
      rules: _rulesFor(tournament),
      location: tournament.location,
      scheduledAt: DateTime.now(),
      createdBy: createdBy,
    );

    final id = await _matchRepository.createMatch(m);
    rounds[round][slot] = BracketSlotModel(
      matchId: id,
      teamAId: aId,
      teamBId: bId,
      teamAName: s.teamAName,
      teamBName: s.teamBName,
    );
    return id;
  }

  Future<void> updateGroup(TournamentGroupModel group) async {
    await _groupRepository.updateGroup(group);
    await _syncPointsTableForGroup(group);
  }

  Future<void> deleteGroup(String groupId) async {
    await _groupRepository.deleteGroup(groupId);
    try {
      await TournamentPointsTableRepository().deleteTable(groupId);
    } catch (_) {
      // Points table may not exist yet.
    }
  }

  /// Removes a scheduled/upcoming tournament match from Firestore and the
  /// tournament's `matchIds` list.
  Future<void> deleteTournamentMatch({
    required String tournamentId,
    required String matchId,
  }) async {
    final match = await _matchRepository.getMatch(matchId);
    if (match == null) return;
    if (!_isDeletableUpcomingMatch(match.status)) {
      throw StateError('Only upcoming scheduled matches can be deleted');
    }

    await _matchRepository.deleteMatch(matchId);

    final tournament = await getTournament(tournamentId);
    if (tournament != null) {
      await updateTournament(
        tournament.copyWith(
          matchIds: tournament.matchIds.where((id) => id != matchId).toList(),
        ),
      );
    }
  }

  bool _isDeletableUpcomingMatch(MatchStatus status) =>
      status == MatchStatus.draft ||
      status == MatchStatus.scheduled ||
      status == MatchStatus.tossCompleted;

  Future<List<TournamentGroupModel>> createGroupsManual({
    required String tournamentId,
    required int count,
    List<String>? names,
  }) async {
    final created = <TournamentGroupModel>[];
    for (var i = 0; i < count; i++) {
      final label = names != null && i < names.length
          ? names[i]
          : 'Group ${String.fromCharCode(65 + i)}';
      created.add(await createGroup(tournamentId: tournamentId, name: label));
    }
    return created;
  }

  Future<List<TournamentGroupModel>> createGroupsAutoDistribution({
    required String tournamentId,
    required int groupCount,
  }) async {
    final tournament = await getTournament(tournamentId);
    if (tournament == null) throw StateError('Tournament not found');
    final teamIds = List<String>.from(tournament.teamIds);
    if (teamIds.isEmpty) throw StateError('Add teams before creating groups');
    if (groupCount < 1) throw StateError('Need at least one group');

    final groups = await createGroupsManual(
      tournamentId: tournamentId,
      count: groupCount,
    );

    final updated = <TournamentGroupModel>[];
    for (var i = 0; i < teamIds.length; i++) {
      final groupIndex = i % groupCount;
      final group = groups[groupIndex];
      final next = group.copyWith(
        teamIds: [...group.teamIds, teamIds[i]],
      );
      await updateGroup(next);
      updated.add(next);
      groups[groupIndex] = next;
    }
    return updated;
  }

  Future<TournamentRoundModel> createRound({
    required String tournamentId,
    required String name,
    RoundType roundType = RoundType.custom,
    String description = '',
    bool isActive = true,
  }) async {
    final existing = await _roundRepository.watchRounds(tournamentId).first;
    final round = TournamentRoundModel(
      id: '',
      tournamentId: tournamentId,
      name: name,
      description: description,
      roundType: roundType,
      sortOrder: existing.length,
      isActive: isActive,
    );
    final id = await _roundRepository.createRound(round);
    return round.copyWithId(id);
  }

  Future<void> updateRound(TournamentRoundModel round) async {
    await _roundRepository.updateRound(round);
  }

  Future<void> deleteRound(String roundId) async {
    await _roundRepository.deleteRound(roundId);
  }

  Future<void> reorderRounds(List<TournamentRoundModel> rounds) async {
    await _roundRepository.reorderRounds(rounds);
  }

  Future<String> scheduleTournamentMatch({
    required TournamentModel tournament,
    required String createdBy,
    required String teamAId,
    required String teamBId,
    String? roundId,
    String? roundName,
    String? groupId,
    String? venue,
    DateTime? scheduledAt,
    MatchRulesModel? rules,
    int totalOvers = 20,
    CricketMatchType cricketMatchType = CricketMatchType.limitedOvers,
  }) async {
    final teams = await _resolveTeams(tournament);
    final teamA = teams.where((t) => t.id == teamAId).firstOrNull;
    final teamB = teams.where((t) => t.id == teamBId).firstOrNull;
    if (teamA == null || teamB == null) {
      throw StateError('Both teams must be in the tournament');
    }

    final matchRules = (rules ?? _rulesFor(tournament)).copyWith(
      totalOvers: rules?.totalOvers ?? totalOvers,
      cricketMatchType: rules?.cricketMatchType ?? cricketMatchType,
    );

    final match = MatchModel(
      id: '',
      title: '${teamA.name} vs ${teamB.name}',
      matchType: MatchType.tournament,
      status: MatchStatus.scheduled,
      teamAId: teamAId,
      teamBId: teamBId,
      teamAName: teamA.name,
      teamBName: teamB.name,
      tournamentId: tournament.id,
      roundId: roundId,
      roundName: roundName,
      groupId: groupId,
      venue: venue ?? '',
      location: tournament.location,
      scheduledAt: scheduledAt ?? DateTime.now().add(const Duration(days: 1)),
      rules: matchRules,
      createdBy: createdBy,
    );

    final id = await _matchRepository.createMatch(match);
    await updateTournament(tournament.copyWith(
      matchIds: [...tournament.matchIds, id],
      status: TournamentStatus.upcoming,
    ));
    return id;
  }

  Future<void> _syncPointsTableForGroup(TournamentGroupModel group) async {
    final tournament = await getTournament(group.tournamentId);
    final entries = group.teamIds.map((id) {
      final name = tournament?.pointsTable
              .where((e) => e.teamId == id)
              .firstOrNull
              ?.teamName ??
          id;
      return PointsTableEntry(teamId: id, teamName: name);
    }).toList();
    if (entries.isEmpty) return;

    final table = TournamentPointsTableModel(
      id: group.id,
      tournamentId: group.tournamentId,
      groupId: group.id,
      groupName: group.name,
      entries: entries,
    );
    await TournamentPointsTableRepository().saveTable(table);
  }
}
