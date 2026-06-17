import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../models/team_roster_report_model.dart';

class TeamRosterReportRepository {
  TeamRosterReportRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.teamRosterReportsCollection);

  Future<bool> hasPendingReport({
    required String reporterUserId,
    required String teamId,
    required String playerId,
  }) async {
    final snap = await _col
        .where('reporterUserId', isEqualTo: reporterUserId)
        .where('teamId', isEqualTo: teamId)
        .where('playerId', isEqualTo: playerId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<String> submitReport({
    required String reporterUserId,
    required String reporterName,
    required String teamId,
    required String teamName,
    required String playerId,
    String? addedByUserId,
    String? message,
  }) async {
    final existing = await hasPendingReport(
      reporterUserId: reporterUserId,
      teamId: teamId,
      playerId: playerId,
    );
    if (existing) {
      throw StateError('You already have a pending report for this team.');
    }

    final id = _uuid.v4();
    final report = TeamRosterReportModel(
      id: id,
      reporterUserId: reporterUserId,
      reporterName: reporterName,
      teamId: teamId,
      teamName: teamName,
      playerId: playerId,
      addedByUserId: addedByUserId,
      message: message?.trim(),
    );
    await _col.doc(id).set(report.toMap());
    return id;
  }
}
