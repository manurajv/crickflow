import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/atomic_create.dart';
import '../../core/utils/cf_team_id_format.dart';
import '../models/owner_player_seed.dart';
import '../models/team_model.dart';
import '../services/team_qr_service.dart';

class TeamRepository {
  TeamRepository({FirebaseFirestore? firestore, TeamQrService? qrService})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _uuid = const Uuid(),
      _qrService = qrService ?? TeamQrService();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;
  final TeamQrService _qrService;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.teamsCollection);

  DocumentReference<Map<String, dynamic>> get _teamCodeCounter =>
      _firestore.collection('app_meta').doc('cf_team_ids');

  /// Allocates the next TM-prefixed public team code (transaction-safe).
  Future<String?> allocateTeamCode() async {
    try {
      return await _firestore.runTransaction((tx) async {
        final snap = await tx.get(_teamCodeCounter);
        final last = snap.data()?['lastNumber'] as int? ?? 0;
        final next = last + 1;
        tx.set(_teamCodeCounter, {
          'lastNumber': next,
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
        return CfTeamIdFormat.format(next);
      });
    } on FirebaseException catch (e) {
      debugPrint('allocateTeamCode skipped: ${e.code}');
      return null;
    } catch (e) {
      debugPrint('allocateTeamCode skipped: $e');
      return null;
    }
  }

  Future<String?> _generateAndPersistQr({
    required String teamId,
    required String? teamCode,
  }) async {
    try {
      final qrUrl = await _qrService.generateAndUploadTeamQr(
        teamId: teamId,
        teamCode: teamCode,
      );
      await _col.doc(teamId).update({
        'qrUrl': qrUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return qrUrl;
    } catch (e) {
      debugPrint('team QR generation failed: $e');
      return null;
    }
  }

  Future<TeamModel> createTeam(TeamModel team) async {
    final id = team.id.isEmpty ? _uuid.v4() : team.id;
    var teamCode = team.teamCode;
    if (teamCode == null || teamCode.isEmpty) {
      final allocated = await allocateTeamCode();
      if (allocated == null) {
        throw Exception(
          'Could not generate Team ID. Check your connection and try again.',
        );
      }
      teamCode = allocated;
    }

    var saved = TeamModel(
      id: id,
      teamCode: teamCode,
      name: team.name,
      logoUrl: team.logoUrl,
      captainId: team.captainId,
      viceCaptainId: team.viceCaptainId,
      coachName: team.coachName,
      contactNumber: team.contactNumber,
      playerIds: team.playerIds,
      memberCount: team.playerIds.length,
      location: team.location,
      stats: team.stats,
      badgeIds: team.badgeIds,
      createdBy: team.createdBy,
      createdAt: team.createdAt ?? DateTime.now(),
    );

    await _col.doc(id).set(saved.toMap());

    final qrUrl = await _generateAndPersistQr(teamId: id, teamCode: teamCode);
    if (qrUrl != null) {
      saved = TeamModel(
        id: saved.id,
        teamCode: saved.teamCode,
        qrUrl: qrUrl,
        name: saved.name,
        logoUrl: saved.logoUrl,
        captainId: saved.captainId,
        viceCaptainId: saved.viceCaptainId,
        coachName: saved.coachName,
        contactNumber: saved.contactNumber,
        playerIds: saved.playerIds,
        location: saved.location,
        stats: saved.stats,
        badgeIds: saved.badgeIds,
        createdBy: saved.createdBy,
        createdAt: saved.createdAt,
      );
    }

    return saved;
  }

  /// All-or-nothing team create (t43).
  ///
  /// The logo is uploaded first; then the team doc and the creator's player
  /// membership are written in ONE batch. If anything fails, the batch is
  /// never applied and the uploaded logo is deleted, so a failed create leaves
  /// no team doc, no roster change and no image behind. The invite QR is
  /// generated after commit and is optional (backfilled by [ensureTeamQr]).
  Future<TeamModel> createTeamAtomic({
    required TeamModel team,
    required String ownerUid,
    OwnerPlayerSeed? ownerPlayer,
    Future<UploadedAsset> Function(String teamId)? uploadLogo,
  }) async {
    final id = team.id.isEmpty ? _uuid.v4() : team.id;
    final existing = await _col.doc(id).get();
    if (existing.exists) {
      throw AtomicCreateException(
        'This team was already created. Open it from My teams.',
      );
    }
    var teamCode = team.teamCode;
    if (teamCode == null || teamCode.isEmpty) {
      teamCode = await allocateTeamCode();
      if (teamCode == null) {
        throw AtomicCreateException(
          'Could not generate Team ID. Check your connection and try again.',
        );
      }
    }
    final code = teamCode;

    final saved = await runAtomicCreate<TeamModel>(
      uploads: {
        if (uploadLogo != null) 'logo': () => uploadLogo(id),
      },
      commit: (urls) async {
        final logoUrl = urls['logo'] ?? team.profileImageUrl;
        final now = DateTime.now().toIso8601String();
        final batch = _firestore.batch();

        final playerIds = <String>[...team.playerIds];
        var captainId = team.captainId;
        if (ownerPlayer != null) {
          if (!playerIds.contains(ownerPlayer.playerId)) {
            playerIds.add(ownerPlayer.playerId);
          }
          captainId ??= ownerPlayer.playerId;
          final playerRef = _firestore
              .collection(AppConstants.playersCollection)
              .doc(ownerPlayer.playerId);
          final membership = <String, dynamic>{
            'teamId': id,
            'rosterChangeTeamId': id,
            'teamJoinedAt': now,
            'updatedAt': now,
          };
          if (ownerPlayer.exists) {
            batch.set(
              playerRef,
              {
                ...membership,
                'teamIds': FieldValue.arrayUnion([id]),
                if (ownerPlayer.fullName != null &&
                    ownerPlayer.fullName!.isNotEmpty)
                  'fullName': ownerPlayer.fullName,
              },
              SetOptions(merge: true),
            );
          } else {
            batch.set(playerRef, {
              ...?ownerPlayer.newPlayerData,
              ...membership,
              'teamIds': [id],
            });
          }
        }

        final model = TeamModel(
          id: id,
          teamCode: code,
          name: team.name,
          logoUrl: logoUrl,
          teamProfileImageUrl: logoUrl,
          teamCoverImageUrl: team.teamCoverImageUrl,
          captainId: captainId,
          viceCaptainId: team.viceCaptainId,
          coachName: team.coachName,
          contactNumber: team.contactNumber,
          playerIds: playerIds,
          memberCount: playerIds.length,
          location: team.location,
          stats: team.stats,
          badgeIds: team.badgeIds,
          createdBy: ownerUid,
          createdAt: team.createdAt ?? DateTime.now(),
        );
        batch.set(_col.doc(id), model.toMap());
        await batch.commit();
        return model;
      },
    );

    final qrUrl = await _generateAndPersistQr(teamId: id, teamCode: code);
    return qrUrl == null ? saved : saved.copyWith(qrUrl: qrUrl);
  }

  /// Backfills invite QR for legacy teams missing [TeamModel.qrUrl].
  Future<TeamModel?> ensureTeamQr(TeamModel team) async {
    if (team.qrUrl != null && team.qrUrl!.isNotEmpty) return team;
    final qrUrl = await _generateAndPersistQr(
      teamId: team.id,
      teamCode: team.teamCode,
    );
    if (qrUrl == null) return team;
    return TeamModel(
      id: team.id,
      teamCode: team.teamCode,
      qrUrl: qrUrl,
      name: team.name,
      logoUrl: team.logoUrl,
      captainId: team.captainId,
      viceCaptainId: team.viceCaptainId,
      coachName: team.coachName,
      contactNumber: team.contactNumber,
      playerIds: team.playerIds,
      location: team.location,
      stats: team.stats,
      badgeIds: team.badgeIds,
      createdBy: team.createdBy,
      createdAt: team.createdAt,
    );
  }

  Future<void> updateTeam(TeamModel team) async {
    await _col.doc(team.id).update(team.toMap());
  }

  Future<TeamModel?> getTeam(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return TeamModel.fromMap(doc.id, doc.data()!);
  }

  /// Lookup by public team code (e.g. TM00042).
  Future<TeamModel?> getTeamByTeamCode(String teamCode) async {
    final normalized = CfTeamIdFormat.normalize(teamCode);
    final snap = await _col
        .where('teamCode', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return TeamModel.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  Stream<List<TeamModel>> watchTeams({String? createdBy}) {
    Query<Map<String, dynamic>> query = _col.orderBy(
      'createdAt',
      descending: true,
    );
    if (createdBy != null) {
      query = query.where('createdBy', isEqualTo: createdBy);
    }
    return query.snapshots().map(
      (snap) =>
          snap.docs.map((d) => TeamModel.fromMap(d.id, d.data())).toList(),
    );
  }

  Stream<TeamModel?> watchTeam(String id) {
    return _col.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return TeamModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<void> addPlayerToTeam({
    required String teamId,
    required String playerId,
  }) async {
    await _col.doc(teamId).update({
      'playerIds': FieldValue.arrayUnion([playerId]),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateCaptainRoles({
    required String teamId,
    String? captainId,
    String? viceCaptainId,
    bool clearCaptain = false,
    bool clearViceCaptain = false,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (clearCaptain) {
      updates['captainId'] = FieldValue.delete();
    } else if (captainId != null) {
      updates['captainId'] = captainId;
    }
    if (clearViceCaptain) {
      updates['viceCaptainId'] = FieldValue.delete();
    } else if (viceCaptainId != null) {
      updates['viceCaptainId'] = viceCaptainId;
    }
    await _col.doc(teamId).update(updates);
  }
}
