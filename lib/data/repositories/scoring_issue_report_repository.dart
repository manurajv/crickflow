import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// Scorer-facing issue reports from Need Help → Facing Problem.
class ScoringIssueReportRepository {
  ScoringIssueReportRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('scoringIssueReports');

  Future<void> submitReport({
    required String matchId,
    required String reportedBy,
    required String issueType,
    required String description,
  }) async {
    await _reports.doc(_uuid.v4()).set({
      'matchId': matchId,
      'reportedBy': reportedBy,
      'issueType': issueType,
      'description': description,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}
