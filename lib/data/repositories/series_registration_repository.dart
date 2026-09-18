import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/series/series.dart';
import '../services/series_functions_service.dart';

class SeriesRegistrationRepository {
  SeriesRegistrationRepository({
    FirebaseFirestore? firestore,
    SeriesFunctionsService? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? SeriesFunctionsService();

  final FirebaseFirestore _firestore;
  final SeriesFunctionsService _functions;

  CollectionReference<Map<String, dynamic>> get _registrations =>
      _firestore.collection(AppConstants.seriesRegistrationsCollection);

  Stream<List<SeriesPlayerRegistrationModel>> watchRegistrations({
    required String seriesId,
    String? clubId,
    String? userId,
  }) {
    Query<Map<String, dynamic>> query = _registrations.where(
      'seriesId',
      isEqualTo: seriesId,
    );
    if (clubId != null) query = query.where('clubId', isEqualTo: clubId);
    if (userId != null) query = query.where('userId', isEqualTo: userId);
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    SeriesPlayerRegistrationModel.fromMap(doc.id, doc.data()),
              )
              .toList(),
        );
  }

  Future<SeriesPlayerRegistrationModel?> getRegistration(
    String registrationId,
  ) async {
    final doc = await _registrations.doc(registrationId).get();
    final data = doc.data();
    return doc.exists && data != null
        ? SeriesPlayerRegistrationModel.fromMap(doc.id, data)
        : null;
  }

  /// Sends PII only to the callable; the server stores identity privately.
  Future<Map<String, dynamic>> submitSeriesRegistration({
    required SeriesPlayerRegistrationModel registration,
    String? nationalId,
    String? passport,
  }) {
    return _functions.submitSeriesRegistration({
      if (registration.id.isNotEmpty) 'registrationId': registration.id,
      'registration': registration.toPublicMap(),
      'identity': {
        if (nationalId != null && nationalId.isNotEmpty)
          'nationalId': nationalId,
        if (passport != null && passport.isNotEmpty) 'passport': passport,
      },
    });
  }
}
