import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/series/series.dart';

class SeriesCompetitionRepository {
  SeriesCompetitionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _competitions =>
      _firestore.collection(AppConstants.seriesCompetitionsCollection);

  Stream<List<SeriesCompetitionModel>> watchCompetitions(String seriesId) {
    return _competitions
        .where('seriesId', isEqualTo: seriesId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SeriesCompetitionModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<SeriesCompetitionModel> createDraftCompetition(
    SeriesCompetitionModel competition,
  ) async {
    final ref = competition.id.isEmpty
        ? _competitions.doc()
        : _competitions.doc(competition.id);
    final now = DateTime.now();
    final data = competition.toMap()
      ..remove('approvedAt')
      ..remove('approvedBy')
      ..addAll({
        'status': SeriesOfficialStatus.draft.name,
        'createdAt': (competition.createdAt ?? now).toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
    await ref.set(data);
    return SeriesCompetitionModel.fromMap(ref.id, data);
  }

  Future<void> linkMatch({
    required String competitionId,
    required String matchId,
  }) {
    return _competitions.doc(competitionId).update({
      'matchId': matchId,
      'type': SeriesCompetitionType.singleMatch.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> linkTournament({
    required String competitionId,
    required String tournamentId,
  }) {
    return _competitions.doc(competitionId).update({
      'tournamentId': tournamentId,
      'type': SeriesCompetitionType.tournament.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
