import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/cf_player_id_format.dart';
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

  Future<void> deletePlayer(String playerId) async {
    await _col.doc(playerId).delete();
  }

  Future<PlayerModel?> getPlayer(String playerId) async {
    final doc = await _col.doc(playerId).get();
    if (!doc.exists) return null;
    return PlayerModel.fromMap(doc.id, doc.data()!);
  }

  Future<PlayerModel?> getPlayerByUserId(String userId) async {
    final doc = await _col.doc(userId).get();
    if (!doc.exists) return null;
    return PlayerModel.fromMap(doc.id, doc.data()!);
  }

  /// Players not on [excludeTeamId] (for squad picker). Name or Player ID filter.
  Future<List<PlayerModel>> searchAvailablePlayers({
    required String excludeTeamId,
    required Set<String> alreadyOnSquadIds,
    String query = '',
  }) async {
    final q = query.trim();
    if (q.isNotEmpty && CfPlayerIdFormat.looksLikeCfPlayerId(q)) {
      final player = await getPlayerByPublicId(q);
      if (player == null) return [];
      if (alreadyOnSquadIds.contains(player.id)) return [];
      if (player.teamId == excludeTeamId) return [];
      return [player];
    }

    final snap = await _col.orderBy('name').limit(300).get();
    final qLower = q.toLowerCase();
    final qUpper = CfPlayerIdFormat.normalize(q);

    final list = snap.docs
        .map((d) => PlayerModel.fromMap(d.id, d.data()))
        .where((p) {
          if (alreadyOnSquadIds.contains(p.id)) return false;
          if (p.teamId == excludeTeamId) return false;
          if (q.isEmpty) return true;
          if (p.name.toLowerCase().contains(qLower)) return true;
          if (p.playerId != null &&
              p.playerId!.toUpperCase().contains(qUpper)) {
            return true;
          }
          return false;
        })
        .toList();

    list.sort((a, b) {
      if (q.isNotEmpty) {
        final aName = a.name.toLowerCase().startsWith(qLower);
        final bName = b.name.toLowerCase().startsWith(qLower);
        if (aName != bName) return aName ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });
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

  /// Lookup player doc by public player ID.
  Future<PlayerModel?> getPlayerByPublicId(String playerId) async {
    final normalized = CfPlayerIdFormat.normalize(playerId);
    final snap = await _col.where('playerId', isEqualTo: normalized).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return PlayerModel.fromMap(doc.id, doc.data());
  }

  /// Links auth user to a player doc (used when role is `player`). Doc id = [userId].
  Future<PlayerModel> ensurePlayerProfileForUser({
    required String userId,
    required String displayName,
    String? photoUrl,
    String? email,
    String? playerId,
  }) async {
    final existing = await _col.doc(userId).get();
    if (existing.exists) {
      if (playerId != null && playerId.isNotEmpty) {
        await _col.doc(userId).set(
          {'playerId': playerId, 'updatedAt': DateTime.now().toIso8601String()},
          SetOptions(merge: true),
        );
      }
      final refreshed = await _col.doc(userId).get();
      return PlayerModel.fromMap(userId, refreshed.data()!);
    }

    final player = PlayerModel(
      id: userId,
      name: displayName.isNotEmpty ? displayName : 'Player',
      userId: userId,
      playerId: playerId,
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
