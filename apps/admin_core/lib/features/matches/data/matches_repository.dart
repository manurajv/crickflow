import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/constants/admin_collections.dart';
import '../../../models/admin_user.dart';
import '../../users/models/admin_audit_log.dart';
import '../models/match_enums.dart';
import '../models/match_filters.dart';
import '../models/managed_match.dart';

class MatchesRepository {
  MatchesRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _matches => _db.collection(AdminCollections.matches);
  CollectionReference<Map<String, dynamic>> get _audit => _db.collection(AdminCollections.adminAuditLogs);
  CollectionReference<Map<String, dynamic>> _ballEvents(String matchId) => _matches.doc(matchId).collection('ball_events');

  Future<MatchPageResult> fetchPage({required AdminAppType appType, required AdminUser? actor, required MatchListFilters filters, required MatchSort sort, DocumentSnapshot<Map<String, dynamic>>? startAfter, int limit = 25}) async {
    Query<Map<String, dynamic>> query = _matches;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) return const MatchPageResult(matches: [], hasMore: false);
      query = query.where('organizationId', isEqualTo: orgId);
    }
    if (filters.statuses.length == 1) {
      final status = filters.statuses.first;
      query = query.where(status == ManagedMatchStatus.cancelled || status == ManagedMatchStatus.delayed ? 'adminStatus' : 'status', isEqualTo: status.wireValue);
    }
    if (filters.streaming != null) {
      query = query.where('stream.status', isEqualTo: filters.streaming! ? 'live' : 'idle');
    }
    final q = filters.query.trim();
    if (q.isNotEmpty) {
      if (RegExp(r'^[A-Za-z0-9_-]{12,}$').hasMatch(q) && !q.contains(' ')) {
        final doc = await _matches.doc(q).get();
        if (!doc.exists || doc.data() == null) return const MatchPageResult(matches: [], hasMore: false);
        final m = ManagedMatch.fromFirestore(id: doc.id, map: doc.data()!);
        if (!_visibleToActor(m, appType: appType, actor: actor)) return const MatchPageResult(matches: [], hasMore: false);
        final filtered = _applyClientFilters([m], filters);
        return MatchPageResult(matches: filtered, hasMore: false, cursor: doc);
      }
      query = query.orderBy('title').startAt([q]).endAt(['$q\uf8ff']);
    } else {
      switch (sort.field) {
        case MatchSortField.title:
          query = query.orderBy('title', descending: sort.descending);
        case MatchSortField.scheduledAt:
          query = query.orderBy('scheduledAt', descending: sort.descending);
        case MatchSortField.startedAt:
          query = query.orderBy('startedAt', descending: sort.descending);
        case MatchSortField.status:
          query = query.orderBy('status', descending: sort.descending);
        case MatchSortField.createdAt:
          query = query.orderBy('createdAt', descending: sort.descending);
      }
    }
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await query.limit(limit + 1).get();
    } on FirebaseException {
      var fallback = _matches.orderBy(FieldPath.documentId).limit(limit + 1);
      if (appType == AdminAppType.organizationAdmin && actor?.organizationId != null) {
        fallback = _matches.where('organizationId', isEqualTo: actor!.organizationId).limit(limit + 1);
      }
      snap = await fallback.get();
    }
    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;
    var matches = pageDocs.map((d) => ManagedMatch.fromFirestore(id: d.id, map: d.data())).toList();
    matches = _applyClientFilters(matches, filters);
    return MatchPageResult(matches: matches, hasMore: hasMore, cursor: pageDocs.isEmpty ? null : pageDocs.last);
  }

  List<ManagedMatch> _applyClientFilters(List<ManagedMatch> list, MatchListFilters filters) {
    Iterable<ManagedMatch> items = list;
    if (!filters.includeDeleted) items = items.where((m) => !m.isSoftDeleted);
    if (!filters.includeArchived) items = items.where((m) => m.recordStatus != AdminMatchRecordStatus.archived);
    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((m) => m.title.toLowerCase().contains(q) || m.id.toLowerCase().contains(q) || (m.tournamentName?.toLowerCase().contains(q) ?? false) || m.venueLabel.toLowerCase().contains(q) || m.currentScorerName.toLowerCase().contains(q) || m.teamAName.toLowerCase().contains(q) || m.teamBName.toLowerCase().contains(q) || m.city.toLowerCase().contains(q) || m.stateProvince.toLowerCase().contains(q) || m.country.toLowerCase().contains(q));
    }
    if (filters.statuses.isNotEmpty) items = items.where((m) => filters.statuses.contains(m.status));
    if (filters.ballTypes.isNotEmpty) items = items.where((m) => m.ballType != null && filters.ballTypes.contains(m.ballType));
    if (filters.matchTypes.isNotEmpty) items = items.where((m) => filters.matchTypes.contains(m.matchType));
    if (filters.formats.isNotEmpty) items = items.where((m) => m.cricketType != null && filters.formats.contains(m.cricketType));
    if (filters.streaming != null) items = items.where((m) => m.isStreaming == filters.streaming);
    if (filters.platforms.isNotEmpty) items = items.where((m) => filters.platforms.contains(m.streamingPlatform));
    if (filters.country?.trim().isNotEmpty == true) { final c = filters.country!.trim().toLowerCase(); items = items.where((m) => m.country.toLowerCase().contains(c)); }
    if (filters.stateProvince?.trim().isNotEmpty == true) { final s = filters.stateProvince!.trim().toLowerCase(); items = items.where((m) => m.stateProvince.toLowerCase().contains(s)); }
    if (filters.city?.trim().isNotEmpty == true) { final c = filters.city!.trim().toLowerCase(); items = items.where((m) => m.city.toLowerCase().contains(c)); }
    if (filters.from != null) items = items.where((m) => m.scheduledAt != null && !m.scheduledAt!.isBefore(filters.from!));
    if (filters.to != null) items = items.where((m) => m.scheduledAt != null && !m.scheduledAt!.isAfter(filters.to!));
    return items.toList();
  }

  bool _visibleToActor(ManagedMatch m, {required AdminAppType appType, required AdminUser? actor}) {
    if (appType != AdminAppType.organizationAdmin) return true;
    final orgId = actor?.organizationId;
    if (orgId == null || orgId.isEmpty) return false;
    return m.organizationId == orgId;
  }

  Stream<ManagedMatch?> watchById(String id, {required AdminAppType appType, required AdminUser? actor}) {
    return _matches.doc(id).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      final m = ManagedMatch.fromFirestore(id: snap.id, map: snap.data()!);
      if (!_visibleToActor(m, appType: appType, actor: actor)) return null;
      return m;
    });
  }

  Future<MatchSummaryStats> fetchSummary({required AdminAppType appType, required AdminUser? actor}) async {
    Query<Map<String, dynamic>> base = _matches;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) return const MatchSummaryStats();
      base = base.where('organizationId', isEqualTo: orgId);
    }
    try {
      final snap = await base.limit(500).get();
      final list = snap.docs.map((d) => ManagedMatch.fromFirestore(id: d.id, map: d.data())).where((m) => !m.isSoftDeleted).toList();
      return MatchSummaryStats(
        total: list.length,
        live: list.where((m) => m.status == ManagedMatchStatus.live).length,
        upcoming: list.where((m) => m.status == ManagedMatchStatus.scheduled || m.status == ManagedMatchStatus.tossCompleted).length,
        completed: list.where((m) => m.status == ManagedMatchStatus.completed).length,
        abandoned: list.where((m) => m.status == ManagedMatchStatus.abandoned).length,
        cancelled: list.where((m) => m.status == ManagedMatchStatus.cancelled).length,
        streamsRunning: list.where((m) => m.isStreaming).length,
      );
    } catch (_) { return const MatchSummaryStats(); }
  }

  Future<List<MatchCommentaryItem>> fetchCommentary(String matchId, {String query = '', int limit = 40}) async {
    final snap = await _ballEvents(matchId).orderBy('sequence', descending: true).limit(limit).get();
    final q = query.trim().toLowerCase();
    final items = <MatchCommentaryItem>[];
    for (final doc in snap.docs) {
      final map = doc.data();
      final text = (map['commentary'] as String?)?.trim() ?? '';
      if (text.isEmpty) continue;
      if (q.isNotEmpty && !text.toLowerCase().contains(q)) continue;
      items.add(MatchCommentaryItem(id: doc.id, text: text, sequence: (map['sequence'] as num?)?.toInt() ?? 0, timestamp: _parseDate(map['timestamp']), overLabel: '${(map['overNumber'] as num?)?.toInt() ?? 0}.${(map['ballInOver'] as num?)?.toInt() ?? 0}'));
    }
    return items;
  }

  Future<List<MatchTimelineItem>> fetchTimeline(ManagedMatch match) async {
    final items = <MatchTimelineItem>[];
    if (match.createdAt != null) items.add(MatchTimelineItem(id: 'created', title: 'Match Created', occurredAt: match.createdAt!, subtitle: match.createdBy ?? ''));
    if (match.scheduledAt != null) items.add(MatchTimelineItem(id: 'scheduled', title: 'Scheduled', occurredAt: match.scheduledAt!, subtitle: match.venueLabel));
    if (match.startedAt != null) items.add(MatchTimelineItem(id: 'started', title: 'First Ball', occurredAt: match.startedAt!, subtitle: match.currentInningsLabel));
    if (match.isStreaming && match.lastHeartbeatAt != null) items.add(MatchTimelineItem(id: 'stream', title: 'Live Started', occurredAt: match.lastHeartbeatAt!, subtitle: match.streamingPlatform.label));
    if (match.completedAt != null) items.add(MatchTimelineItem(id: 'completed', title: 'Match Completed', occurredAt: match.completedAt!, subtitle: match.resultSummary));
    final audits = await fetchAuditForMatch(match.id);
    for (final a in audits) { items.add(MatchTimelineItem(id: a.id, title: a.action, occurredAt: a.timestamp, subtitle: a.reason ?? a.actorEmail)); }
    items.sort((a,b)=>b.occurredAt.compareTo(a.occurredAt));
    return items;
  }

  Future<List<AdminAuditLogEntry>> fetchAuditForMatch(String matchId, {int limit = 30}) async {
    try {
      final snap = await _audit.where('targetUid', isEqualTo: matchId).orderBy('timestamp', descending: true).limit(limit).get();
      return snap.docs.map((d) => AdminAuditLogEntry.fromMap(d.id, d.data())).toList();
    } catch (_) { return const []; }
  }

  Future<void> setFeatured({required ManagedMatch target, required bool featured, required AdminUser actor, String? reason}) async {
    await _matches.doc(target.id).set({'adminFeatured': featured, 'updatedAt': DateTime.now().toIso8601String()}, SetOptions(merge: true));
    await _writeAudit(action: featured ? AdminAuditActions.matchFeatured : AdminAuditActions.matchUnfeatured, actor: actor, target: target, reason: reason);
  }

  Future<void> setPaused({required ManagedMatch target, required bool paused, required AdminUser actor, String? reason}) async {
    await _matches.doc(target.id).set({'adminPaused': paused, 'updatedAt': DateTime.now().toIso8601String()}, SetOptions(merge: true));
    await _writeAudit(action: paused ? AdminAuditActions.matchPaused : AdminAuditActions.matchResumed, actor: actor, target: target, reason: reason);
  }

  Future<void> setStatus({required ManagedMatch target, required ManagedMatchStatus status, required AdminUser actor, String? reason}) async {
    final data = <String, dynamic>{'updatedAt': DateTime.now().toIso8601String()};
    if (status == ManagedMatchStatus.cancelled || status == ManagedMatchStatus.delayed) {
      data['adminStatus'] = status.wireValue;
    } else {
      data['status'] = status.wireValue;
      data['adminStatus'] = FieldValue.delete();
    }
    await _matches.doc(target.id).set(data, SetOptions(merge: true));
    final action = switch (status) {
      ManagedMatchStatus.cancelled => AdminAuditActions.matchCancelled,
      ManagedMatchStatus.abandoned => AdminAuditActions.matchAbandoned,
      ManagedMatchStatus.delayed => AdminAuditActions.matchEdited,
      _ => AdminAuditActions.matchEdited,
    };
    await _writeAudit(action: action, actor: actor, target: target, reason: reason, metadata: {'status': status.wireValue});
  }

  Future<void> softDelete({required ManagedMatch target, required AdminUser actor, String? reason}) async {
    final now = DateTime.now().toIso8601String();
    await _matches.doc(target.id).set({'adminRecordStatus': AdminMatchRecordStatus.deleted.wireValue, 'adminDeletedAt': now, 'adminDeletedBy': actor.uid, 'updatedAt': now}, SetOptions(merge: true));
    await _writeAudit(action: AdminAuditActions.matchSoftDeleted, actor: actor, target: target, reason: reason);
  }

  Future<void> restore({required ManagedMatch target, required AdminUser actor, String? reason}) async {
    await _matches.doc(target.id).set({'adminRecordStatus': AdminMatchRecordStatus.active.wireValue, 'adminDeletedAt': FieldValue.delete(), 'adminDeletedBy': FieldValue.delete(), 'updatedAt': DateTime.now().toIso8601String()}, SetOptions(merge: true));
    await _writeAudit(action: AdminAuditActions.matchRestored, actor: actor, target: target, reason: reason);
  }

  Future<void> archive({required ManagedMatch target, required AdminUser actor, String? reason}) async {
    await _matches.doc(target.id).set({'adminRecordStatus': AdminMatchRecordStatus.archived.wireValue, 'updatedAt': DateTime.now().toIso8601String()}, SetOptions(merge: true));
    await _writeAudit(action: AdminAuditActions.matchArchived, actor: actor, target: target, reason: reason);
  }

  Future<void> updateMetadata({required ManagedMatch target, required AdminUser actor, String? title, String? venue, String? reason}) async {
    await _matches.doc(target.id).set({
      'title': ?title,
      'venue': ?venue,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(action: AdminAuditActions.matchEdited, actor: actor, target: target, reason: reason);
  }

  Future<void> _writeAudit({required String action, required AdminUser actor, required ManagedMatch target, String? reason, Map<String, dynamic> metadata = const {}}) async {
    final entry = AdminAuditLogEntry(id: '', action: action, actorUid: actor.uid, actorEmail: actor.email, targetUid: target.id, targetEmail: target.title, timestamp: DateTime.now(), reason: reason, metadata: {...metadata, 'entity': 'match'});
    await _audit.add(entry.toMap());
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw > 9999999999 ? raw : raw * 1000);
    return null;
  }
}
