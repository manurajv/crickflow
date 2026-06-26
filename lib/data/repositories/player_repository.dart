import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/cf_player_id_format.dart';
import '../../core/utils/team_leadership_utils.dart';
import '../models/player_model.dart';
import '../models/team_model.dart';
import 'notification_repository.dart';

class PlayerRepository {
  PlayerRepository({
    FirebaseFirestore? firestore,
    NotificationRepository? notificationRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _notificationRepository = notificationRepository,
       _uuid = const Uuid();

  final FirebaseFirestore _firestore;
  final NotificationRepository? _notificationRepository;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.playersCollection);

  CollectionReference<Map<String, dynamic>> get _teams =>
      _firestore.collection(AppConstants.teamsCollection);

  CollectionReference<Map<String, dynamic>> _joinRequests(String teamId) =>
      _teams.doc(teamId).collection(AppConstants.teamJoinRequestsSubcollection);

  Future<String> createPlayer(PlayerModel player) async {
    final id = player.id.isEmpty ? _uuid.v4() : player.id;
    final data = player.toMap();
    if (player.teamIds.isNotEmpty) {
      data['teamIds'] = player.teamIds;
    } else if (player.teamId != null) {
      data['teamId'] = player.teamId;
    }
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
      if (player != null) {
        if (player.userId == null || player.userId!.isEmpty) return [];
        if (alreadyOnSquadIds.contains(player.id)) return [];
        if (player.isOnTeam(excludeTeamId)) return [];
        return [player];
      }
    }

    final snap = await _col.orderBy('name').limit(300).get();
    final qLower = q.toLowerCase();
    final qUpper = CfPlayerIdFormat.normalize(q);

    final list = snap.docs
        .map((d) => PlayerModel.fromMap(d.id, d.data()))
        .where((p) {
          final uid = p.userId;
          if (uid == null || uid.isEmpty) return false;
          if (alreadyOnSquadIds.contains(p.id)) return false;
          if (p.isOnTeam(excludeTeamId)) return false;
          if (q.isEmpty) return true;
          if (p.name.toLowerCase().contains(qLower)) return true;
          if (p.fullName.toLowerCase().contains(qLower)) return true;
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

  /// Directory search for match officials — name, full name, or public Player ID.
  Future<List<PlayerModel>> searchPlayersDirectory({String query = ''}) async {
    final q = query.trim();
    if (q.isNotEmpty && CfPlayerIdFormat.looksLikeCfPlayerId(q)) {
      final player = await getPlayerByPublicId(q);
      return player == null ? [] : [player];
    }

    final snap = await _col.orderBy('name').limit(300).get();
    final qLower = q.toLowerCase();
    final qUpper = CfPlayerIdFormat.normalize(q);

    final list = snap.docs.map((d) => PlayerModel.fromMap(d.id, d.data())).where((p) {
      if (q.isEmpty) return true;
      if (p.name.toLowerCase().contains(qLower)) return true;
      if (p.fullName.toLowerCase().contains(qLower)) return true;
      if (p.playerId != null && p.playerId!.toUpperCase().contains(qUpper)) {
        return true;
      }
      return false;
    }).toList();

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
    String? addedByUserId,
    bool notifyPlayer = true,
  }) async {
    var wasNewAssignment = false;

    await _firestore.runTransaction((tx) async {
      final teamRef = _teams.doc(teamId);
      final playerRef = _col.doc(playerId);
      final teamSnap = await tx.get(teamRef);
      if (!teamSnap.exists) throw Exception('Team not found');

      final teamData = teamSnap.data()!;
      final currentIds = List<String>.from(teamData['playerIds'] as List? ?? []);

      final existing = await tx.get(playerRef);
      final existingData = existing.data();
      final alreadyOnTeam =
          existing.exists && _playerIsOnTeam(existingData, teamId);

      if (!currentIds.contains(playerId)) {
        currentIds.add(playerId);
        wasNewAssignment = true;
      } else if (!alreadyOnTeam) {
        wasNewAssignment = true;
      }

      // Always sync `teamIds` — legacy `teamId`-only docs are invisible to
      // watchPlayersForTeam's arrayContains query when other members exist.
      final playerPayload = <String, dynamic>{
        'teamIds': FieldValue.arrayUnion([teamId]),
        'teamId': teamId,
        'rosterChangeTeamId': teamId,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (!alreadyOnTeam) {
        playerPayload['teamJoinedAt'] = DateTime.now().toIso8601String();
      }

      if (existing.exists) {
        tx.update(playerRef, playerPayload);
      } else {
        tx.set(playerRef, playerPayload, SetOptions(merge: true));
      }

      tx.update(teamRef, {
        'playerIds': currentIds,
        'memberCount': currentIds.length,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    });

    if (!notifyPlayer || !wasNewAssignment) return;

    final player = await getPlayer(playerId);
    final targetUid = player?.userId;
    if (targetUid == null || targetUid.isEmpty) return;
    if (addedByUserId != null && targetUid == addedByUserId) return;

    final teamSnap = await _teams.doc(teamId).get();
    final teamName = teamSnap.data()?['name'] as String? ?? 'your team';

    await _notificationRepository?.createNotification(
      userId: targetUid,
      title: 'Added to team',
      body: 'You were added to $teamName.',
      teamId: teamId,
      playerId: playerId,
      type: 'team_member_added',
      addedByUserId: addedByUserId,
    );
  }

  /// Removes a player from a team roster (leave team). Handles owner transfer
  /// or full team deletion when the owner is the sole member.
  ///
  /// Returns `true` when the team document was deleted.
  Future<bool> leaveTeam({
    required String teamId,
    required PlayerModel leavingPlayer,
    required List<PlayerModel> squad,
  }) async {
    final leavingId = leavingPlayer.id;
    final others = squad.where((p) => p.id != leavingId).toList()
      ..sort((a, b) => a.effectiveJoinedAt.compareTo(b.effectiveJoinedAt));

    final joinRequestRefs = others.isEmpty
        ? (await _joinRequests(teamId).get()).docs.map((d) => d.reference).toList()
        : <DocumentReference<Map<String, dynamic>>>[];

    var teamDeleted = false;

    try {
      await _firestore.runTransaction((tx) async {
        final teamRef = _teams.doc(teamId);
        final playerRef = _col.doc(leavingId);

        // READ phase — all tx.get calls before any writes.
        final teamSnap = await tx.get(teamRef);
        final playerSnap = await tx.get(playerRef);
        final joinRequestSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final ref in joinRequestRefs) {
          joinRequestSnaps.add(await tx.get(ref));
        }

        if (!teamSnap.exists) throw Exception('Team not found');

        final teamData = teamSnap.data()!;
        final createdBy = teamData['createdBy'] as String?;
        final ownerUid = leavingPlayer.userId ?? leavingPlayer.id;
        final isOwner =
            createdBy != null && createdBy.isNotEmpty && createdBy == ownerUid;

        final removeFromRoster = <String>{
          leavingId,
          if (leavingPlayer.userId != null && leavingPlayer.userId!.isNotEmpty)
            leavingPlayer.userId!,
        };

        final updatedIds = List<String>.from(
          teamData['playerIds'] as List? ?? [],
        )..removeWhere((id) => removeFromRoster.contains(id));

        final playerUpdates = _playerLeaveUpdates(
          playerSnap: playerSnap,
          teamId: teamId,
        );

        // WRITE phase — owner is sole member: delete team + join requests.
        if (isOwner && others.isEmpty) {
          for (final snap in joinRequestSnaps) {
            if (snap.exists) {
              tx.delete(snap.reference);
            }
          }
          tx.delete(teamRef);
          if (playerSnap.exists) {
            tx.update(playerRef, playerUpdates);
          }
          teamDeleted = true;
          return;
        }

        final teamUpdates = <String, dynamic>{
          'playerIds': updatedIds,
          'memberCount': updatedIds.length,
          'updatedAt': DateTime.now().toIso8601String(),
        };

        if (teamData['captainId'] == leavingId) {
          teamUpdates['captainId'] = FieldValue.delete();
        }
        if (teamData['viceCaptainId'] == leavingId) {
          teamUpdates['viceCaptainId'] = FieldValue.delete();
        }

        if (isOwner) {
          final team = TeamModel.fromMap(teamId, teamData);
          final nextOwner = TeamLeadershipUtils.pickNextOwner(team, others);
          if (nextOwner == null) {
            throw Exception('No eligible member to transfer ownership');
          }
          teamUpdates['createdBy'] = nextOwner.userId ?? nextOwner.id;
        }

        tx.update(teamRef, teamUpdates);
        if (playerSnap.exists) {
          tx.update(playerRef, playerUpdates);
        }
      });
    } catch (e, st) {
      debugPrint('leaveTeam failed: $e\n$st');
      rethrow;
    }

    if (teamDeleted) {
      await _notificationRepository?.deleteNotificationsForTeam(teamId);
    }

    return teamDeleted;
  }

  /// Owner removes another player from the roster.
  Future<void> removePlayerFromTeamByOwner({
    required String teamId,
    required String playerId,
    String? teamName,
  }) async {
    final preRead = await _col.doc(playerId).get();
    final targetUserId = preRead.data()?['userId'] as String? ?? playerId;

    try {
      await _firestore.runTransaction((tx) async {
        final teamRef = _teams.doc(teamId);
        final playerRef = _col.doc(playerId);

        // READ phase
        final teamSnap = await tx.get(teamRef);
        final playerSnap = await tx.get(playerRef);

        if (!teamSnap.exists) throw Exception('Team not found');

        final teamData = teamSnap.data()!;
        final currentIds = List<String>.from(teamData['playerIds'] as List? ?? [])
          ..remove(playerId);

        final updates = <String, dynamic>{
          'playerIds': currentIds,
          'memberCount': currentIds.length,
          'updatedAt': DateTime.now().toIso8601String(),
        };
        if (teamData['captainId'] == playerId) {
          updates['captainId'] = FieldValue.delete();
        }
        if (teamData['viceCaptainId'] == playerId) {
          updates['viceCaptainId'] = FieldValue.delete();
        }

        final playerUpdates = _playerLeaveUpdates(
          playerSnap: playerSnap,
          teamId: teamId,
        );

        // WRITE phase
        tx.update(teamRef, updates);
        if (playerSnap.exists) {
          tx.update(playerRef, playerUpdates);
        }
      });
    } catch (e, st) {
      debugPrint('removePlayerFromTeamByOwner failed: $e\n$st');
      rethrow;
    }

    final name = teamName ?? 'your team';
    await _notificationRepository?.createNotification(
      userId: targetUserId,
      title: 'Removed from team',
      body: 'You have been removed from $name.',
      teamId: teamId,
      type: 'team_member_removed',
    );
  }

  /// @deprecated Use [leaveTeam].
  Future<void> removePlayerFromTeam({
    required String playerId,
    required String teamId,
  }) async {
    final player = await getPlayer(playerId);
    if (player == null) return;
    final squad = await getPlayersByTeam(teamId);
    await leaveTeam(teamId: teamId, leavingPlayer: player, squad: squad);
  }

  /// Lookup player doc by public player ID.
  Future<PlayerModel?> getPlayerByPublicId(String playerId) async {
    final normalized = CfPlayerIdFormat.normalize(playerId);
    final snap = await _col
        .where('playerId', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return PlayerModel.fromMap(doc.id, doc.data());
  }

  /// Links auth user to a player doc (used when role is `player`). Doc id = [userId].
  Future<PlayerModel> ensurePlayerProfileForUser({
    required String userId,
    required String displayName,
    String? fullName,
    String? photoUrl,
    String? email,
    String? playerId,
  }) async {
    final existing = await _col.doc(userId).get();
    if (existing.exists) {
      final merge = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (playerId != null && playerId.isNotEmpty) {
        merge['playerId'] = playerId;
      }
      if (fullName != null && fullName.isNotEmpty) {
        merge['fullName'] = fullName;
      }
      if (merge.length > 1) {
        await _col.doc(userId).set(merge, SetOptions(merge: true));
      }
      final refreshed = await _col.doc(userId).get();
      return PlayerModel.fromMap(userId, refreshed.data()!);
    }

    final player = PlayerModel(
      id: userId,
      name: displayName.isNotEmpty ? displayName : 'Player',
      fullName: fullName ?? '',
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

  /// Primary squad stream: `teamIds` on player docs, then `teams.playerIds`.
  Stream<List<PlayerModel>> watchPlayersForTeam(String teamId) {
    return _col
        .where('teamIds', arrayContains: teamId)
        .snapshots()
        .asyncMap((snap) async {
      final fromQuery = snap.docs
          .map((d) => PlayerModel.fromMap(d.id, d.data()))
          .toList();

      final fromRoster = await _playersFromTeamRoster(teamId);
      final byId = <String, PlayerModel>{
        for (final p in fromQuery) p.id: p,
        for (final p in fromRoster) p.id: p,
      };
      final merged = byId.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return merged;
    });
  }

  Future<List<PlayerModel>> getPlayersByTeam(String teamId) async {
    final snap = await _col.where('teamIds', arrayContains: teamId).get();
    final list = snap.docs
        .map((d) => PlayerModel.fromMap(d.id, d.data()))
        .toList();
    if (list.isNotEmpty) {
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    }

    final legacySnap = await _col.where('teamId', isEqualTo: teamId).get();
    final legacyList = legacySnap.docs
        .map((d) => PlayerModel.fromMap(d.id, d.data()))
        .toList();
    if (legacyList.isNotEmpty) {
      legacyList.sort((a, b) => a.name.compareTo(b.name));
      return legacyList;
    }

    return _playersFromTeamRoster(teamId);
  }

  Future<List<PlayerModel>> getPlayersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final results = <PlayerModel>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();
      final snap = await _col.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(snap.docs.map((d) => PlayerModel.fromMap(d.id, d.data())));
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

    // Backfill teamIds on legacy docs missing the array.
    for (final p in players) {
      if (!p.isOnTeam(teamId)) {
        await _col.doc(p.id).set({
          'teamIds': FieldValue.arrayUnion([teamId]),
          'teamId': p.teamId ?? teamId,
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }
    }

    return players;
  }

  static Map<String, dynamic> _playerLeaveUpdates({
    required DocumentSnapshot<Map<String, dynamic>> playerSnap,
    required String teamId,
  }) {
    final remainingTeamIds = _playerEffectiveTeamIds(playerSnap.data())
      ..remove(teamId);
    final playerUpdates = <String, dynamic>{
      'teamIds': FieldValue.arrayRemove([teamId]),
      'rosterChangeTeamId': teamId,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (playerSnap.data()?['teamId'] == teamId) {
      if (remainingTeamIds.isEmpty) {
        playerUpdates['teamId'] = FieldValue.delete();
        playerUpdates['teamJoinedAt'] = FieldValue.delete();
      } else {
        playerUpdates['teamId'] = remainingTeamIds.last;
      }
    }
    return playerUpdates;
  }

  static List<String> _playerEffectiveTeamIds(Map<String, dynamic>? data) {
    if (data == null) return [];
    final fromList = List<String>.from(data['teamIds'] as List? ?? []);
    if (fromList.isNotEmpty) return fromList;
    final legacy = data['teamId'] as String?;
    if (legacy != null && legacy.isNotEmpty) return [legacy];
    return [];
  }

  static bool _playerIsOnTeam(Map<String, dynamic>? data, String teamId) {
    return _playerEffectiveTeamIds(data).contains(teamId);
  }
}
