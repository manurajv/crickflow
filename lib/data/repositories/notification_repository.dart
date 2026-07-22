import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../models/notification_model.dart';
import '../models/team_model.dart';
import '../models/tournament/tournament_member_model.dart';
import '../models/tournament/tournament_official_model.dart';
import '../models/tournament_model.dart';
import '../../core/constants/enums.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  static const int pageSize = 30;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.notificationsCollection);

  CollectionReference<Map<String, dynamic>> get _players =>
      _firestore.collection(AppConstants.playersCollection);

  Query<Map<String, dynamic>> _userQuery(String userId) => _col
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true);

  Stream<List<NotificationModel>> watchForUser(String userId, {int limit = pageSize}) {
    return _userQuery(userId)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => NotificationModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// One-shot page fetch for lazy loading (cursor = last createdAt ISO string).
  Future<List<NotificationModel>> fetchPage({
    required String userId,
    int limit = pageSize,
    String? startAfterCreatedAt,
  }) async {
    Query<Map<String, dynamic>> q = _userQuery(userId).limit(limit);
    if (startAfterCreatedAt != null && startAfterCreatedAt.isNotEmpty) {
      q = q.startAfter([startAfterCreatedAt]);
    }
    final snap = await q.get();
    return snap.docs
        .map((d) => NotificationModel.fromMap(d.id, d.data()))
        .toList();
  }

  Stream<int> watchUnreadCount(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markRead(String notificationId) async {
    await _col.doc(notificationId).update({'read': true, 'isRead': true});
  }

  Future<void> setActionStatus(
    String notificationId,
    String status,
  ) async {
    await _col.doc(notificationId).update({
      'actionStatus': status,
      'read': true,
      'isRead': true,
    });
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    String? matchId,
    String? matchTitle,
    String? teamId,
    String? playerId,
    String? type,
    String? category,
    String? tab,
    String? addedByUserId,
    String? reportId,
    String? tournamentId,
    String? requestId,
    String? actionStatus,
  }) async {
    if (userId.isEmpty) return;

    await _col.doc(_uuid.v4()).set({
      'userId': userId,
      'title': title,
      'body': body,
      'message': body,
      'matchId': ?matchId,
      'matchTitle': ?matchTitle,
      'teamId': ?teamId,
      'playerId': ?playerId,
      'type': ?type,
      'category': ?category,
      'tab': ?tab,
      'addedByUserId': ?addedByUserId,
      'reportId': ?reportId,
      'tournamentId': ?tournamentId,
      'requestId': ?requestId,
      'actionStatus': ?actionStatus,
      'read': false,
      'isRead': false,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Notifies owner, captain, and vice captain using Firebase Auth uids.
  Future<void> notifyTeamLeadership({
    required TeamModel team,
    required String title,
    required String body,
    required String type,
    String? playerId,
    String? excludeUserId,
    String? tournamentId,
    String? requestId,
    String? category,
  }) async {
    final recipients = await _leadershipAuthUserIds(team);
    for (final uid in recipients) {
      if (excludeUserId != null && uid == excludeUserId) continue;
      await createNotification(
        userId: uid,
        title: title,
        body: body,
        teamId: team.id,
        playerId: playerId,
        type: type,
        tournamentId: tournamentId,
        requestId: requestId,
        category: category ?? 'team',
      );
    }
  }

  /// Notifies teams, staff, and officials when a tournament finishes.
  Future<void> notifyTournamentCompleted({
    required TournamentModel tournament,
    required String championTeamName,
    String? runnerUpTeamName,
    required Iterable<TeamModel> teams,
    Iterable<TournamentMemberModel> members = const [],
    Iterable<TournamentOfficialModel> officials = const [],
  }) async {
    final title = 'Tournament Complete';
    final bodyParts = <String>[
      tournament.name,
      'Champion: $championTeamName',
    ];
    if (runnerUpTeamName != null && runnerUpTeamName.isNotEmpty) {
      bodyParts.add('Runner-up: $runnerUpTeamName');
    }
    final body = bodyParts.join('\n');
    const type = 'tournament_completed';
    final notified = <String>{};

    for (final team in teams) {
      final leadership = await _leadershipAuthUserIds(team);
      for (final uid in leadership) {
        if (notified.add(uid)) {
          await createNotification(
            userId: uid,
            title: title,
            body: body,
            type: type,
            category: 'tournament',
            tournamentId: tournament.id,
            teamId: team.id,
          );
        }
      }
    }

    for (final member in members) {
      if (member.role != TournamentRole.owner &&
          member.role != TournamentRole.admin) {
        continue;
      }
      if (member.userId.isEmpty) continue;
      if (notified.add(member.userId)) {
        await createNotification(
          userId: member.userId,
          title: title,
          body: body,
          type: type,
          category: 'tournament',
          tournamentId: tournament.id,
        );
      }
    }

    for (final official in officials) {
      if (official.userId.isEmpty) continue;
      if (notified.add(official.userId)) {
        await createNotification(
          userId: official.userId,
          title: title,
          body: body,
          type: type,
          category: 'tournament',
          tournamentId: tournament.id,
        );
      }
    }

    final organizerId = tournament.effectiveOrganizerId;
    if (organizerId.isNotEmpty && notified.add(organizerId)) {
      await createNotification(
        userId: organizerId,
        title: title,
        body: body,
        type: type,
        category: 'tournament',
        tournamentId: tournament.id,
      );
    }
  }

  Future<Set<String>> _leadershipAuthUserIds(TeamModel team) async {
    final ids = <String>{};

    final owner = team.createdBy;
    if (owner != null && owner.isNotEmpty) {
      ids.add(owner);
    }

    await _addResolvedPlayerUid(ids, team.captainId);
    await _addResolvedPlayerUid(ids, team.viceCaptainId);

    return ids;
  }

  Future<void> _addResolvedPlayerUid(Set<String> ids, String? playerDocId) async {
    if (playerDocId == null || playerDocId.isEmpty) return;

    final playerSnap = await _players.doc(playerDocId).get();
    if (!playerSnap.exists) {
      ids.add(playerDocId);
      return;
    }

    final userId = playerSnap.data()?['userId'] as String?;
    ids.add(userId != null && userId.isNotEmpty ? userId : playerDocId);
  }

  Future<void> markAllRead(String userId) async {
    while (true) {
      final snap = await _col
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .limit(200)
          .get();
      if (snap.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true, 'isRead': true});
      }
      await batch.commit();
      if (snap.docs.length < 200) return;
    }
  }

  Future<void> deleteNotificationsForTeam(String teamId) async {
    while (true) {
      final snap =
          await _col.where('teamId', isEqualTo: teamId).limit(100).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// Removes community engagement notifications created by [addedByUserId].
  ///
  /// For likes: [requestId] = postId.
  /// For comments: [requestId] = postId and optional [reportId] = commentId.
  /// Best-effort: failures are swallowed so unlike/delete-comment UX never fails.
  Future<void> deleteCommunityEngagementNotifications({
    required String type,
    required String requestId,
    required String addedByUserId,
    String? reportId,
  }) async {
    if (type.isEmpty || requestId.isEmpty || addedByUserId.isEmpty) return;

    try {
      // Scope by addedByUserId so the query satisfies notification read rules.
      final snap = await _col
          .where('addedByUserId', isEqualTo: addedByUserId)
          .where('type', isEqualTo: type)
          .where('requestId', isEqualTo: requestId)
          .limit(50)
          .get();
      final matches = snap.docs.where((d) {
        if (reportId == null || reportId.isEmpty) return true;
        final stored = d.data()['reportId'] as String?;
        // Exact match for new notifications; also clear legacy rows without reportId.
        return stored == reportId || stored == null || stored.isEmpty;
      });
      if (matches.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in matches) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {
      // Comment/like already removed; inbox cleanup is secondary.
    }
  }

  Future<void> deleteAllForUser(String userId) async {
    while (true) {
      final snap =
          await _col.where('userId', isEqualTo: userId).limit(100).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
