import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../models/match_model.dart';
import '../models/player_model.dart';
import '../models/team_model.dart';
import '../../domain/services/player_rankings/player_rankings_models.dart';
import '../../domain/services/player_rankings/player_rankings_service.dart';

/// Loads player career docs (or year-scoped match aggregates) and ranks them.
class PlayerRankingsRepository {
  PlayerRankingsRepository({
    FirebaseFirestore? firestore,
    PlayerRankingsService? rankingsService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _rankings = rankingsService ?? const PlayerRankingsService();

  final FirebaseFirestore _firestore;
  final PlayerRankingsService _rankings;

  CollectionReference<Map<String, dynamic>> get _players =>
      _firestore.collection(AppConstants.playersCollection);

  CollectionReference<Map<String, dynamic>> get _teams =>
      _firestore.collection(AppConstants.teamsCollection);

  CollectionReference<Map<String, dynamic>> get _matches =>
      _firestore.collection(AppConstants.matchesCollection);

  /// Fetches a pool of players, ranks client-side, returns a page.
  Future<PlayerRankingsResult> fetchRankings({
    required PlayerRankingsFilter filter,
    int page = 0,
    int pageSize = 25,
    int poolLimit = 500,
  }) async {
    Map<String, PlayerStatsModel>? yearStats;
    List<PlayerModel> players;

    Map<String, int>? bowlingInningsByPlayerId;

    if (!filter.usesCareerAggregates) {
      final matches = await _fetchCompletedMatches(
        year: filter.year,
        // Overs filter needs a wider pool — recent-only can miss format buckets.
        limit: filter.overs == PlayerRankingsOversFilter.all ? 1000 : 2500,
      );

      bowlingInningsByPlayerId = <String, int>{};

      // Prefer selected ball type; if empty, fall back to all types for that
      // year — same idea as career rankings falling back to overall stats.
      yearStats = _rankings.aggregateFromMatches(
        matches: matches,
        ballType: filter.ballType,
        overs: filter.overs,
        year: filter.year,
        bowlingInningsOut: bowlingInningsByPlayerId,
      );
      if (yearStats.isEmpty) {
        bowlingInningsByPlayerId.clear();
        yearStats = _rankings.aggregateFromMatches(
          matches: matches,
          ballType: null,
          overs: filter.overs,
          year: filter.year,
          bowlingInningsOut: bowlingInningsByPlayerId,
        );
      }
      players = await _playersForIds(yearStats.keys.toList());
    } else {
      players = await _fetchCareerPlayers(poolLimit: poolLimit);
    }

    final teamIds = <String>{
      for (final p in players) ...p.effectiveTeamIds,
    };
    final teamNames = await _teamNames(teamIds);

    final ranked = _rankings.rank(
      players: players,
      filter: filter,
      teamNamesById: teamNames,
      statsByPlayerId: yearStats,
      bowlingInningsByPlayerId: bowlingInningsByPlayerId,
    );

    final start = page * pageSize;
    if (start >= ranked.length) {
      return PlayerRankingsResult(
        entries: const [],
        totalCount: ranked.length,
        page: page,
        pageSize: pageSize,
        hasMore: false,
      );
    }

    final end = (start + pageSize).clamp(0, ranked.length);
    return PlayerRankingsResult(
      entries: ranked.sublist(start, end),
      totalCount: ranked.length,
      page: page,
      pageSize: pageSize,
      hasMore: end < ranked.length,
    );
  }

  Future<List<PlayerModel>> _fetchCareerPlayers({required int poolLimit}) async {
    final snap = await _players
        .orderBy('stats.matchesPlayed', descending: true)
        .limit(poolLimit)
        .get();

    var players = snap.docs
        .map((d) => PlayerModel.fromMap(d.id, d.data()))
        .where((p) => p.userId != null && p.userId!.isNotEmpty)
        .toList();

    if (players.isEmpty) {
      final fallback = await _players.orderBy('name').limit(poolLimit).get();
      players = fallback.docs
          .map((d) => PlayerModel.fromMap(d.id, d.data()))
          .where((p) => p.userId != null && p.userId!.isNotEmpty)
          .where((p) => p.stats.matchesPlayed > 0)
          .toList();
    }
    return players;
  }

  Future<List<MatchModel>> _fetchCompletedMatches({
    int? year,
    int limit = 1000,
  }) async {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

    try {
      final snap = await _matches
          .where('status', isEqualTo: MatchStatus.completed.name)
          .orderBy('completedAt', descending: true)
          .limit(limit)
          .get();
      docs = snap.docs;
    } catch (e) {
      debugPrint('PlayerRankings: completedAt query failed: $e');
      try {
        final snap = await _matches
            .where('status', isEqualTo: MatchStatus.completed.name)
            .limit(limit)
            .get();
        docs = snap.docs;
      } catch (e2) {
        debugPrint('PlayerRankings: status-only query failed: $e2');
        return const [];
      }
    }

    final list = <MatchModel>[];
    for (final doc in docs) {
      final data = doc.data();
      var match = MatchModel.fromMap(doc.id, data);
      match = _withParsedDates(match, data);
      if (year != null) {
        final date = match.completedAt ??
            match.startedAt ??
            match.scheduledAt ??
            match.createdAt;
        if (date == null || date.year != year) continue;
      }
      list.add(match);
    }
    return list;
  }

  MatchModel _withParsedDates(
    MatchModel match,
    Map<String, dynamic> data,
  ) {
    final completed = _parseDate(data['completedAt']);
    final started = _parseDate(data['startedAt']);
    if (completed == null && started == null) return match;
    return match.copyWith(
      completedAt: completed ?? match.completedAt,
      startedAt: started ?? match.startedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  Future<List<PlayerModel>> _playersForIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final byId = <String, PlayerModel>{};
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();
      final snap =
          await _players.where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in snap.docs) {
        final player = PlayerModel.fromMap(doc.id, doc.data());
        // Skip walk-in / guest profiles (no linked CrickFlow account).
        final userId = player.userId?.trim() ?? '';
        if (userId.isEmpty) continue;
        byId[doc.id] = player;
      }
    }
    return byId.values.toList();
  }

  Future<Map<String, String>> _teamNames(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final out = <String, String>{};
    final list = ids.toList();
    for (var i = 0; i < list.length; i += 10) {
      final chunk = list.skip(i).take(10).toList();
      final snap =
          await _teams.where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in snap.docs) {
        final team = TeamModel.fromMap(doc.id, doc.data());
        out[doc.id] = team.name;
      }
    }
    return out;
  }
}

class PlayerRankingsResult {
  const PlayerRankingsResult({
    required this.entries,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  final List<PlayerRankingEntry> entries;
  final int totalCount;
  final int page;
  final int pageSize;
  final bool hasMore;
}
