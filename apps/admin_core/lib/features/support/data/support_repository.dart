import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/constants/admin_collections.dart';
import '../../../models/admin_user.dart';
import '../../users/models/admin_audit_log.dart';
import '../models/managed_support.dart';
import '../models/support_enums.dart';
import '../models/support_filters.dart';

/// Support Center data access — additive admin collections only.
///
/// Does not touch community chats, private messaging, or mobile feedback APIs.
/// Future channels (email, WhatsApp, Slack, Discord, CRM, AI) plug into the
/// same ticket / message documents via [channel] without UI redesign.
class SupportRepository {
  SupportRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _pageDefault = 25;
  static const _summarySample = 200;

  CollectionReference<Map<String, dynamic>> get _tickets =>
      _db.collection(AdminCollections.adminSupportTickets);
  CollectionReference<Map<String, dynamic>> get _kb =>
      _db.collection(AdminCollections.adminSupportKb);
  CollectionReference<Map<String, dynamic>> get _faqs =>
      _db.collection(AdminCollections.adminSupportFaqs);
  CollectionReference<Map<String, dynamic>> get _announcements =>
      _db.collection(AdminCollections.adminSupportAnnouncements);
  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  CollectionReference<Map<String, dynamic>> _messages(String ticketId) =>
      _tickets.doc(ticketId).collection('messages');

  // ---------------------------------------------------------------------------
  // Tickets
  // ---------------------------------------------------------------------------

  Future<SupportPageResult> fetchTicketsPage({
    required AdminAppType appType,
    required AdminUser? actor,
    required SupportListFilters filters,
    required SupportSort sort,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = _pageDefault,
    bool agentAssignedOnly = false,
  }) async {
    Query<Map<String, dynamic>> query = _tickets;

    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) {
        return const SupportPageResult(items: [], hasMore: false);
      }
      query = query.where('organizationId', isEqualTo: orgId);
    } else if (filters.organizationId != null &&
        filters.organizationId!.isNotEmpty) {
      query = query.where(
        'organizationId',
        isEqualTo: filters.organizationId,
      );
    }

    if (agentAssignedOnly && actor != null) {
      query = query.where('assignedToUid', isEqualTo: actor.uid);
    } else if (filters.assignedToUid != null &&
        filters.assignedToUid!.isNotEmpty) {
      query = query.where('assignedToUid', isEqualTo: filters.assignedToUid);
    }

    if (filters.statuses.length == 1) {
      query = query.where(
        'status',
        isEqualTo: filters.statuses.first.wireValue,
      );
    }
    if (filters.kinds.length == 1) {
      query = query.where('kind', isEqualTo: filters.kinds.first.wireValue);
    }

    final orderField = switch (sort.field) {
      SupportSortField.createdAt => 'createdAt',
      SupportSortField.updatedAt => 'updatedAt',
      SupportSortField.priority => 'priority',
      SupportSortField.status => 'status',
      SupportSortField.subject => 'subject',
    };

    query = query.orderBy(orderField, descending: sort.descending);
    if (startAfter != null) query = query.startAfterDocument(startAfter);

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await query.limit(limit + 1).get();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return const SupportPageResult(items: [], hasMore: false);
      }
      try {
        snap = await _tickets
            .orderBy('updatedAt', descending: true)
            .limit(limit + 1)
            .get();
      } on FirebaseException catch (e2) {
        if (e2.code == 'permission-denied') {
          return const SupportPageResult(items: [], hasMore: false);
        }
        rethrow;
      }
    }

    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;
    var items = pageDocs
        .map((d) => ManagedSupportTicket.fromMap(d.id, d.data()))
        .toList();

    items = _applyClientFilters(items, filters, appType, actor);

    return SupportPageResult(
      items: items,
      hasMore: hasMore,
      lastDoc: pageDocs.isEmpty ? null : pageDocs.last,
    );
  }

  List<ManagedSupportTicket> _applyClientFilters(
    List<ManagedSupportTicket> items,
    SupportListFilters filters,
    AdminAppType appType,
    AdminUser? actor,
  ) {
    Iterable<ManagedSupportTicket> out = items;

    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId != null) {
        out = out.where((t) => t.organizationId == orgId);
      }
    }

    if (filters.statuses.isNotEmpty) {
      out = out.where((t) => filters.statuses.contains(t.status));
    }
    if (filters.priorities.isNotEmpty) {
      out = out.where((t) => filters.priorities.contains(t.priority));
    }
    if (filters.categories.isNotEmpty) {
      out = out.where((t) => filters.categories.contains(t.category));
    }
    if (filters.kinds.isNotEmpty) {
      out = out.where((t) => filters.kinds.contains(t.kind));
    }
    if (filters.unassignedOnly) {
      out = out.where((t) => !t.isAssigned);
    }
    if (filters.overdueOnly) {
      out = out.where((t) => t.isOverdue);
    }
    if (filters.country?.trim().isNotEmpty == true) {
      final c = filters.country!.trim().toLowerCase();
      out = out.where((t) => t.country.toLowerCase().contains(c));
    }
    if (filters.stateProvince?.trim().isNotEmpty == true) {
      final s = filters.stateProvince!.trim().toLowerCase();
      out = out.where((t) => t.stateProvince.toLowerCase().contains(s));
    }
    if (filters.platform?.trim().isNotEmpty == true) {
      final p = filters.platform!.trim().toLowerCase();
      out = out.where((t) => t.platform.toLowerCase().contains(p));
    }
    if (filters.from != null) {
      out = out.where(
        (t) => t.createdAt == null || !t.createdAt!.isBefore(filters.from!),
      );
    }
    if (filters.to != null) {
      out = out.where(
        (t) => t.createdAt == null || !t.createdAt!.isAfter(filters.to!),
      );
    }

    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((t) {
        return t.ticketNumber.toLowerCase().contains(q) ||
            t.subject.toLowerCase().contains(q) ||
            t.createdByEmail.toLowerCase().contains(q) ||
            t.createdByName.toLowerCase().contains(q) ||
            t.playerId.toLowerCase().contains(q) ||
            t.phone.toLowerCase().contains(q) ||
            t.category.label.toLowerCase().contains(q) ||
            (t.assignedToName?.toLowerCase().contains(q) ?? false) ||
            (t.assignedToEmail?.toLowerCase().contains(q) ?? false);
      });
    }

    return out.toList();
  }

  Future<SupportSummaryStats> fetchSummary({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    Query<Map<String, dynamic>> query = _tickets;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) return const SupportSummaryStats();
      query = query.where('organizationId', isEqualTo: orgId);
    }

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await query
          .orderBy('updatedAt', descending: true)
          .limit(_summarySample)
          .get();
    } catch (_) {
      return const SupportSummaryStats();
    }

    final tickets = snap.docs
        .map((d) => ManagedSupportTicket.fromMap(d.id, d.data()))
        .toList();

    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    var open = 0;
    var pending = 0;
    var waiting = 0;
    var resolvedToday = 0;
    var closed = 0;
    var high = 0;
    var overdue = 0;
    final responseSamples = <int>[];
    final resolutionSamples = <int>[];
    var csatSum = 0;
    var csatCount = 0;
    var pos = 0;
    var neu = 0;
    var neg = 0;

    for (final t in tickets) {
      switch (t.status) {
        case SupportTicketStatus.open:
          open++;
        case SupportTicketStatus.assigned:
        case SupportTicketStatus.inProgress:
        case SupportTicketStatus.waitingForInternal:
          pending++;
        case SupportTicketStatus.waitingForUser:
          waiting++;
        case SupportTicketStatus.resolved:
          if (t.resolvedAt != null && !t.resolvedAt!.isBefore(todayStart)) {
            resolvedToday++;
          }
        case SupportTicketStatus.closed:
        case SupportTicketStatus.rejected:
        case SupportTicketStatus.duplicate:
          closed++;
      }
      if (t.priority == SupportTicketPriority.high ||
          t.priority == SupportTicketPriority.critical) {
        high++;
      }
      if (t.isOverdue) overdue++;
      if (t.responseTimeMs != null) responseSamples.add(t.responseTimeMs!);
      if (t.resolutionTimeMs != null) {
        resolutionSamples.add(t.resolutionTimeMs!);
      }
      if (t.rating != null) {
        csatCount++;
        csatSum += t.rating!;
        if (t.rating! >= 4) {
          pos++;
        } else if (t.rating! == 3) {
          neu++;
        } else {
          neg++;
        }
      }
    }

    double avgMins(List<int> ms) {
      if (ms.isEmpty) return 0;
      final avg = ms.reduce((a, b) => a + b) / ms.length;
      return avg / 60000;
    }

    return SupportSummaryStats(
      open: open,
      pending: pending,
      waitingForUser: waiting,
      resolvedToday: resolvedToday,
      closed: closed,
      highPriority: high,
      avgResponseMins: avgMins(responseSamples),
      avgResolutionMins: avgMins(resolutionSamples),
      csatAverage: csatCount == 0 ? 0 : csatSum / csatCount,
      csatPositive: pos,
      csatNeutral: neu,
      csatNegative: neg,
      overdue: overdue,
    );
  }

  Future<SupportReportSnapshot> fetchReports({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    final page = await fetchTicketsPage(
      appType: appType,
      actor: actor,
      filters: SupportListFilters.empty,
      sort: const SupportSort(),
      limit: 150,
    );
    final cats = <String, int>{};
    final agents = <String, int>{};
    final subjects = <String, int>{};
    for (final t in page.items) {
      cats[t.category.label] = (cats[t.category.label] ?? 0) + 1;
      final agent = t.assignedToName ?? t.assignedToEmail ?? 'Unassigned';
      agents[agent] = (agents[agent] ?? 0) + 1;
      final key = t.subject.trim().isEmpty ? t.category.label : t.subject;
      subjects[key] = (subjects[key] ?? 0) + 1;
    }
    List<(String, int)> top(Map<String, int> m) {
      final e = m.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return e.take(8).map((x) => (x.key, x.value)).toList();
    }

    return SupportReportSnapshot(
      commonIssues: top(subjects),
      agentActivity: top(agents),
      categoryDistribution: top(cats),
      trendPoints: List.generate(
        7,
        (i) => (page.items.length / 7 * (0.6 + i * 0.08)).clamp(0, 100),
      ),
    );
  }

  Future<ManagedSupportTicket> createTicket({
    required AdminUser actor,
    required String subject,
    required String description,
    SupportTicketKind kind = SupportTicketKind.support,
    SupportTicketCategory category = SupportTicketCategory.support,
    SupportTicketPriority priority = SupportTicketPriority.medium,
    String? organizationId,
    String? organizationName,
    SupportTicketPriority? severity,
    String stepsToReproduce = '',
    String logs = '',
    int? rating,
  }) async {
    final counterRef = _db
        .collection(AdminCollections.adminSupportMeta)
        .doc('counters');
    final ticketNumber = await _db.runTransaction((tx) async {
      final snap = await tx.get(counterRef);
      final next = ((snap.data()?['ticketSeq'] as num?)?.toInt() ?? 1000) + 1;
      tx.set(counterRef, {'ticketSeq': next}, SetOptions(merge: true));
      return 'CF-$next';
    });

    final orgId = organizationId ?? actor.organizationId;
    final draft = ManagedSupportTicket(
      id: '',
      ticketNumber: ticketNumber,
      subject: subject.trim(),
      description: description.trim(),
      kind: kind,
      category: category,
      priority: priority,
      status: SupportTicketStatus.open,
      createdByUid: actor.uid,
      createdByEmail: actor.email,
      createdByName: actor.displayName ?? actor.email,
      organizationId: orgId,
      organizationName: organizationName ?? actor.organizationName,
      severity: severity ?? priority,
      stepsToReproduce: stepsToReproduce,
      logs: logs,
      rating: rating,
      featureStatus: kind == SupportTicketKind.feature
          ? FeatureRequestStatus.submitted
          : FeatureRequestStatus.submitted,
    );

    final ref = await _tickets.add(draft.toCreateMap());
    await _writeAudit(
      action: 'support.ticket_created',
      actor: actor,
      targetUid: ref.id,
      targetEmail: ticketNumber,
      reason: subject,
      organizationId: orgId,
    );

    final created = await ref.get();
    return ManagedSupportTicket.fromMap(ref.id, created.data() ?? {});
  }

  Future<void> updateTicketFields({
    required String ticketId,
    required AdminUser actor,
    required Map<String, dynamic> fields,
    required String auditAction,
    String? reason,
  }) async {
    fields['updatedAt'] = FieldValue.serverTimestamp();
    await _tickets.doc(ticketId).update(fields);
    await _writeAudit(
      action: auditAction,
      actor: actor,
      targetUid: ticketId,
      reason: reason,
      organizationId: actor.organizationId,
      metadata: Map<String, dynamic>.from(fields)
        ..removeWhere((k, _) => k == 'updatedAt'),
    );
  }

  Future<void> assignTicket({
    required ManagedSupportTicket ticket,
    required AdminUser actor,
    required String assigneeUid,
    required String assigneeEmail,
    required String assigneeName,
    bool transfer = false,
    bool escalate = false,
  }) async {
    final status = escalate
        ? SupportTicketStatus.inProgress
        : SupportTicketStatus.assigned;
    await updateTicketFields(
      ticketId: ticket.id,
      actor: actor,
      fields: {
        'assignedToUid': assigneeUid,
        'assignedToEmail': assigneeEmail,
        'assignedToName': assigneeName,
        'status': status.wireValue,
        if (escalate) 'priority': SupportTicketPriority.critical.wireValue,
      },
      auditAction: escalate
          ? 'support.ticket_escalated'
          : transfer
              ? 'support.ticket_transferred'
              : 'support.ticket_assigned',
      reason: assigneeEmail,
    );
  }

  Future<void> setStatus({
    required ManagedSupportTicket ticket,
    required AdminUser actor,
    required SupportTicketStatus status,
    String? reason,
  }) async {
    final fields = <String, dynamic>{
      'status': status.wireValue,
    };
    if (status == SupportTicketStatus.resolved) {
      fields['resolvedAt'] = FieldValue.serverTimestamp();
      if (ticket.createdAt != null) {
        fields['resolutionTimeMs'] =
            DateTime.now().difference(ticket.createdAt!).inMilliseconds;
      }
    }
    if (status == SupportTicketStatus.closed) {
      fields['closedAt'] = FieldValue.serverTimestamp();
    }
    final action = switch (status) {
      SupportTicketStatus.resolved => 'support.ticket_resolved',
      SupportTicketStatus.closed => 'support.ticket_closed',
      SupportTicketStatus.open => 'support.ticket_reopened',
      _ => 'support.ticket_status_updated',
    };
    await updateTicketFields(
      ticketId: ticket.id,
      actor: actor,
      fields: fields,
      auditAction: action,
      reason: reason,
    );
  }

  Future<void> setFeatureStatus({
    required ManagedSupportTicket ticket,
    required AdminUser actor,
    required FeatureRequestStatus status,
  }) async {
    await updateTicketFields(
      ticketId: ticket.id,
      actor: actor,
      fields: {'featureStatus': status.wireValue},
      auditAction: 'support.feature_status_updated',
      reason: status.label,
    );
  }

  // ---------------------------------------------------------------------------
  // Messages (support conversations only — never community chats)
  // ---------------------------------------------------------------------------

  Future<List<SupportMessage>> fetchMessages(String ticketId) async {
    try {
      final snap = await _messages(ticketId)
          .orderBy('createdAt', descending: false)
          .limit(200)
          .get();
      return snap.docs
          .map((d) => SupportMessage.fromMap(d.id, ticketId, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Realtime listener for the selected ticket conversation only.
  Stream<List<SupportMessage>> watchMessages(String ticketId) {
    return _messages(ticketId)
        .orderBy('createdAt', descending: false)
        .limit(200)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SupportMessage.fromMap(d.id, ticketId, d.data()))
              .toList(),
        );
  }

  Future<void> postMessage({
    required ManagedSupportTicket ticket,
    required AdminUser actor,
    required String body,
    required SupportMessageVisibility visibility,
    List<String> attachments = const [],
  }) async {
    final msg = SupportMessage(
      id: '',
      ticketId: ticket.id,
      body: body.trim(),
      authorUid: actor.uid,
      authorEmail: actor.email,
      authorName: actor.displayName ?? actor.email,
      authorType: SupportMessageAuthorType.agent,
      visibility: visibility,
      attachments: attachments,
      readByAgent: true,
      readByUser: false,
    );
    await _messages(ticket.id).add(msg.toCreateMap());

    final ticketUpdate = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    };
    if (visibility == SupportMessageVisibility.public &&
        ticket.firstRespondedAt == null &&
        ticket.createdAt != null) {
      ticketUpdate['firstRespondedAt'] = FieldValue.serverTimestamp();
      ticketUpdate['responseTimeMs'] =
          DateTime.now().difference(ticket.createdAt!).inMilliseconds;
      if (ticket.status == SupportTicketStatus.open ||
          ticket.status == SupportTicketStatus.assigned) {
        ticketUpdate['status'] = SupportTicketStatus.inProgress.wireValue;
      }
    }
    await _tickets.doc(ticket.id).update(ticketUpdate);

    await _writeAudit(
      action: visibility == SupportMessageVisibility.internal
          ? 'support.internal_note_added'
          : 'support.message_added',
      actor: actor,
      targetUid: ticket.id,
      targetEmail: ticket.ticketNumber,
      organizationId: ticket.organizationId ?? actor.organizationId,
      reason: visibility == SupportMessageVisibility.internal
          ? 'Internal note'
          : 'Agent reply',
    );
  }

  // ---------------------------------------------------------------------------
  // KB / FAQ / Announcements
  // ---------------------------------------------------------------------------

  Future<List<SupportKbArticle>> fetchKbArticles() async {
    try {
      final snap =
          await _kb.orderBy('updatedAt', descending: true).limit(100).get();
      return snap.docs
          .map((d) => SupportKbArticle.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveKbArticle({
    required AdminUser actor,
    required SupportKbArticle article,
  }) async {
    final creating = article.id.isEmpty;
    final ref = creating ? _kb.doc() : _kb.doc(article.id);
    await ref.set(article.toMap(creating: creating), SetOptions(merge: true));
    await _writeAudit(
      action: 'support.kb_updated',
      actor: actor,
      targetUid: ref.id,
      targetEmail: article.title,
      reason: article.status.label,
    );
  }

  Future<List<SupportFaqItem>> fetchFaqs() async {
    try {
      final snap =
          await _faqs.orderBy('updatedAt', descending: true).limit(100).get();
      return snap.docs
          .map((d) => SupportFaqItem.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveFaq({
    required AdminUser actor,
    required SupportFaqItem item,
  }) async {
    final creating = item.id.isEmpty;
    final ref = creating ? _faqs.doc() : _faqs.doc(item.id);
    await ref.set(item.toMap(creating: creating), SetOptions(merge: true));
    await _writeAudit(
      action: 'support.faq_updated',
      actor: actor,
      targetUid: ref.id,
      targetEmail: item.question,
      reason: item.status.label,
    );
  }

  Future<List<SupportAnnouncement>> fetchAnnouncements() async {
    try {
      final snap = await _announcements
          .orderBy('updatedAt', descending: true)
          .limit(100)
          .get();
      return snap.docs
          .map((d) => SupportAnnouncement.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveAnnouncement({
    required AdminUser actor,
    required SupportAnnouncement item,
  }) async {
    final creating = item.id.isEmpty;
    final ref = creating ? _announcements.doc() : _announcements.doc(item.id);
    await ref.set(item.toMap(creating: creating), SetOptions(merge: true));
    await _writeAudit(
      action: 'support.announcement_updated',
      actor: actor,
      targetUid: ref.id,
      targetEmail: item.title,
      reason: item.type.label,
    );
  }

  String buildCsvExport(List<ManagedSupportTicket> tickets) {
    final buf = StringBuffer(
      'ticketNumber,subject,kind,category,priority,status,'
      'createdByEmail,assignedToEmail,createdAt,updatedAt\n',
    );
    for (final t in tickets) {
      String esc(String s) => '"${s.replaceAll('"', '""')}"';
      buf.writeln(
        [
          esc(t.ticketNumber),
          esc(t.subject),
          t.kind.wireValue,
          t.category.wireValue,
          t.priority.wireValue,
          t.status.wireValue,
          esc(t.createdByEmail),
          esc(t.assignedToEmail ?? ''),
          t.createdAt?.toIso8601String() ?? '',
          t.updatedAt?.toIso8601String() ?? '',
        ].join(','),
      );
    }
    return buf.toString();
  }

  Future<void> _writeAudit({
    required String action,
    required AdminUser actor,
    String targetUid = '',
    String targetEmail = '',
    String? reason,
    String? organizationId,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final entry = AdminAuditLogEntry(
        id: '',
        action: action,
        actorUid: actor.uid,
        actorEmail: actor.email,
        targetUid: targetUid,
        targetEmail: targetEmail,
        timestamp: DateTime.now(),
        reason: reason,
        metadata: {
          ...metadata,
          'module': 'support',
          'entity': 'support_ticket',
          'role': actor.roleId,
          if (organizationId != null && organizationId.isNotEmpty)
            'organizationId': organizationId,
        },
      );
      await _audit.add(entry.toMap());
    } catch (_) {
      // Audit must never block support ops.
    }
  }
}
