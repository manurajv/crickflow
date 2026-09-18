import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/series/series.dart';

class SeriesClubRepository {
  SeriesClubRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _clubs =>
      _firestore.collection(AppConstants.seriesClubsCollection);
  CollectionReference<Map<String, dynamic>> get _admins =>
      _firestore.collection(AppConstants.seriesClubAdminsCollection);

  Stream<List<SeriesClubModel>> watchClubsForSeries(String seriesId) {
    return _clubs
        .where('seriesId', isEqualTo: seriesId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SeriesClubModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<SeriesClubModel?> getClub(String clubId) async {
    final doc = await _clubs.doc(clubId).get();
    final data = doc.data();
    return doc.exists && data != null
        ? SeriesClubModel.fromMap(doc.id, data)
        : null;
  }

  /// Creates only an unprivileged pending club application.
  Future<SeriesClubModel> createClubPending(SeriesClubModel club) async {
    final ref = club.id.isEmpty ? _clubs.doc() : _clubs.doc(club.id);
    final now = DateTime.now();
    final data = club.toMap()
      ..addAll({
        'status': SeriesClubStatus.pending.name,
        'createdAt': (club.createdAt ?? now).toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
    await ref.set(data);
    return SeriesClubModel.fromMap(ref.id, data);
  }

  Stream<List<SeriesClubAdminModel>> watchClubAdmins({
    required String seriesId,
    String? clubId,
  }) {
    Query<Map<String, dynamic>> query = _admins.where(
      'seriesId',
      isEqualTo: seriesId,
    );
    if (clubId != null) query = query.where('clubId', isEqualTo: clubId);
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => SeriesClubAdminModel.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }
}
