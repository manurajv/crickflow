import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/series/series.dart';
import '../services/series_functions_service.dart';

class SeriesRepository {
  SeriesRepository({
    FirebaseFirestore? firestore,
    SeriesFunctionsService? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? SeriesFunctionsService();

  final FirebaseFirestore _firestore;
  final SeriesFunctionsService _functions;

  CollectionReference<Map<String, dynamic>> get _series =>
      _firestore.collection(AppConstants.seriesCollection);
  CollectionReference<Map<String, dynamic>> get _admins =>
      _firestore.collection(AppConstants.seriesAdminsCollection);

  static String adminId(String seriesId, String userId) =>
      '${seriesId}_$userId';
  static String clubAdminId(String seriesId, String clubId, String userId) =>
      '${seriesId}_${clubId}_$userId';
  static String membershipId(String seriesId, String clubId, String userId) =>
      '${seriesId}_${clubId}_$userId';
  static String clubRankingId(String seriesId, String clubId) =>
      '${seriesId}_$clubId';
  static String playerRankingId(String seriesId, String userId) =>
      '${seriesId}_$userId';

  Stream<List<SeriesModel>> watchSeries() {
    return _series
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SeriesModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<SeriesModel>> listActiveSeries() {
    return _series
        .where('status', isEqualTo: SeriesStatus.active.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SeriesModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<SeriesModel?> watchSeriesById(String seriesId) {
    return _series.doc(seriesId).snapshots().map((doc) {
      final data = doc.data();
      return doc.exists && data != null
          ? SeriesModel.fromMap(doc.id, data)
          : null;
    });
  }

  Future<SeriesModel?> getSeries(String seriesId) async {
    final doc = await _series.doc(seriesId).get();
    final data = doc.data();
    return doc.exists && data != null
        ? SeriesModel.fromMap(doc.id, data)
        : null;
  }

  Stream<List<SeriesAdminModel>> watchSeriesAdmins(String seriesId) {
    return _admins
        .where('seriesId', isEqualTo: seriesId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SeriesAdminModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Creates a user-owned draft only; super-admin stamping uses [createSeries].
  Future<SeriesModel> createSeriesDraft(SeriesModel series) async {
    final ref = series.id.isEmpty ? _series.doc() : _series.doc(series.id);
    final now = DateTime.now();
    final data = series.toMap()
      ..remove('superAdminUserId')
      ..addAll({
        'status': SeriesStatus.draft.name,
        'createdAt': (series.createdAt ?? now).toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
    await ref.set(data);
    return SeriesModel.fromMap(ref.id, data);
  }

  /// Preferred creation path for an authoritative super-admin stamp.
  Future<Map<String, dynamic>> createSeries(SeriesModel series) {
    return _functions.createSeries({
      if (series.id.isNotEmpty) 'seriesId': series.id,
      ...series.toMap(),
    });
  }

  Future<Map<String, dynamic>> updateSeriesSettings({
    required String seriesId,
    required SeriesSettingsModel settings,
  }) {
    return _functions.updateSeriesSettings(
      seriesId: seriesId,
      settings: settings.toMap(),
    );
  }
}
