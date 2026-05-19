import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../data/models/bracket_models.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_rules_model.dart';
import '../../data/models/tournament_model.dart';
import '../../domain/services/fixture_generator_service.dart';
import 'match_repository.dart';
import 'team_repository.dart';

class TournamentRepository {
  TournamentRepository({
    FirebaseFirestore? firestore,
    MatchRepository? matchRepository,
    TeamRepository? teamRepository,
    FixtureGeneratorService? fixtureGenerator,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _matchRepository = matchRepository ?? MatchRepository(),
        _teamRepository = teamRepository ?? TeamRepository(),
        _fixtureGenerator = fixtureGenerator ?? FixtureGeneratorService(),
        _uuid = const Uuid();

  final FirebaseFirestore _firestore;
  final MatchRepository _matchRepository;
  final TeamRepository _teamRepository;
  final FixtureGeneratorService _fixtureGenerator;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.tournamentsCollection);

  Future<String> createTournament(TournamentModel tournament) async {
    final id = tournament.id.isEmpty ? _uuid.v4() : tournament.id;
    await _col.doc(id).set(tournament.toMap());
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

  Stream<List<TournamentModel>> watchTournaments() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TournamentModel.fromMap(d.id, d.data()))
            .toList());
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

  /// Round-robin league fixtures for all teams in tournament.
  Future<List<String>> generateLeagueFixtures({
    required String tournamentId,
    required String createdBy,
    MatchRulesModel rules = const MatchRulesModel(),
  }) async {
    final tournament = await getTournament(tournamentId);
    if (tournament == null) throw StateError('Tournament not found');
    if (tournament.teamIds.length < 2) {
      throw StateError('Add at least 2 teams first');
    }

    final teams = <({String id, String name})>[];
    for (final teamId in tournament.teamIds) {
      final team = await _teamRepository.getTeam(teamId);
      final entry = tournament.pointsTable
          .where((e) => e.teamId == teamId)
          .firstOrNull;
      teams.add((
        id: teamId,
        name: team?.name ?? entry?.teamName ?? 'Team',
      ));
    }

    final matches = _fixtureGenerator.buildLeagueMatches(
      tournament: tournament,
      teams: teams,
      createdBy: createdBy,
      rules: rules,
    );

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
    MatchRulesModel rules = const MatchRulesModel(),
  }) async {
    final tournament = await getTournament(tournamentId);
    if (tournament == null) throw StateError('Tournament not found');
    if (tournament.teamIds.length < 2) {
      throw StateError('Add at least 2 teams first');
    }

    final teams = <({String id, String name})>[];
    for (final teamId in tournament.teamIds) {
      final team = await _teamRepository.getTeam(teamId);
      final entry = tournament.pointsTable
          .where((e) => e.teamId == teamId)
          .firstOrNull;
      teams.add((
        id: teamId,
        name: team?.name ?? entry?.teamName ?? 'Team',
      ));
    }

    final matches = _fixtureGenerator.buildKnockoutRoundOneMatches(
      tournament: tournament,
      teams: teams,
      createdBy: createdBy,
      rules: rules,
    );

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
      bracketRound: round,
      bracketSlot: slot,
      rules: const MatchRulesModel(),
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
}

extension _TournamentCopy on TournamentModel {
  TournamentModel copyWith({
    List<String>? teamIds,
    List<String>? matchIds,
    List<PointsTableEntry>? pointsTable,
    List<List<BracketSlotModel>>? bracketRounds,
    TournamentStatus? status,
  }) {
    return TournamentModel(
      id: id,
      name: name,
      format: format,
      status: status ?? this.status,
      teamIds: teamIds ?? this.teamIds,
      matchIds: matchIds ?? this.matchIds,
      pointsTable: pointsTable ?? this.pointsTable,
      bracketRounds: bracketRounds ?? this.bracketRounds,
      location: location,
      bannerUrl: bannerUrl,
      startDate: startDate,
      endDate: endDate,
      createdBy: createdBy,
      description: description,
      createdAt: createdAt,
    );
  }
}
