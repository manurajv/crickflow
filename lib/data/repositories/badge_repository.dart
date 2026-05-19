import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../models/badge_model.dart';

class BadgeRepository {
  BadgeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.badgesCollection);

  Future<List<BadgeModel>> getBadgesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final unique = ids.toSet().take(20).toList();
    final results = <BadgeModel>[];

    for (var i = 0; i < unique.length; i += 10) {
      final chunk = unique.skip(i).take(10).toList();
      final snap = await _col.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(
        snap.docs.map((d) => BadgeModel.fromMap(d.id, d.data())),
      );
    }

    results.sort((a, b) {
      final ai = ids.indexOf(a.id);
      final bi = ids.indexOf(b.id);
      return ai.compareTo(bi);
    });
    return results;
  }
}
