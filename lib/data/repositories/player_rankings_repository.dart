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
  ///
  /// When [viewerPlayerDocId] / [viewerPublicPlayerId] are set, [myEntry] is
  /// the signed-in user's row in the full ranked list (if present).
  Future<PlayerRankingsResult> fetchRankings({
    required PlayerRankingsFilter filter,
    int page = 0,
    int pageSize = 25,
    int poolLimit = 500,
    String? viewerPlayerDocId,
    String? viewerPublicPlayerId,
  }) async {
    Map<String, PlayerStatsModel>? yearStats;
    List<PlayerModel> players;

    Map<String, int>? bowlingInningsByPlayerId;

    if (!filter.usesCareerAggregates) {
      final matches = await _fetchCompletedMatches(
        year: filter.year,
        // Ball-type rankings need a wide completed-match pool.
        limit: 2500,
      );

      bowlingInningsByPlayerId = <String, int>{};
      yearStats = _rankings.aggregateFromMatches(
        matches: matches,
        filter: filter,
        bowlingInningsOut: bowlingInningsByPlayerId,
      );
      players = await _playersForIds(yearStats.keys.toList());
    } else {
      players = await _fetchCareerPlayers(poolLimit: poolLimit);
      // Ensure the viewer is in the career pool so their rank can appear.
      players = await _ensureViewerInPool(
        players: players,
        viewerPlayerDocId: viewerPlayerDocId,
      );
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

    final myEntry = _findViewerEntry(
      ranked: ranked,
      viewerPlayerDocId: viewerPlayerDocId,
      viewerPublicPlayerId: viewerPublicPlayerId,
    );

    // Search only narrows the list — ranks stay from the other filters.
    final visible = _applySearch(ranked, filter.searchQuery);

    final start = page * pageSize;
    if (start >= visible.length) {
      return PlayerRankingsResult(
        entries: const [],
        totalCount: visible.length,
        page: page,
        pageSize: pageSize,
        hasMore: false,
        myEntry: myEntry,
      );
    }

    final end = (start + pageSize).clamp(0, visible.length);
    return PlayerRankingsResult(
      entries: visible.sublist(start, end),
      totalCount: visible.length,
      page: page,
      pageSize: pageSize,
      hasMore: end < visible.length,
      myEntry: myEntry,
    );
  }

  List<PlayerRankingEntry> _applySearch(
    List<PlayerRankingEntry> ranked,
    String searchQuery,
  ) {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return ranked;
    return [
      for (final e in ranked)
        if (_entryMatchesSearch(e, q)) e,
    ];
  }

  bool _entryMatchesSearch(PlayerRankingEntry entry, String q) {
    if (entry.playerName.toLowerCase().contains(q)) return true;
    final publicId = entry.publicPlayerId?.toLowerCase() ?? '';
    if (publicId.contains(q)) return true;
    if (entry.teamName.toLowerCase().contains(q)) return true;
    if (entry.role.toLowerCase().contains(q)) return true;
    return false;
  }

  Future<List<PlayerModel>> _ensureViewerInPool({
    required List<PlayerModel> players,
    String? viewerPlayerDocId,
  }) async {
    final id = viewerPlayerDocId?.trim() ?? '';
    if (id.isEmpty) return players;
    if (players.any((p) => p.id == id)) return players;
    try {
      final doc = await _players.doc(id).get();
      final data = doc.data();
      if (!doc.exists || data == null) return players;
      final player = PlayerModel.fromMap(doc.id, data);
      final userId = player.userId?.trim() ?? '';
      if (userId.isEmpty) return players;
      return [...players, player];
    } catch (e) {
      debugPrint('PlayerRankings: failed to load viewer player: $e');
      return players;
    }
  }

  PlayerRankingEntry? _findViewerEntry({
    required List<PlayerRankingEntry> ranked,
    String? viewerPlayerDocId,
    String? viewerPublicPlayerId,
  }) {
    final docId = viewerPlayerDocId?.trim() ?? '';
    final publicId = viewerPublicPlayerId?.trim() ?? '';
    if (docId.isEmpty && publicId.isEmpty) return null;

    for (final e in ranked) {
      if (docId.isNotEmpty && e.playerDocId == docId) return e;
      final pid = e.publicPlayerId?.trim() ?? '';
      if (publicId.isNotEmpty && pid.isNotEmpty && pid == publicId) return e;
    }
    return null;
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
    this.myEntry,
  });

  final List<PlayerRankingEntry> entries;
  final int totalCount;
  final int page;
  final int pageSize;
  final bool hasMore;

  /// Signed-in user's ranking row for the current filters, if ranked.
  final PlayerRankingEntry? myEntry;
}
