import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/series/series.dart';

class SeriesRankingRepository {
  SeriesRankingRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<SeriesClubRankingModel>> watchClubRankings(
    String seriesId, {
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(AppConstants.seriesClubRankingsCollection)
        .where('seriesId', isEqualTo: seriesId)
        .orderBy('points', descending: true)
        .orderBy('netRunRate', descending: true);
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => SeriesClubRankingModel.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Stream<List<SeriesPlayerRankingModel>> watchPlayerRankings(
    String seriesId, {
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(AppConstants.seriesPlayerRankingsCollection)
        .where('seriesId', isEqualTo: seriesId)
        .orderBy('runs', descending: true);
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => SeriesPlayerRankingModel.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }
}
