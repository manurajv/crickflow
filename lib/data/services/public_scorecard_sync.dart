import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_model.dart';
import '../models/overlay_state_model.dart';

/// Writes a sanitized public scorecard (no stream keys) for web viewers.
class PublicScorecardSync {
  PublicScorecardSync({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _ref(String matchId) =>
      _firestore.collection('matches').doc(matchId).collection('public').doc('scorecard');

  Future<void> syncFromMatch(
    MatchModel match, {
    OverlayStateModel? overlay,
  }) async {
    final data = <String, dynamic>{
      'matchId': match.id,
      'title': match.title,
      'status': match.status.name,
      'teamAName': match.teamAName,
      'teamBName': match.teamBName,
      'venue': match.venue,
      'location': match.location.toMap(),
      'rules': {'ballsPerOver': match.rules.ballsPerOver},
      'innings': match.innings.map((inn) => inn.toMap()).toList(),
      'stream': {
        'status': match.stream.status.name,
        if (match.stream.youtubeWatchUrl != null)
          'youtubeWatchUrl': match.stream.youtubeWatchUrl,
        if (match.stream.secondaryYoutubeWatchUrl != null)
          'secondaryYoutubeWatchUrl': match.stream.secondaryYoutubeWatchUrl,
        'cameraALabel': match.stream.cameraALabel,
        'cameraBLabel': match.stream.cameraBLabel,
        if (match.stream.startedAt != null)
          'startedAt': match.stream.startedAt!.toIso8601String(),
        'webrtcEnabled': match.stream.webrtcEnabled,
      },
      'resultSummary': match.resultSummary,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (overlay != null) {
      data['overlay'] = overlay.toMap();
    }
    await _ref(match.id).set(data, SetOptions(merge: true));
  }
}
