import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../models/player_model.dart';

class PlayerRepository {
  PlayerRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.playersCollection);

  CollectionReference<Map<String, dynamic>> get _teams =>
      _firestore.collection(AppConstants.teamsCollection);

  Future<String> createPlayer(PlayerModel player) async {
    final id = player.id.isEmpty ? _uuid.v4() : player.id;
    final data = player.toMap();
    data['teamId'] = player.teamId;
    await _col.doc(id).set(data);
    return id;
  }

  Future<void> updatePlayer(PlayerModel player) async {
    await _col.doc(player.id).update(player.toMap());
  }

  Future<PlayerModel?> getPlayerByUserId(String userId) async {
    final doc = await _col.doc(userId).get();
    if (!doc.exists) return null;
    return PlayerModel.fromMap(doc.id, doc.data()!);
  }

  /// Players not on [excludeTeamId] (for squad picker). Optional name filter.
  Future<List<PlayerModel>> searchAvailablePlayers({
    required String excludeTeamId,
    required Set<String> alreadyOnSquadIds,
    String query = '',
  }) async {
    final snap = await _col.orderBy('name').limit(250).get();
    final q = query.trim().toLowerCase();

    final list = snap.docs
        .map((d) => PlayerModel.fromMap(d.id, d.data()))
        .where((p) {
          if (alreadyOnSquadIds.contains(p.id)) return false;
          if (p.teamId == excludeTeamId) return false;
          if (q.isEmpty) return true;
          return p.name.toLowerCase().contains(q);
        })
        .toList();

    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// Adds an existing global player profile to a team roster.
  Future<void> assignPlayerToTeam({
    required String playerId,
    required String teamId,
  }) async {
    await _col.doc(playerId).set(
      {
        'teamId': teamId,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
    await _teams.doc(teamId).update({
      'playerIds': FieldValue.arrayUnion([playerId]),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Links auth user to a player doc (used when role is `player`). Doc id = [userId].
  Future<PlayerModel> ensurePlayerProfileForUser({
    required String userId,
    required String displayName,
    String? photoUrl,
    String? email,
  }) async {
    final existing = await _col.doc(userId).get();
    if (existing.exists) {
      return PlayerModel.fromMap(userId, existing.data()!);
    }

    final player = PlayerModel(
      id: userId,
      name: displayName.isNotEmpty ? displayName : 'Player',
      userId: userId,
      photoUrl: photoUrl,
      createdBy: userId,
    );
    final data = player.toMap();
    if (email != null) data['email'] = email;
    await _col.doc(userId).set(data);
    return player;
  }

  Stream<List<PlayerModel>> watchPlayersByTeam(String teamId) {
    return watchPlayersForTeam(teamId);
  }

  /// Primary squad stream: `teamId` field on player docs, then `teams.playerIds`.
  Stream<List<PlayerModel>> watchPlayersForTeam(String teamId) {
    return _col.where('teamId', isEqualTo: teamId).snapshots().asyncMap(
      (snap) async {
        final fromQuery =
            snap.docs.map((d) => PlayerModel.fromMap(d.id, d.data())).toList();

        if (fromQuery.isNotEmpty) {
          fromQuery.sort((a, b) => a.name.compareTo(b.name));
          return fromQuery;
        }

        return _playersFromTeamRoster(teamId);
      },
    );
  }

  Future<List<PlayerModel>> getPlayersByTeam(String teamId) async {
    final snap = await _col.where('teamId', isEqualTo: teamId).get();
    final list =
        snap.docs.map((d) => PlayerModel.fromMap(d.id, d.data())).toList();
    if (list.isNotEmpty) {
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    }
    return _playersFromTeamRoster(teamId);
  }

  Future<List<PlayerModel>> getPlayersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final results = <PlayerModel>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();
      final snap = await _col
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results.addAll(
        snap.docs.map((d) => PlayerModel.fromMap(d.id, d.data())),
      );
    }
    results.sort((a, b) => a.name.compareTo(b.name));
    return results;
  }

  Future<List<PlayerModel>> _playersFromTeamRoster(String teamId) async {
    final teamDoc = await _teams.doc(teamId).get();
    if (!teamDoc.exists) return [];

    final ids = List<String>.from(teamDoc.data()?['playerIds'] as List? ?? []);
    if (ids.isEmpty) return [];

    final players = await getPlayersByIds(ids);

    // Backfill teamId on legacy docs missing the field.
    for (final p in players) {
      if (p.teamId != teamId) {
        await _col.doc(p.id).set({'teamId': teamId}, SetOptions(merge: true));
      }
    }

    return players;
  }
}
