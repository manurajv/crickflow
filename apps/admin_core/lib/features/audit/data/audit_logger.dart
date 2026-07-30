import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/admin_collections.dart';
import '../../../models/admin_user.dart';
import '../../users/models/admin_audit_log.dart';
import '../models/audit_enums.dart';

/// Centralized immutable audit writer for the admin ecosystem.
///
/// Existing module repositories may keep their private `_writeAudit` helpers;
/// new code (and Auth) should prefer this service so metadata stays consistent.
///
/// Never logs passwords, OAuth tokens, API keys, or other secrets.
class AuditLogger {
  AuditLogger({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  /// Writes an immutable audit entry. Returns the new document id.
  Future<String> log({
    required String action,
    required AdminUser actor,
    String targetUid = '',
    String targetEmail = '',
    String? reason,
    AuditModule? module,
    AuditSeverity? severity,
    AuditStatus? status,
    String? organizationId,
    String? description,
    Object? oldValue,
    Object? newValue,
    Map<String, dynamic> metadata = const {},
    String? sessionId,
  }) async {
    final resolvedModule = module ?? AuditModule.fromAction(action);
    final resolvedSeverity =
        severity ?? AuditSeverity.parse(_inferSeverity(action));
    final resolvedStatus = status ?? AuditStatus.parse(_inferStatus(action));
    final orgId = organizationId ?? actor.organizationId;

    final meta = <String, dynamic>{
      ...metadata,
      'entity': metadata['entity'] ?? resolvedModule.wireValue,
      'module': resolvedModule.wireValue,
      'severity': resolvedSeverity.wireValue,
      'status': resolvedStatus.wireValue,
      'role': actor.roleId,
      'actorRole': actor.roleId,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      if (orgId != null && orgId.isNotEmpty) 'organizationId': orgId,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (oldValue != null) 'oldValue': _safeValue(oldValue),
      if (newValue != null) 'newValue': _safeValue(newValue),
      'sessionId': sessionId ?? _sessionId,
    };

    for (final key in meta.keys.toList()) {
      final lower = key.toLowerCase();
      if (lower.contains('password') ||
          lower.contains('token') ||
          lower.contains('secret') ||
          lower.contains('apikey') ||
          lower.contains('api_key') ||
          lower.contains('refresh') ||
          lower.contains('credential')) {
        meta.remove(key);
      }
    }

    final entry = AdminAuditLogEntry(
      id: '',
      action: action,
      actorUid: actor.uid,
      actorEmail: actor.email,
      targetUid: targetUid,
      targetEmail: targetEmail,
      timestamp: DateTime.now(),
      reason: reason,
      metadata: meta,
    );

    final ref = await _audit.add(entry.toMap());
    return ref.id;
  }

  /// Best-effort login audit when [AdminUser] may not be loaded yet.
  Future<void> logAuthEvent({
    required String action,
    required String uid,
    required String email,
    String? roleId,
    String? organizationId,
    String? reason,
    AuditStatus status = AuditStatus.success,
    AuditSeverity severity = AuditSeverity.info,
    Map<String, dynamic> metadata = const {},
  }) async {
    final meta = <String, dynamic>{
      ...metadata,
      'entity': 'auth',
      'module': AuditModule.auth.wireValue,
      'severity': severity.wireValue,
      'status': status.wireValue,
      if (roleId != null) 'role': roleId,
      if (organizationId != null && organizationId.isNotEmpty)
        'organizationId': organizationId,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'sessionId': _sessionId,
    };

    final entry = AdminAuditLogEntry(
      id: '',
      action: action,
      actorUid: uid,
      actorEmail: email,
      targetUid: uid,
      targetEmail: email,
      timestamp: DateTime.now(),
      reason: reason,
      metadata: meta,
    );
    try {
      await _audit.add(entry.toMap());
    } catch (_) {
      // Never block auth flows on audit write failures.
    }
  }

  static String _inferSeverity(String action) {
    final a = action.toLowerCase();
    if (a.contains('banned') ||
        a.contains('blocked') ||
        a.contains('escalation') ||
        a.contains('suspicious')) {
      return AuditSeverity.critical.wireValue;
    }
    if (a.contains('failed') ||
        a.contains('suspended') ||
        a.contains('deleted')) {
      return AuditSeverity.high.wireValue;
    }
    if (a.contains('password') ||
        a.contains('role') ||
        a.contains('permission')) {
      return AuditSeverity.warning.wireValue;
    }
    return AuditSeverity.info.wireValue;
  }

  static String _inferStatus(String action) {
    final a = action.toLowerCase();
    if (a.contains('failed')) return AuditStatus.failed.wireValue;
    if (a.contains('blocked')) return AuditStatus.blocked.wireValue;
    return AuditStatus.success.wireValue;
  }

  static Object _safeValue(Object value) {
    final s = value.toString();
    if (s.length > 500) return '${s.substring(0, 500)}…';
    return value is num || value is bool ? value : s;
  }

  static final String _sessionId =
      'sess_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 32)}';

  static String get currentSessionId => _sessionId;
}
