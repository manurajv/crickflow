import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/constants/admin_collections.dart';
import '../../../core/constants/admin_query_limits.dart';
import '../../../models/admin_user.dart';
import '../../users/models/admin_audit_log.dart';
import '../models/managed_notification.dart';
import '../models/notification_enums.dart';
import '../models/notification_filters.dart';

/// Admin notification management.
///
/// - Campaigns / templates / segments: additive admin collections
/// - Announcements: `home_promotions` (existing mobile carousel)
/// - Auto notifications: read-only monitor of `notifications` (no FCM tokens)
///
/// Does not modify mobile notification generation or FCM token storage.
/// Mass send goes through the `adminSendNotificationCampaign` callable.
class NotificationsRepository {
  NotificationsRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _campaigns =>
      _db.collection(AdminCollections.adminNotificationCampaigns);
  CollectionReference<Map<String, dynamic>> get _templates =>
      _db.collection(AdminCollections.adminNotificationTemplates);
  CollectionReference<Map<String, dynamic>> get _segments =>
      _db.collection(AdminCollections.adminNotificationSegments);
  CollectionReference<Map<String, dynamic>> get _promotions =>
      _db.collection(AdminCollections.homePromotions);
  CollectionReference<Map<String, dynamic>> get _inbox =>
      _db.collection(AdminCollections.notifications);
  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  Future<NotificationPageResult> fetchCampaignsPage({
    required AdminAppType appType,
    required AdminUser? actor,
    required NotificationListFilters filters,
    required NotificationSort sort,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
    bool campaignsOnly = false,
    bool scheduledOnly = false,
  }) async {
    Query<Map<String, dynamic>> query = _campaigns;

    query = query.orderBy('createdAt', descending: sort.descending);
    if (startAfter != null) query = query.startAfterDocument(startAfter);

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await query.limit(limit + 1).get();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return const NotificationPageResult(items: [], hasMore: false);
      }
      try {
        snap = await _campaigns
            .orderBy(FieldPath.documentId)
            .limit(limit + 1)
            .get();
      } on FirebaseException catch (e2) {
        if (e2.code == 'permission-denied') {
          return const NotificationPageResult(items: [], hasMore: false);
        }
        rethrow;
      }
    }

    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;
    var items = pageDocs
        .map(
          (d) => ManagedNotificationCampaign.fromFirestore(
            id: d.id,
            map: d.data(),
          ),
        )
        .toList();
    items = _applyFilters(
      items,
      filters,
      campaignsOnly: campaignsOnly,
      scheduledOnly: scheduledOnly || filters.scheduledOnly,
    );
    _sort(items, sort);
    return NotificationPageResult(
      items: items,
      hasMore: hasMore,
      cursor: pageDocs.isEmpty ? null : pageDocs.last,
    );
  }

  List<ManagedNotificationCampaign> _applyFilters(
    List<ManagedNotificationCampaign> list,
    NotificationListFilters filters, {
    bool campaignsOnly = false,
    bool scheduledOnly = false,
  }) {
    Iterable<ManagedNotificationCampaign> items = list;
    if (!filters.includeArchived) {
      items = items.where(
        (c) => c.status != ManagedNotificationStatus.archived,
      );
    }
    if (campaignsOnly) {
      items = items.where((c) => c.isCampaign);
    }
    if (scheduledOnly) {
      items = items.where(
        (c) =>
            c.status == ManagedNotificationStatus.scheduled ||
            c.scheduleMode == ManagedScheduleMode.later ||
            c.scheduleMode == ManagedScheduleMode.recurring,
      );
    }
    if (filters.types.isNotEmpty) {
      items = items.where((c) => filters.types.contains(c.type));
    }
    if (filters.statuses.isNotEmpty) {
      items = items.where((c) => filters.statuses.contains(c.status));
    }
    if (filters.audiences.isNotEmpty) {
      items = items.where((c) => filters.audiences.contains(c.audience));
    }
    if (filters.platforms.isNotEmpty) {
      items = items.where((c) => c.platforms.any(filters.platforms.contains));
    }
    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((c) {
        return c.id.toLowerCase().contains(q) ||
            c.title.toLowerCase().contains(q) ||
            c.body.toLowerCase().contains(q) ||
            c.campaignName.toLowerCase().contains(q) ||
            c.createdByEmail.toLowerCase().contains(q) ||
            c.audienceLabel.toLowerCase().contains(q) ||
            (c.tournamentId?.toLowerCase().contains(q) ?? false) ||
            (c.matchId?.toLowerCase().contains(q) ?? false) ||
            (c.teamId?.toLowerCase().contains(q) ?? false) ||
            c.audienceIds.any((id) => id.toLowerCase().contains(q));
      });
    }
    if (filters.from != null) {
      items = items.where(
        (c) => c.createdAt != null && !c.createdAt!.isBefore(filters.from!),
      );
    }
    if (filters.to != null) {
      items = items.where(
        (c) => c.createdAt != null && !c.createdAt!.isAfter(filters.to!),
      );
    }
    return items.toList();
  }

  void _sort(List<ManagedNotificationCampaign> list, NotificationSort sort) {
    list.sort((a, b) {
      final r = switch (sort.field) {
        NotificationSortField.createdAt =>
          (a.createdAt ?? DateTime(1970)).compareTo(
            b.createdAt ?? DateTime(1970),
          ),
        NotificationSortField.title => a.displayTitle.toLowerCase().compareTo(
          b.displayTitle.toLowerCase(),
        ),
        NotificationSortField.status => a.status.name.compareTo(b.status.name),
        NotificationSortField.scheduledAt =>
          (a.scheduledAt ?? DateTime(1970)).compareTo(
            b.scheduledAt ?? DateTime(1970),
          ),
      };
      return sort.descending ? -r : r;
    });
  }

  Stream<ManagedNotificationCampaign?> watchCampaign(String id) {
    return _campaigns.doc(id).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return ManagedNotificationCampaign.fromFirestore(
        id: snap.id,
        map: snap.data()!,
      );
    });
  }

  Future<ManagedNotificationCampaign?> fetchCampaign(String id) async {
    final snap = await _campaigns.doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    return ManagedNotificationCampaign.fromFirestore(
      id: snap.id,
      map: snap.data()!,
    );
  }

  Future<NotificationSummaryStats> fetchSummary({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _campaigns;
      final snap = await query.limit(AdminQueryLimits.summaryScanMax).get();
      final items = snap.docs
          .map(
            (d) => ManagedNotificationCampaign.fromFirestore(
              id: d.id,
              map: d.data(),
            ),
          )
          .toList();
      final todayStart = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final sentToday = items
          .where(
            (c) =>
                c.status == ManagedNotificationStatus.sent &&
                c.sentAt != null &&
                !c.sentAt!.isBefore(todayStart),
          )
          .length;
      final scheduled = items
          .where((c) => c.status == ManagedNotificationStatus.scheduled)
          .length;
      final delivered = items.fold<int>(0, (s, c) => s + c.deliveredCount);
      final failed = items.fold<int>(0, (s, c) => s + c.failedCount);
      final sent = items.fold<int>(0, (s, c) => s + c.sentCount);
      final opened = items.fold<int>(0, (s, c) => s + c.openedCount);
      final clicked = items.fold<int>(0, (s, c) => s + c.clickedCount);
      return NotificationSummaryStats(
        sentToday: sentToday,
        scheduled: scheduled,
        delivered: delivered,
        failed: failed,
        openRate: delivered > 0 ? opened / delivered : 0,
        clickRate: delivered > 0 ? clicked / delivered : (sent > 0 ? 0 : 0),
        activeCampaigns: items
            .where(
              (c) =>
                  c.isCampaign &&
                  (c.status == ManagedNotificationStatus.scheduled ||
                      c.status == ManagedNotificationStatus.sending ||
                      c.status == ManagedNotificationStatus.queued),
            )
            .length,
        draftCampaigns: items
            .where(
              (c) =>
                  c.isCampaign && c.status == ManagedNotificationStatus.draft,
            )
            .length,
      );
    } catch (_) {
      return const NotificationSummaryStats();
    }
  }

  Future<String> createCampaign({
    required ManagedNotificationCampaign draft,
    required AdminUser actor,
    String? reason,
  }) async {
    final data = draft.toFirestoreMap(forCreate: true);
    data['createdByUid'] = actor.uid;
    data['createdByEmail'] = actor.email;
    if (actor.organizationId != null && actor.organizationId!.isNotEmpty) {
      data['organizationId'] = actor.organizationId;
    }
    final ref = await _campaigns.add(data);
    await _writeAudit(
      action: AdminAuditActions.notificationCreated,
      actor: actor,
      targetId: ref.id,
      targetLabel: draft.displayTitle,
      reason: reason,
    );
    return ref.id;
  }

  Future<void> updateCampaign({
    required ManagedNotificationCampaign campaign,
    required AdminUser actor,
    String? reason,
  }) async {
    await _campaigns
        .doc(campaign.id)
        .set(campaign.toFirestoreMap(), SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.notificationEdited,
      actor: actor,
      targetId: campaign.id,
      targetLabel: campaign.displayTitle,
      reason: reason,
    );
  }

  Future<void> deleteDraft({
    required ManagedNotificationCampaign campaign,
    required AdminUser actor,
    String? reason,
  }) async {
    if (campaign.status != ManagedNotificationStatus.draft &&
        campaign.status != ManagedNotificationStatus.cancelled) {
      throw StateError('Only draft or cancelled notifications can be deleted');
    }
    await _campaigns.doc(campaign.id).delete();
    await _writeAudit(
      action: AdminAuditActions.notificationDeleted,
      actor: actor,
      targetId: campaign.id,
      targetLabel: campaign.displayTitle,
      reason: reason,
    );
  }

  Future<void> archiveCampaign({
    required ManagedNotificationCampaign campaign,
    required AdminUser actor,
    String? reason,
  }) async {
    await _campaigns.doc(campaign.id).set({
      'status': ManagedNotificationStatus.archived.wireValue,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.notificationArchived,
      actor: actor,
      targetId: campaign.id,
      targetLabel: campaign.displayTitle,
      reason: reason,
    );
  }

  Future<String> duplicateCampaign({
    required ManagedNotificationCampaign source,
    required AdminUser actor,
    String? reason,
  }) async {
    final copy = source.copyWith(
      status: ManagedNotificationStatus.draft,
      scheduleMode: ManagedScheduleMode.immediate,
      clearScheduledAt: true,
      sentCount: 0,
      deliveredCount: 0,
      openedCount: 0,
      clickedCount: 0,
      failedCount: 0,
      deliveryNote: '',
    );
    final id = await createCampaign(draft: copy, actor: actor, reason: reason);
    await _writeAudit(
      action: AdminAuditActions.notificationDuplicated,
      actor: actor,
      targetId: id,
      targetLabel: source.displayTitle,
      reason: reason,
      metadata: {'sourceId': source.id},
    );
    return id;
  }

  /// Schedule for later / recurring. Does not call FCM.
  Future<void> scheduleCampaign({
    required ManagedNotificationCampaign campaign,
    required DateTime scheduledAt,
    required AdminUser actor,
    ManagedRecurrence recurrence = ManagedRecurrence.none,
    String timezone = 'UTC',
    String? reason,
  }) async {
    await _campaigns.doc(campaign.id).set({
      'status': ManagedNotificationStatus.scheduled.wireValue,
      'deliveryEngine': 'v1',
      'scheduleMode': recurrence == ManagedRecurrence.none
          ? ManagedScheduleMode.later.wireValue
          : ManagedScheduleMode.recurring.wireValue,
      'scheduledAt': scheduledAt.toIso8601String(),
      'recurrence': recurrence.wireValue,
      'timezone': timezone,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.notificationScheduled,
      actor: actor,
      targetId: campaign.id,
      targetLabel: campaign.displayTitle,
      reason: reason,
      metadata: {
        'scheduledAt': scheduledAt.toIso8601String(),
        'recurrence': recurrence.wireValue,
        'timezone': timezone,
      },
    );
  }

  Future<void> cancelSchedule({
    required ManagedNotificationCampaign campaign,
    required AdminUser actor,
    String? reason,
  }) async {
    await _campaigns.doc(campaign.id).set({
      'status': ManagedNotificationStatus.cancelled.wireValue,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.notificationCancelled,
      actor: actor,
      targetId: campaign.id,
      targetLabel: campaign.displayTitle,
      reason: reason,
    );
  }

  /// Starts a server-side campaign send or a dry-run estimate.
  ///
  /// The callable checks staff permission, writes the audit log, fans out
  /// inbox docs, and sends FCM from `users/{uid}/private/fcm` (legacy
  /// `fcmToken` as fallback), respecting notification prefs. The client
  /// never reads FCM tokens. Pass [dryRun] to count the audience without
  /// sending.
  Future<Map<String, dynamic>> sendOrQueue({
    required ManagedNotificationCampaign campaign,
    required AdminUser actor,
    String? reason,
    bool dryRun = false,
  }) async {
    if (campaign.id.isEmpty) {
      throw StateError('Save the campaign before sending');
    }
    final res = await _functions
        .httpsCallable(
          'adminSendNotificationCampaign',
          options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
        )
        .call<Map<String, dynamic>>({
          'campaignId': campaign.id,
          'dryRun': dryRun,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        });
    return Map<String, dynamic>.from(res.data);
  }

  // --- Announcements (home_promotions) ---

  Future<List<ManagedAnnouncement>> fetchAnnouncements({int limit = 80}) async {
    try {
      final snap = await _promotions
          .orderBy('priority', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map(
            (d) => ManagedAnnouncement.fromFirestore(id: d.id, map: d.data()),
          )
          .where((a) => a.kind == 'announcement' || a.kind == 'advertisement')
          .toList();
    } on FirebaseException {
      final snap = await _promotions.limit(limit).get();
      return snap.docs
          .map(
            (d) => ManagedAnnouncement.fromFirestore(id: d.id, map: d.data()),
          )
          .toList();
    }
  }

  Future<String> upsertAnnouncement({
    required ManagedAnnouncement announcement,
    required AdminUser actor,
    String? reason,
    bool create = false,
  }) async {
    final data = announcement.toFirestoreMap(forCreate: create);
    if (create) {
      final ref = await _promotions.add(data);
      await _writeAudit(
        action: AdminAuditActions.announcementCreated,
        actor: actor,
        targetId: ref.id,
        targetLabel: announcement.title,
        reason: reason,
      );
      return ref.id;
    }
    await _promotions.doc(announcement.id).set(data, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.announcementEdited,
      actor: actor,
      targetId: announcement.id,
      targetLabel: announcement.title,
      reason: reason,
    );
    return announcement.id;
  }

  Future<void> deleteAnnouncement({
    required ManagedAnnouncement announcement,
    required AdminUser actor,
    String? reason,
  }) async {
    await _promotions.doc(announcement.id).delete();
    await _writeAudit(
      action: AdminAuditActions.announcementDeleted,
      actor: actor,
      targetId: announcement.id,
      targetLabel: announcement.title,
      reason: reason,
    );
  }

  // --- Templates ---

  Future<List<ManagedNotificationTemplate>> fetchTemplates({
    required AdminAppType appType,
    required AdminUser? actor,
    int limit = 80,
  }) async {
    Query<Map<String, dynamic>> query = _templates;
    try {
      final snap = await query.limit(limit).get();
      return snap.docs
          .map(
            (d) => ManagedNotificationTemplate.fromFirestore(
              id: d.id,
              map: d.data(),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String> upsertTemplate({
    required ManagedNotificationTemplate template,
    required AdminUser actor,
    bool create = false,
    String? reason,
  }) async {
    final data = template.toFirestoreMap(forCreate: create);
    if (actor.organizationId != null) {
      data['organizationId'] = actor.organizationId;
    }
    if (create) {
      final ref = await _templates.add(data);
      await _writeAudit(
        action: AdminAuditActions.templateCreated,
        actor: actor,
        targetId: ref.id,
        targetLabel: template.name,
        reason: reason,
      );
      return ref.id;
    }
    await _templates.doc(template.id).set(data, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.templateEdited,
      actor: actor,
      targetId: template.id,
      targetLabel: template.name,
      reason: reason,
    );
    return template.id;
  }

  Future<void> deleteTemplate({
    required ManagedNotificationTemplate template,
    required AdminUser actor,
    String? reason,
  }) async {
    await _templates.doc(template.id).delete();
    await _writeAudit(
      action: AdminAuditActions.templateDeleted,
      actor: actor,
      targetId: template.id,
      targetLabel: template.name,
      reason: reason,
    );
  }

  // --- Segments ---

  Future<List<ManagedNotificationSegment>> fetchSegments({
    required AdminAppType appType,
    required AdminUser? actor,
    int limit = 80,
  }) async {
    Query<Map<String, dynamic>> query = _segments;
    try {
      final snap = await query.limit(limit).get();
      return snap.docs
          .map(
            (d) => ManagedNotificationSegment.fromFirestore(
              id: d.id,
              map: d.data(),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String> upsertSegment({
    required ManagedNotificationSegment segment,
    required AdminUser actor,
    bool create = false,
    String? reason,
  }) async {
    final data = segment.toFirestoreMap(forCreate: create);
    if (actor.organizationId != null) {
      data['organizationId'] = actor.organizationId;
    }
    if (create) {
      final ref = await _segments.add(data);
      await _writeAudit(
        action: AdminAuditActions.segmentCreated,
        actor: actor,
        targetId: ref.id,
        targetLabel: segment.name,
        reason: reason,
      );
      return ref.id;
    }
    await _segments.doc(segment.id).set(data, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.segmentEdited,
      actor: actor,
      targetId: segment.id,
      targetLabel: segment.name,
      reason: reason,
    );
    return segment.id;
  }

  Future<void> deleteSegment({
    required ManagedNotificationSegment segment,
    required AdminUser actor,
    String? reason,
  }) async {
    await _segments.doc(segment.id).delete();
    await _writeAudit(
      action: AdminAuditActions.segmentDeleted,
      actor: actor,
      targetId: segment.id,
      targetLabel: segment.name,
      reason: reason,
    );
  }

  /// Monitor automatic platform notifications (read-only). Never includes tokens.
  Future<List<ManagedAutoNotification>> fetchAutoNotifications({
    int limit = 40,
  }) async {
    try {
      final snap = await _inbox
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map(
            (d) =>
                ManagedAutoNotification.fromFirestore(id: d.id, map: d.data()),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<AdminAuditLogEntry>> fetchAudit({
    String? targetId,
    int limit = 40,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _audit.orderBy(
        'timestamp',
        descending: true,
      );
      if (targetId != null && targetId.isNotEmpty) {
        q = _audit
            .where('targetUid', isEqualTo: targetId)
            .orderBy('timestamp', descending: true);
      }
      final snap = await q.limit(limit).get();
      return snap.docs
          .map((d) => AdminAuditLogEntry.fromMap(d.id, d.data()))
          .where(
            (e) =>
                e.action.startsWith('notification.') ||
                e.action.startsWith('announcement.') ||
                e.action.startsWith('notification_template.') ||
                e.action.startsWith('notification_segment.') ||
                targetId != null,
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeAudit({
    required String action,
    required AdminUser actor,
    required String targetId,
    required String targetLabel,
    String? reason,
    Map<String, dynamic> metadata = const {},
  }) async {
    final entry = AdminAuditLogEntry(
      id: '',
      action: action,
      actorUid: actor.uid,
      actorEmail: actor.email,
      targetUid: targetId,
      targetEmail: targetLabel,
      timestamp: DateTime.now(),
      reason: reason,
      metadata: metadata,
    );
    await _audit.add(entry.toMap());
  }
}
