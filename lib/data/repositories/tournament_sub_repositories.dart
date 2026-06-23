import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/tournament/tournament_group_model.dart';
import '../../data/models/tournament/tournament_member_model.dart';
import '../../data/models/tournament/tournament_official_model.dart';
import '../../data/models/tournament/tournament_points_table_model.dart';
import '../../data/models/tournament/tournament_round_model.dart';
import '../../data/models/tournament/tournament_rules_model.dart';
import '../../data/models/tournament/tournament_sponsor_model.dart';

class TournamentGroupRepository {
  TournamentGroupRepository({FirebaseFirestore? firestore, Uuid? uuid})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.tournamentGroupsCollection);

  Future<String> createGroup(TournamentGroupModel group) async {
    final id = group.id.isEmpty ? _uuid.v4() : group.id;
    await _col.doc(id).set(group.toMap());
    return id;
  }

  Future<void> updateGroup(TournamentGroupModel group) async {
    await _col.doc(group.id).update(group.toMap());
  }

  Future<void> deleteGroup(String id) async {
    await _col.doc(id).delete();
  }

  Stream<List<TournamentGroupModel>> watchGroups(String tournamentId) {
    return _col
        .where('tournamentId', isEqualTo: tournamentId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TournamentGroupModel.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name)));
  }
}

class TournamentRoundRepository {
  TournamentRoundRepository({FirebaseFirestore? firestore, Uuid? uuid})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.tournamentRoundsCollection);

  Future<String> createRound(TournamentRoundModel round) async {
    final id = round.id.isEmpty ? _uuid.v4() : round.id;
    await _col.doc(id).set(round.toMap());
    return id;
  }

  Future<void> updateRound(TournamentRoundModel round) async {
    await _col.doc(round.id).update(round.toMap());
  }

  Stream<List<TournamentRoundModel>> watchRounds(String tournamentId) {
    return _col
        .where('tournamentId', isEqualTo: tournamentId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TournamentRoundModel.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));
  }
}

class TournamentMemberRepository {
  TournamentMemberRepository({FirebaseFirestore? firestore, Uuid? uuid})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.tournamentMembersCollection);

  Future<String> upsertMember(TournamentMemberModel member) async {
    final id = member.id.isEmpty ? _uuid.v4() : member.id;
    await _col.doc(id).set(member.toMap(), SetOptions(merge: true));
    return id;
  }

  Future<TournamentMemberModel?> getMemberForUser({
    required String tournamentId,
    required String userId,
  }) async {
    final snap = await _col
        .where('tournamentId', isEqualTo: tournamentId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return TournamentMemberModel.fromMap(doc.id, doc.data());
  }

  Stream<List<TournamentMemberModel>> watchMembers(String tournamentId) {
    return _col
        .where('tournamentId', isEqualTo: tournamentId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TournamentMemberModel.fromMap(d.id, d.data()))
            .toList());
  }
}

class TournamentOfficialRepository {
  TournamentOfficialRepository({FirebaseFirestore? firestore, Uuid? uuid})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.tournamentOfficialsCollection);

  Future<String> addOfficial(TournamentOfficialModel official) async {
    final id = official.id.isEmpty ? _uuid.v4() : official.id;
    await _col.doc(id).set(official.toMap());
    return id;
  }

  Future<void> removeOfficial(String id) async {
    await _col.doc(id).delete();
  }

  Stream<List<TournamentOfficialModel>> watchOfficials(String tournamentId) {
    return _col
        .where('tournamentId', isEqualTo: tournamentId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TournamentOfficialModel.fromMap(d.id, d.data()))
            .toList());
  }
}

class TournamentSponsorRepository {
  TournamentSponsorRepository({FirebaseFirestore? firestore, Uuid? uuid})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.tournamentSponsorsCollection);

  Future<String> addSponsor(TournamentSponsorModel sponsor) async {
    final id = sponsor.id.isEmpty ? _uuid.v4() : sponsor.id;
    await _col.doc(id).set(sponsor.toMap());
    return id;
  }

  Future<void> removeSponsor(String id) async {
    await _col.doc(id).delete();
  }

  Stream<List<TournamentSponsorModel>> watchSponsors(String tournamentId) {
    return _col
        .where('tournamentId', isEqualTo: tournamentId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TournamentSponsorModel.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));
  }
}

class TournamentRulesRepository {
  TournamentRulesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.tournamentRulesCollection);

  Future<void> saveRules({
    required String tournamentId,
    required TournamentRulesModel rules,
  }) async {
    await _col.doc(tournamentId).set({
      'tournamentId': tournamentId,
      ...rules.toMap(),
    }, SetOptions(merge: true));
  }

  Stream<TournamentRulesModel> watchRules(String tournamentId) {
    return _col.doc(tournamentId).snapshots().map((snap) {
      if (!snap.exists) return const TournamentRulesModel();
      return TournamentRulesModel.fromMap(snap.data());
    });
  }
}

class TournamentPointsTableRepository {
  TournamentPointsTableRepository({FirebaseFirestore? firestore, Uuid? uuid})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.tournamentPointsTablesCollection);

  Future<String> saveTable(TournamentPointsTableModel table) async {
    final id = table.id.isEmpty ? _uuid.v4() : table.id;
    await _col.doc(id).set(table.toMap());
    return id;
  }

  Stream<List<TournamentPointsTableModel>> watchTables(String tournamentId) {
    return _col
        .where('tournamentId', isEqualTo: tournamentId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TournamentPointsTableModel.fromMap(d.id, d.data()))
            .toList());
  }
}
