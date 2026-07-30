import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/constants/admin_collections.dart';
import '../../../models/admin_user.dart';
import '../../users/models/admin_audit_log.dart';
import '../models/ads_enums.dart';
import '../models/ads_filters.dart';
import '../models/managed_ads.dart';

/// Admin advertisement management.
///
/// Does not modify mobile AdMob (`AdMobConfig` / `google_mobile_ads`).
/// Custom home carousel creatives may sync to existing `home_promotions`
/// (kind=advertisement) so the mobile carousel can show approved ads.
class AdsRepository {
  AdsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _campaigns =>
      _db.collection(AdminCollections.adminAdCampaigns);
  CollectionReference<Map<String, dynamic>> get _advertisers =>
      _db.collection(AdminCollections.adminAdvertisers);
  CollectionReference<Map<String, dynamic>> get _sponsored =>
      _db.collection(AdminCollections.adminSponsoredContent);
  DocumentReference<Map<String, dynamic>> get _admobDoc =>
      _db.collection(AdminCollections.adminAdmobConfig).doc('settings');
  CollectionReference<Map<String, dynamic>> get _promotions =>
      _db.collection(AdminCollections.homePromotions);
  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  Future<AdsPageResult> fetchCampaignsPage({
    required AdminAppType appType,
    required AdminUser? actor,
    required AdsListFilters filters,
    required AdsSort sort,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
    bool pendingOnly = false,
  }) async {
    Query<Map<String, dynamic>> query = _campaigns;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) {
        return const AdsPageResult(items: [], hasMore: false);
      }
      query = query.where('organizationId', isEqualTo: orgId);
    }
    query = query.orderBy('createdAt', descending: sort.descending);
    if (startAfter != null) query = query.startAfterDocument(startAfter);

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await query.limit(limit + 1).get();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return const AdsPageResult(items: [], hasMore: false);
      }
      try {
        snap =
            await _campaigns.orderBy(FieldPath.documentId).limit(limit + 1).get();
      } on FirebaseException catch (e2) {
        if (e2.code == 'permission-denied') {
          return const AdsPageResult(items: [], hasMore: false);
        }
        rethrow;
      }
    }

    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;
    var items = pageDocs
        .map((d) => ManagedAdCampaign.fromFirestore(id: d.id, map: d.data()))
        .toList();
    items = _applyFilters(
      items,
      filters,
      pendingOnly: pendingOnly || filters.pendingOnly,
    );
    _sort(items, sort);
    return AdsPageResult(
      items: items,
      hasMore: hasMore,
      cursor: pageDocs.isEmpty ? null : pageDocs.last,
    );
  }

  List<ManagedAdCampaign> _applyFilters(
    List<ManagedAdCampaign> list,
    AdsListFilters filters, {
    bool pendingOnly = false,
  }) {
    Iterable<ManagedAdCampaign> items = list;
    if (!filters.includeArchived) {
      items = items.where((a) => a.status != ManagedAdStatus.archived);
    }
    if (pendingOnly) {
      items = items.where((a) => a.status == ManagedAdStatus.pendingApproval);
    }
    if (filters.statuses.isNotEmpty) {
      items = items.where((a) => filters.statuses.contains(a.status));
    }
    if (filters.placements.isNotEmpty) {
      items = items.where(
        (a) => a.placements.any(filters.placements.contains),
      );
    }
    if (filters.mediaTypes.isNotEmpty) {
      items = items.where((a) => filters.mediaTypes.contains(a.mediaType));
    }
    if (filters.campaignTypes.isNotEmpty) {
      items =
          items.where((a) => filters.campaignTypes.contains(a.campaignType));
    }
    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((a) {
        return a.id.toLowerCase().contains(q) ||
            a.title.toLowerCase().contains(q) ||
            a.campaignName.toLowerCase().contains(q) ||
            a.advertiserName.toLowerCase().contains(q) ||
            a.createdByEmail.toLowerCase().contains(q) ||
            a.destinationUrl.toLowerCase().contains(q);
      });
    }
    if (filters.from != null) {
      items = items.where(
        (a) => a.createdAt != null && !a.createdAt!.isBefore(filters.from!),
      );
    }
    if (filters.to != null) {
      items = items.where(
        (a) => a.createdAt != null && !a.createdAt!.isAfter(filters.to!),
      );
    }
    return items.toList();
  }

  void _sort(List<ManagedAdCampaign> list, AdsSort sort) {
    list.sort((a, b) {
      final r = switch (sort.field) {
        AdsSortField.createdAt =>
          (a.createdAt ?? DateTime(1970)).compareTo(b.createdAt ?? DateTime(1970)),
        AdsSortField.title =>
          a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()),
        AdsSortField.status => a.status.name.compareTo(b.status.name),
        AdsSortField.startDate =>
          (a.startDate ?? DateTime(1970)).compareTo(b.startDate ?? DateTime(1970)),
        AdsSortField.priority => a.priority.compareTo(b.priority),
      };
      return sort.descending ? -r : r;
    });
  }

  Stream<ManagedAdCampaign?> watchCampaign(String id) {
    return _campaigns.doc(id).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return ManagedAdCampaign.fromFirestore(id: snap.id, map: snap.data()!);
    });
  }

  Future<AdsSummaryStats> fetchSummary({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _campaigns;
      if (appType == AdminAppType.organizationAdmin) {
        final orgId = actor?.organizationId;
        if (orgId == null || orgId.isEmpty) return const AdsSummaryStats();
        query = query.where('organizationId', isEqualTo: orgId);
      }
      final snap = await query.limit(400).get();
      final items = snap.docs
          .map((d) => ManagedAdCampaign.fromFirestore(id: d.id, map: d.data()))
          .toList();

      var sponsoredTournaments = 0;
      var sponsoredTeams = 0;
      var sponsoredPosts = 0;
      try {
        final sSnap = await _sponsored.limit(200).get();
        for (final d in sSnap.docs) {
          final s = ManagedSponsoredContent.fromFirestore(id: d.id, map: d.data());
          switch (s.entityType) {
            case ManagedSponsoredEntityType.tournament:
              sponsoredTournaments++;
            case ManagedSponsoredEntityType.team:
              sponsoredTeams++;
            case ManagedSponsoredEntityType.communityPost:
              sponsoredPosts++;
            default:
              break;
          }
        }
      } catch (_) {}

      return AdsSummaryStats(
        activeCampaigns: items
            .where((a) => a.status == ManagedAdStatus.active)
            .length,
        scheduledCampaigns: items
            .where((a) => a.status == ManagedAdStatus.scheduled)
            .length,
        totalAds: items.length,
        sponsoredTournaments: sponsoredTournaments,
        sponsoredTeams: sponsoredTeams,
        sponsoredCommunityPosts: sponsoredPosts,
        totalImpressions:
            items.fold<int>(0, (s, a) => s + a.impressions),
        estimatedRevenue:
            items.fold<double>(0, (s, a) => s + a.estimatedRevenue),
      );
    } catch (_) {
      return const AdsSummaryStats();
    }
  }

  Future<String> createCampaign({
    required ManagedAdCampaign draft,
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
      action: AdminAuditActions.adCreated,
      actor: actor,
      targetId: ref.id,
      targetLabel: draft.displayTitle,
      reason: reason,
    );
    return ref.id;
  }

  Future<void> updateCampaign({
    required ManagedAdCampaign campaign,
    required AdminUser actor,
    String? reason,
  }) async {
    await _campaigns.doc(campaign.id).set(
          campaign.toFirestoreMap(),
          SetOptions(merge: true),
        );
    await _writeAudit(
      action: AdminAuditActions.adEdited,
      actor: actor,
      targetId: campaign.id,
      targetLabel: campaign.displayTitle,
      reason: reason,
    );
  }

  Future<void> setStatus({
    required ManagedAdCampaign campaign,
    required ManagedAdStatus status,
    required AdminUser actor,
    String? reason,
    String? rejectionReason,
  }) async {
    final auditAction = switch (status) {
      ManagedAdStatus.paused => AdminAuditActions.adPaused,
      ManagedAdStatus.archived => AdminAuditActions.adArchived,
      ManagedAdStatus.rejected => AdminAuditActions.adRejected,
      ManagedAdStatus.scheduled => AdminAuditActions.adScheduled,
      ManagedAdStatus.approved || ManagedAdStatus.active =>
        status == ManagedAdStatus.active &&
                campaign.status == ManagedAdStatus.paused
            ? AdminAuditActions.adResumed
            : AdminAuditActions.adApproved,
      _ => AdminAuditActions.adEdited,
    };

    await _campaigns.doc(campaign.id).set({
      'status': status.wireValue,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    // Sync approved home placement ads to mobile carousel collection.
    if ((status == ManagedAdStatus.approved ||
            status == ManagedAdStatus.active) &&
        campaign.placements.contains(ManagedAdPlacement.home)) {
      await _syncHomePromotion(campaign.copyWith(status: status), actor);
    }

    await _writeAudit(
      action: auditAction,
      actor: actor,
      targetId: campaign.id,
      targetLabel: campaign.displayTitle,
      reason: reason ?? rejectionReason,
      metadata: {'status': status.wireValue},
    );
  }

  Future<void> _syncHomePromotion(
    ManagedAdCampaign campaign,
    AdminUser actor,
  ) async {
    final data = {
      'kind': 'advertisement',
      'title': campaign.title,
      'description': campaign.description,
      'imageUrl': campaign.bannerUrl.isNotEmpty
          ? campaign.bannerUrl
          : campaign.thumbnailUrl,
      'buttonText': campaign.buttonText,
      'redirectAction':
          campaign.destinationUrl.startsWith('http') ? 'url' : 'route',
      'redirectUrl': campaign.destinationUrl,
      'priority': campaign.priority,
      'active': campaign.status == ManagedAdStatus.active ||
          campaign.status == ManagedAdStatus.approved,
      if (campaign.endDate != null)
        'expiresAt': Timestamp.fromDate(campaign.endDate!),
      'adminCampaignId': campaign.id,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (campaign.homePromotionId != null &&
        campaign.homePromotionId!.isNotEmpty) {
      await _promotions
          .doc(campaign.homePromotionId)
          .set(data, SetOptions(merge: true));
    } else {
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _promotions.add(data);
      await _campaigns.doc(campaign.id).set({
        'homePromotionId': ref.id,
      }, SetOptions(merge: true));
    }
  }

  Future<void> deleteCampaign({
    required ManagedAdCampaign campaign,
    required AdminUser actor,
    String? reason,
  }) async {
    await _campaigns.doc(campaign.id).delete();
    await _writeAudit(
      action: AdminAuditActions.adDeleted,
      actor: actor,
      targetId: campaign.id,
      targetLabel: campaign.displayTitle,
      reason: reason,
    );
  }

  Future<String> duplicateCampaign({
    required ManagedAdCampaign source,
    required AdminUser actor,
    String? reason,
  }) async {
    final copy = source.copyWith(
      status: ManagedAdStatus.draft,
      impressions: 0,
      clicks: 0,
      estimatedRevenue: 0,
      homePromotionId: null,
    );
    final id = await createCampaign(draft: copy, actor: actor, reason: reason);
    await _writeAudit(
      action: AdminAuditActions.adDuplicated,
      actor: actor,
      targetId: id,
      targetLabel: source.displayTitle,
      reason: reason,
      metadata: {'sourceId': source.id},
    );
    return id;
  }

  Future<void> setFeatured({
    required ManagedAdCampaign campaign,
    required bool featured,
    required AdminUser actor,
    String? reason,
  }) async {
    await _campaigns.doc(campaign.id).set({
      'featured': featured,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.adFeatured,
      actor: actor,
      targetId: campaign.id,
      targetLabel: campaign.displayTitle,
      reason: reason,
      metadata: {'featured': featured},
    );
  }

  // --- Advertisers ---

  Future<List<ManagedAdvertiser>> fetchAdvertisers({
    required AdminAppType appType,
    required AdminUser? actor,
    int limit = 80,
  }) async {
    Query<Map<String, dynamic>> query = _advertisers;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) return const [];
      query = query.where('organizationId', isEqualTo: orgId);
    }
    try {
      final snap = await query.limit(limit).get();
      return snap.docs
          .map((d) => ManagedAdvertiser.fromFirestore(id: d.id, map: d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String> upsertAdvertiser({
    required ManagedAdvertiser advertiser,
    required AdminUser actor,
    required bool create,
    String? reason,
  }) async {
    final data = advertiser.toFirestoreMap(forCreate: create);
    if (actor.organizationId != null) {
      data['organizationId'] = actor.organizationId;
    }
    if (create) {
      final ref = await _advertisers.add(data);
      await _writeAudit(
        action: AdminAuditActions.advertiserCreated,
        actor: actor,
        targetId: ref.id,
        targetLabel: advertiser.companyName,
        reason: reason,
      );
      return ref.id;
    }
    await _advertisers.doc(advertiser.id).set(data, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.advertiserEdited,
      actor: actor,
      targetId: advertiser.id,
      targetLabel: advertiser.companyName,
      reason: reason,
    );
    return advertiser.id;
  }

  Future<void> deleteAdvertiser({
    required ManagedAdvertiser advertiser,
    required AdminUser actor,
    String? reason,
  }) async {
    await _advertisers.doc(advertiser.id).delete();
    await _writeAudit(
      action: AdminAuditActions.advertiserDeleted,
      actor: actor,
      targetId: advertiser.id,
      targetLabel: advertiser.companyName,
      reason: reason,
    );
  }

  // --- Sponsored ---

  Future<List<ManagedSponsoredContent>> fetchSponsored({int limit = 80}) async {
    try {
      final snap = await _sponsored.limit(limit).get();
      return snap.docs
          .map(
            (d) => ManagedSponsoredContent.fromFirestore(id: d.id, map: d.data()),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String> upsertSponsored({
    required ManagedSponsoredContent item,
    required AdminUser actor,
    required bool create,
    String? reason,
  }) async {
    final data = item.toFirestoreMap(forCreate: create);
    if (actor.organizationId != null) {
      data['organizationId'] = actor.organizationId;
    }
    if (create) {
      final ref = await _sponsored.add(data);
      await _writeAudit(
        action: AdminAuditActions.sponsoredCreated,
        actor: actor,
        targetId: ref.id,
        targetLabel: item.entityLabel.isEmpty ? item.entityId : item.entityLabel,
        reason: reason,
      );
      return ref.id;
    }
    await _sponsored.doc(item.id).set(data, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.sponsoredEdited,
      actor: actor,
      targetId: item.id,
      targetLabel: item.entityLabel,
      reason: reason,
    );
    return item.id;
  }

  Future<void> deleteSponsored({
    required ManagedSponsoredContent item,
    required AdminUser actor,
    String? reason,
  }) async {
    await _sponsored.doc(item.id).delete();
    await _writeAudit(
      action: AdminAuditActions.sponsoredDeleted,
      actor: actor,
      targetId: item.id,
      targetLabel: item.entityLabel,
      reason: reason,
    );
  }

  // --- AdMob config (admin mirror only) ---

  Future<ManagedAdmobConfig> fetchAdmobConfig() async {
    try {
      final snap = await _admobDoc.get();
      if (!snap.exists || snap.data() == null) {
        return ManagedAdmobConfig.defaults();
      }
      return ManagedAdmobConfig.fromFirestore(snap.data()!);
    } catch (_) {
      return ManagedAdmobConfig.defaults();
    }
  }

  Future<void> saveAdmobConfig({
    required ManagedAdmobConfig config,
    required AdminUser actor,
    String? reason,
  }) async {
    await _admobDoc.set(
      config.toFirestoreMap(updatedBy: actor.uid),
      SetOptions(merge: true),
    );
    await _writeAudit(
      action: AdminAuditActions.admobConfigUpdated,
      actor: actor,
      targetId: 'settings',
      targetLabel: 'AdMob Config',
      reason: reason,
      metadata: {'testMode': config.testMode},
    );
  }

  Future<List<AdminAuditLogEntry>> fetchAudit({
    String? targetId,
    int limit = 40,
  }) async {
    try {
      Query<Map<String, dynamic>> q =
          _audit.orderBy('timestamp', descending: true);
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
                e.action.startsWith('ad.') ||
                e.action.startsWith('advertiser.') ||
                e.action.startsWith('admob.') ||
                e.action.startsWith('sponsored.') ||
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
