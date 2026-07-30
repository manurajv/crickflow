import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/admin_collections.dart';
import '../../../core/constants/admin_query_limits.dart';
import '../models/audit_enums.dart';
import '../models/audit_filters.dart';
import '../models/audit_log_view.dart';

/// Read / query / export for the Audit Center.
///
/// Writes go through [AuditLogger] or existing module `_writeAudit` helpers.
/// Logs are immutable — this repository never updates or deletes documents.
class AuditRepository {
  AuditRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  /// Realtime newest-first feed (capped). Prefer [fetchTimeline] for hubs.
  Stream<List<AuditLogView>> watchTimeline({
    String? organizationId,
    int limit = AdminQueryLimits.auditTimelineMax,
  }) {
    Query<Map<String, dynamic>> q = _audit.orderBy(
      'timestamp',
      descending: true,
    );
    // Client-side org filter — metadata.organizationId may lack a composite index.
    return q.limit(organizationId == null ? limit : limit * 3).snapshots().map(
      (snap) {
        var logs = snap.docs
            .map((d) => AuditLogView.fromFirestore(id: d.id, map: d.data()))
            .toList();
        if (organizationId != null && organizationId.isNotEmpty) {
          logs = logs
              .where((l) => l.organizationId == organizationId)
              .take(limit)
              .toList();
        }
        return logs;
      },
    );
  }

  /// One-shot timeline (default for Audit Center — avoids permanent listener).
  Future<List<AuditLogView>> fetchTimeline({
    String? organizationId,
    int limit = AdminQueryLimits.auditTimelineMax,
  }) async {
    Query<Map<String, dynamic>> q = _audit.orderBy(
      'timestamp',
      descending: true,
    );
    final snap =
        await q.limit(organizationId == null ? limit : limit * 3).get();
    var logs = snap.docs
        .map((d) => AuditLogView.fromFirestore(id: d.id, map: d.data()))
        .toList();
    if (organizationId != null && organizationId.isNotEmpty) {
      logs = logs
          .where((l) => l.organizationId == organizationId)
          .take(limit)
          .toList();
    }
    return logs;
  }

  Future<AuditPageResult> fetchPage({
    required AuditListFilters filters,
    String? organizationId,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 40,
  }) async {
    Query<Map<String, dynamic>> query =
        _audit.orderBy('timestamp', descending: true);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      // Over-fetch when client filters are heavy.
      final fetchLimit = filters.hasActiveFilters || organizationId != null
          ? limit * 3
          : limit + 1;
      snap = await query.limit(fetchLimit).get();
    } on FirebaseException {
      snap = await _audit.limit(limit + 1).get();
    }

    var logs = snap.docs
        .map((d) => AuditLogView.fromFirestore(id: d.id, map: d.data()))
        .toList();
    logs = _applyClientFilters(logs, filters, organizationId);

    final hasMore = snap.docs.length > limit || logs.length > limit;
    final page = logs.take(limit).toList();
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    if (page.isNotEmpty && snap.docs.isNotEmpty) {
      final lastId = page.last.id;
      for (final d in snap.docs) {
        if (d.id == lastId) {
          cursor = d;
          break;
        }
      }
      cursor ??= snap.docs.last;
    }

    return AuditPageResult(
      logs: page,
      hasMore: hasMore && page.length >= limit,
      cursor: cursor,
    );
  }

  List<AuditLogView> _applyClientFilters(
    List<AuditLogView> list,
    AuditListFilters filters,
    String? organizationId,
  ) {
    Iterable<AuditLogView> items = list;

    if (organizationId != null && organizationId.isNotEmpty) {
      items = items.where((l) => l.organizationId == organizationId);
    }

    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((l) {
        return l.action.toLowerCase().contains(q) ||
            l.actorEmail.toLowerCase().contains(q) ||
            l.actorUid.toLowerCase().contains(q) ||
            l.targetUid.toLowerCase().contains(q) ||
            l.targetEmail.toLowerCase().contains(q) ||
            l.module.label.toLowerCase().contains(q) ||
            l.ipAddress.toLowerCase().contains(q) ||
            l.sessionId.toLowerCase().contains(q) ||
            l.id.toLowerCase().contains(q);
      });
    }

    if (filters.modules.isNotEmpty) {
      items = items.where((l) => filters.modules.contains(l.module));
    }
    if (filters.severities.isNotEmpty) {
      items = items.where((l) => filters.severities.contains(l.severity));
    }
    if (filters.statuses.isNotEmpty) {
      items = items.where((l) => filters.statuses.contains(l.status));
    }
    if (filters.action?.trim().isNotEmpty == true) {
      final a = filters.action!.trim().toLowerCase();
      items = items.where((l) => l.action.toLowerCase().contains(a));
    }
    if (filters.actorEmail?.trim().isNotEmpty == true) {
      final e = filters.actorEmail!.trim().toLowerCase();
      items = items.where((l) => l.actorEmail.toLowerCase().contains(e));
    }
    if (filters.actorUid?.trim().isNotEmpty == true) {
      final u = filters.actorUid!.trim();
      items = items.where((l) => l.actorUid == u);
    }
    if (filters.role?.trim().isNotEmpty == true) {
      final r = filters.role!.trim().toLowerCase();
      items = items.where((l) => l.role.toLowerCase().contains(r));
    }
    if (filters.organizationId?.trim().isNotEmpty == true) {
      items = items.where(
        (l) => l.organizationId == filters.organizationId!.trim(),
      );
    }
    if (filters.country?.trim().isNotEmpty == true) {
      final c = filters.country!.trim().toLowerCase();
      items = items.where((l) => l.country.toLowerCase().contains(c));
    }
    if (filters.stateProvince?.trim().isNotEmpty == true) {
      final s = filters.stateProvince!.trim().toLowerCase();
      items = items.where((l) => l.stateProvince.toLowerCase().contains(s));
    }
    if (filters.city?.trim().isNotEmpty == true) {
      final c = filters.city!.trim().toLowerCase();
      items = items.where((l) => l.city.toLowerCase().contains(c));
    }
    if (filters.platform?.trim().isNotEmpty == true) {
      final p = filters.platform!.trim().toLowerCase();
      items = items.where((l) => l.platform.toLowerCase().contains(p));
    }
    if (filters.device?.trim().isNotEmpty == true) {
      final d = filters.device!.trim().toLowerCase();
      items = items.where((l) => l.device.toLowerCase().contains(d));
    }
    if (filters.browser?.trim().isNotEmpty == true) {
      final b = filters.browser!.trim().toLowerCase();
      items = items.where((l) => l.browser.toLowerCase().contains(b));
    }
    if (filters.from != null) {
      items = items.where((l) => !l.timestamp.isBefore(filters.from!));
    }
    if (filters.to != null) {
      items = items.where((l) => !l.timestamp.isAfter(filters.to!));
    }

    return items.toList();
  }

  Future<AuditDashboardStats> fetchDashboardStats({
    String? organizationId,
  }) async {
    try {
      final snap = await _audit
          .orderBy('timestamp', descending: true)
          .limit(300)
          .get();
      var logs = snap.docs
          .map((d) => AuditLogView.fromFirestore(id: d.id, map: d.data()))
          .toList();
      if (organizationId != null && organizationId.isNotEmpty) {
        logs = logs.where((l) => l.organizationId == organizationId).toList();
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final today = logs.where((l) => !l.timestamp.isBefore(startOfDay));

      final activeAdmins = today.map((l) => l.actorUid).toSet().length;

      return AuditDashboardStats(
        actionsToday: today.length,
        failedActions:
            logs.where((l) => l.status == AuditStatus.failed).length,
        securityEvents: logs.where((l) => l.isSecurityEvent).length,
        loginsToday: today.where((l) => l.isLoginEvent).length,
        activeAdmins: activeAdmins,
        permissionChanges: logs.where((l) => l.isPermissionChange).length,
        suspiciousActivities: logs
            .where(
              (l) =>
                  l.severity == AuditSeverity.critical ||
                  l.action.contains('suspicious') ||
                  l.action.contains('unknown_device'),
            )
            .length,
        criticalEvents: logs
            .where((l) => l.severity == AuditSeverity.critical)
            .length,
      );
    } catch (_) {
      return const AuditDashboardStats();
    }
  }

  Future<AuditHubSnapshot> fetchHubSnapshot({String? organizationId}) async {
    final stats = await fetchDashboardStats(organizationId: organizationId);
    final page = await fetchPage(
      filters: AuditListFilters.empty,
      organizationId: organizationId,
      limit: 25,
    );
    return AuditHubSnapshot(stats: stats, recent: page.logs);
  }

  String buildCsv(List<AuditLogView> logs) {
    final buf = StringBuffer();
    buf.writeln(
      'timestamp,action,module,actor,target,role,severity,status,ip,platform,sessionId,reason',
    );
    for (final l in logs) {
      String esc(String? v) {
        final s = (v ?? '').replaceAll('"', '""');
        return '"$s"';
      }

      buf.writeln([
        esc(l.timestamp.toIso8601String()),
        esc(l.action),
        esc(l.module.label),
        esc(l.actorEmail),
        esc(l.targetLabel),
        esc(l.role),
        esc(l.severity.label),
        esc(l.status.label),
        esc(l.ipAddress),
        esc(l.platform),
        esc(l.sessionId),
        esc(l.reason),
      ].join(','));
    }
    return buf.toString();
  }

  String buildJsonExport(List<AuditLogView> logs) {
    final items = logs
        .map(
          (l) => {
            'id': l.id,
            'action': l.action,
            'module': l.module.wireValue,
            'actorUid': l.actorUid,
            'actorEmail': l.actorEmail,
            'targetUid': l.targetUid,
            'targetEmail': l.targetEmail,
            'timestamp': l.timestamp.toIso8601String(),
            'severity': l.severity.wireValue,
            'status': l.status.wireValue,
            'role': l.role,
            'organizationId': l.organizationId,
            'reason': l.reason,
            // Never include secret-bearing metadata keys.
            'oldValue': l.oldValue,
            'newValue': l.newValue,
          },
        )
        .toList();
    return items.toString();
  }
}
