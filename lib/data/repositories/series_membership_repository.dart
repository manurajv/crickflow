import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/series/series.dart';

class SeriesMembershipRepository {
  SeriesMembershipRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _memberships =>
      _firestore.collection(AppConstants.seriesMembershipsCollection);

  Stream<List<SeriesMembershipModel>> watchMembershipsForClub({
    required String seriesId,
    required String clubId,
  }) {
    return _memberships
        .where('seriesId', isEqualTo: seriesId)
        .where('clubId', isEqualTo: clubId)
        .snapshots()
        .map(_fromSnapshot);
  }

  Stream<List<SeriesMembershipModel>> watchMembershipsForUser(
    String userId, {
    String? seriesId,
  }) {
    Query<Map<String, dynamic>> query = _memberships.where(
      'userId',
      isEqualTo: userId,
    );
    if (seriesId != null) {
      query = query.where('seriesId', isEqualTo: seriesId);
    }
    return query.snapshots().map(_fromSnapshot);
  }

  Future<int> getActiveSquadCount({
    required String seriesId,
    required String clubId,
  }) async {
    final aggregate = await _memberships
        .where('seriesId', isEqualTo: seriesId)
        .where('clubId', isEqualTo: clubId)
        .where('status', isEqualTo: SeriesMembershipStatus.active.name)
        .count()
        .get();
    return aggregate.count ?? 0;
  }

  List<SeriesMembershipModel> _fromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) => SeriesMembershipModel.fromMap(doc.id, doc.data()))
        .toList();
  }
}
