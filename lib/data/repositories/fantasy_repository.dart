import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/fantasy_join_code.dart';
import '../../domain/services/fantasy_points_service.dart';
import '../models/ball_event_model.dart';
import '../models/fantasy_entry_model.dart';
import '../models/fantasy_league_model.dart';
import '../models/match_model.dart';

class FantasyEntryWithLeague {
  const FantasyEntryWithLeague({
    required this.entry,
    required this.league,
  });

  final FantasyEntryModel entry;
  final FantasyLeagueModel league;
}

class FantasyRepository {
  FantasyRepository({
    FirebaseFirestore? firestore,
    FantasyPointsService? pointsService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _points = pointsService ?? const FantasyPointsService(),
        _uuid = const Uuid();

  final FirebaseFirestore _firestore;
  final FantasyPointsService _points;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _leagues =>
      _firestore.collection(AppConstants.fantasyLeaguesCollection);

  CollectionReference<Map<String, dynamic>> _entries(String leagueId) =>
      _leagues.doc(leagueId).collection(AppConstants.fantasyEntriesCollection);

  Future<String> createLeagueForMatch({
    required MatchModel match,
    required String createdBy,
    String? name,
  }) async {
    final leagueId = _uuid.v4();
    var joinCode = generateFantasyJoinCode();
    for (var attempt = 0; attempt < 5; attempt++) {
      final existing = await _leagues
          .where('joinCode', isEqualTo: joinCode)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) break;
      joinCode = generateFantasyJoinCode();
    }

    final now = DateTime.now();
    final league = FantasyLeagueModel(
      id: leagueId,
      name: name ?? '${match.title} Fantasy',
      joinCode: joinCode,
      matchId: match.id,
      matchTitle: match.title,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
    );

    await _leagues.doc(leagueId).set(league.toMap());
    return leagueId;
  }

  Future<FantasyLeagueModel?> getLeague(String leagueId) async {
    final doc = await _leagues.doc(leagueId).get();
    if (!doc.exists) return null;
    return FantasyLeagueModel.fromMap(doc.id, doc.data()!);
  }

  Future<FantasyLeagueModel?> findLeagueByJoinCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.length < 4) return null;

    final snap = await _leagues
        .where('joinCode', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return FantasyLeagueModel.fromMap(doc.id, doc.data());
  }

  Stream<FantasyLeagueModel?> watchLeague(String leagueId) {
    return _leagues.doc(leagueId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return FantasyLeagueModel.fromMap(doc.id, doc.data()!);
    });
  }

  Stream<List<FantasyEntryModel>> watchLeaderboard(String leagueId) {
    return _entries(leagueId)
        .orderBy('totalPoints', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => FantasyEntryModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Stream<List<FantasyEntryWithLeague>> watchUserEntries(String userId) {
    return _firestore
        .collectionGroup(AppConstants.fantasyEntriesCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      final results = <FantasyEntryWithLeague>[];
      for (final doc in snap.docs) {
        final leagueId = doc.reference.parent.parent?.id;
        if (leagueId == null) continue;
        final league = await getLeague(leagueId);
        if (league == null) continue;
        results.add(
          FantasyEntryWithLeague(
            entry: FantasyEntryModel.fromMap(doc.id, doc.data()),
            league: league,
          ),
        );
      }
      return results;
    });
  }

  Stream<FantasyEntryModel?> watchUserEntry({
    required String leagueId,
    required String userId,
  }) {
    return _entries(leagueId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return FantasyEntryModel.fromMap(doc.id, doc.data());
    });
  }

  Future<FantasyEntryModel?> getUserEntry({
    required String leagueId,
    required String userId,
  }) async {
    final snap = await _entries(leagueId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return FantasyEntryModel.fromMap(doc.id, doc.data());
  }

  Future<String> joinLeague({
    required FantasyLeagueModel league,
    required String userId,
    required String displayName,
  }) async {
    final existing = await getUserEntry(leagueId: league.id, userId: userId);
    if (existing != null) return existing.id;

    final entryId = _uuid.v4();
    final now = DateTime.now();
    final entry = FantasyEntryModel(
      id: entryId,
      leagueId: league.id,
      userId: userId,
      displayName: displayName,
      createdAt: now,
      updatedAt: now,
    );
    await _entries(league.id).doc(entryId).set(entry.toMap());
    return entryId;
  }

  Future<void> saveSquad({
    required FantasyLeagueModel league,
    required FantasyEntryModel entry,
    required List<String> playerIds,
    required String captainId,
    required String viceCaptainId,
    required List<BallEventModel> ballEvents,
  }) async {
    if (!league.isOpen) {
      throw StateError('This fantasy league is locked.');
    }
    if (playerIds.length != league.squadSize) {
      throw ArgumentError('Pick exactly ${league.squadSize} players.');
    }
    if (!playerIds.contains(captainId) || !playerIds.contains(viceCaptainId)) {
      throw ArgumentError('Captain and vice-captain must be in your squad.');
    }
    if (captainId == viceCaptainId) {
      throw ArgumentError('Captain and vice-captain must be different.');
    }

    final updated = entry.copyWith(
      playerIds: playerIds,
      captainId: captainId,
      viceCaptainId: viceCaptainId,
      totalPoints: _points.totalForEntry(
        entry: entry.copyWith(
          playerIds: playerIds,
          captainId: captainId,
          viceCaptainId: viceCaptainId,
        ),
        league: league,
        events: ballEvents,
      ),
      updatedAt: DateTime.now(),
    );

    await _entries(league.id).doc(entry.id).update(updated.toMap());
  }

  Future<void> refreshLeaguePoints({
    required FantasyLeagueModel league,
    required List<BallEventModel> ballEvents,
  }) async {
    final snap = await _entries(league.id).get();
    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();
    final now = DateTime.now().toIso8601String();

    for (final doc in snap.docs) {
      final entry = FantasyEntryModel.fromMap(doc.id, doc.data());
      if (entry.playerIds.isEmpty) continue;

      final total = _points.totalForEntry(
        entry: entry,
        league: league,
        events: ballEvents,
      );

      batch.update(doc.reference, {
        'totalPoints': total,
        'updatedAt': now,
      });
    }

    await batch.commit();
  }

  Future<void> setLeagueStatus({
    required String leagueId,
    required FantasyLeagueStatus status,
    required String requesterId,
  }) async {
    final league = await getLeague(leagueId);
    if (league == null) throw StateError('League not found.');
    if (league.createdBy != requesterId) {
      throw StateError('Only the league creator can change status.');
    }

    await _leagues.doc(leagueId).update({
      'status': status.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
