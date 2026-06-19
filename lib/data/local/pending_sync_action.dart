import 'dart:convert';

/// A Firestore write queued while the device is offline or sync is pending.
class PendingSyncAction {
  const PendingSyncAction({
    required this.id,
    required this.matchId,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.attemptCount = 0,
  });

  final String id;
  final String matchId;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attemptCount;

  PendingSyncAction copyWith({
    int? attemptCount,
  }) {
    return PendingSyncAction(
      id: id,
      matchId: matchId,
      type: type,
      payload: payload,
      createdAt: createdAt,
      attemptCount: attemptCount ?? this.attemptCount,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'matchId': matchId,
        'type': type,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'attemptCount': attemptCount,
      };

  factory PendingSyncAction.fromMap(Map<String, dynamic> map) {
    return PendingSyncAction(
      id: map['id'] as String,
      matchId: map['matchId'] as String,
      type: map['type'] as String,
      payload: Map<String, dynamic>.from(map['payload'] as Map),
      createdAt: DateTime.parse(map['createdAt'] as String),
      attemptCount: map['attemptCount'] as int? ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PendingSyncAction.fromJson(String source) =>
      PendingSyncAction.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Known sync action types processed by [OfflineSyncService].
abstract final class SyncActionType {
  static const ballCommit = 'ball_commit';
  static const undoBalls = 'undo_balls';
  static const matchOverlay = 'match_overlay';
  static const matchUpdate = 'match_update';
  static const firestoreBatch = 'firestore_batch';
}

/// A single Firestore batch operation stored in [SyncActionType.firestoreBatch].
class FirestoreBatchOp {
  const FirestoreBatchOp({
    required this.op,
    required this.collection,
    required this.docId,
    this.subcollection,
    this.subDocId,
    this.data,
    this.merge = false,
  });

  final String op; // set | update | delete
  final String collection;
  final String docId;
  final String? subcollection;
  final String? subDocId;
  final Map<String, dynamic>? data;
  final bool merge;

  Map<String, dynamic> toMap() => {
        'op': op,
        'collection': collection,
        'docId': docId,
        if (subcollection != null) 'subcollection': subcollection,
        if (subDocId != null) 'subDocId': subDocId,
        if (data != null) 'data': data,
        'merge': merge,
      };

  factory FirestoreBatchOp.fromMap(Map<String, dynamic> map) {
    return FirestoreBatchOp(
      op: map['op'] as String,
      collection: map['collection'] as String,
      docId: map['docId'] as String,
      subcollection: map['subcollection'] as String?,
      subDocId: map['subDocId'] as String?,
      data: map['data'] == null
          ? null
          : Map<String, dynamic>.from(map['data'] as Map),
      merge: map['merge'] as bool? ?? false,
    );
  }
}

enum ConnectivityStatus { online, offline, syncing }

class MatchSyncMeta {
  const MatchSyncMeta({
    required this.matchId,
    required this.pendingCount,
    this.lastSyncAt,
    required this.status,
  });

  final String matchId;
  final int pendingCount;
  final DateTime? lastSyncAt;
  final ConnectivityStatus status;
}
