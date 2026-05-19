import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore signaling room for WebRTC (Phase 3.3 — media peer TBD).
class WebrtcRoomState {
  const WebrtcRoomState({
    required this.publisherId,
    required this.status,
    this.viewerCount = 0,
  });

  final String publisherId;
  final String status;
  final int viewerCount;

  factory WebrtcRoomState.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const WebrtcRoomState(publisherId: '', status: 'closed');
    }
    return WebrtcRoomState(
      publisherId: map['publisherId'] as String? ?? '',
      status: map['status'] as String? ?? 'closed',
      viewerCount: map['viewerCount'] as int? ?? 0,
    );
  }

  bool get isOpen => status == 'open' || status == 'live';
}

class WebrtcSignalingService {
  WebrtcSignalingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _room(String matchId) =>
      _firestore.collection('matches').doc(matchId).collection('webrtc').doc('room');

  Future<void> openRoom({
    required String matchId,
    required String publisherId,
  }) async {
    await _room(matchId).set({
      'publisherId': publisherId,
      'status': 'open',
      'viewerCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> closeRoom(String matchId) async {
    await _room(matchId).set({
      'status': 'closed',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> registerViewer(String matchId) async {
    await _room(matchId).update({
      'viewerCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<WebrtcRoomState?> watchRoom(String matchId) {
    return _room(matchId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return WebrtcRoomState.fromMap(doc.data());
    });
  }
}
