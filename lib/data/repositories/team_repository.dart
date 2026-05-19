import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../models/team_model.dart';

class TeamRepository {
  TeamRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.teamsCollection);

  Future<String> createTeam(TeamModel team) async {
    final id = team.id.isEmpty ? _uuid.v4() : team.id;
    await _col.doc(id).set(team.toMap());
    return id;
  }

  Future<void> updateTeam(TeamModel team) async {
    await _col.doc(team.id).update(team.toMap());
  }

  Future<TeamModel?> getTeam(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return TeamModel.fromMap(doc.id, doc.data()!);
  }

  Stream<List<TeamModel>> watchTeams({String? createdBy}) {
    Query<Map<String, dynamic>> query =
        _col.orderBy('createdAt', descending: true);
    if (createdBy != null) {
      query = query.where('createdBy', isEqualTo: createdBy);
    }
    return query.snapshots().map((snap) =>
        snap.docs.map((d) => TeamModel.fromMap(d.id, d.data())).toList());
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
}
