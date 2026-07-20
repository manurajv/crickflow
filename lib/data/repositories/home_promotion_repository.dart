import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/home_promotion_model.dart';

class HomePromotionRepository {
  HomePromotionRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('home_promotions');

  List<HomePromotionModel> _parse(QuerySnapshot<Map<String, dynamic>> snap) {
    final now = DateTime.now();
    return snap.docs
        .map(HomePromotionModel.fromDoc)
        .where((p) => p.expiresAt == null || p.expiresAt!.isAfter(now))
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// Active promotions ordered by priority (higher first). Cached by callers.
  Stream<List<HomePromotionModel>> watchActivePromotions({int limit = 20}) {
    return _col
        .where('active', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map(_parse)
        .transform(
          StreamTransformer<List<HomePromotionModel>,
              List<HomePromotionModel>>.fromHandlers(
            handleData: (data, sink) => sink.add(data),
            handleError: (error, stackTrace, sink) {
              // Rules not deployed / denied — empty carousel, no crash.
              sink.add(const <HomePromotionModel>[]);
            },
          ),
        );
  }

  Future<List<HomePromotionModel>> fetchActivePromotions({int limit = 20}) async {
    try {
      final snap =
          await _col.where('active', isEqualTo: true).limit(limit).get();
      return _parse(snap);
    } catch (_) {
      return const [];
    }
  }
}
