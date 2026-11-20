import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../../models/admin_role.dart';

/// Lifecycle of an `admin_users/{uid}` profile as managed by Super Admin.
///
/// Enforcement is `isActive` (Firestore rules + session guard). [accessStatus]
/// records *why* access is off so the UI can tell suspended from revoked.
enum AdminAccessStatus {
  active,
  suspended,
  revoked;

  String get label => switch (this) {
    AdminAccessStatus.active => 'Active',
    AdminAccessStatus.suspended => 'Suspended',
    AdminAccessStatus.revoked => 'Revoked',
  };

  String get wireValue => name;

  bool get grantsAccess => this == AdminAccessStatus.active;

  /// Resolves the effective status from the stored fields.
  ///
  /// `isActive == false` without an explicit status is treated as suspended.
  static AdminAccessStatus resolve({String? raw, required bool isActive}) {
    if (!isActive) {
      return raw == AdminAccessStatus.revoked.name
          ? AdminAccessStatus.revoked
          : AdminAccessStatus.suspended;
    }
    return AdminAccessStatus.active;
  }
}

/// Super Admin view of an `admin_users/{uid}` document.
class AdminAccount extends Equatable {
  const AdminAccount({
    required this.uid,
    required this.email,
    required this.roleId,
    required this.status,
    this.displayName,
    this.photoUrl,
    this.organizationId,
    this.organizationName,
    this.permissionOverrides = const {},
    this.statusReason,
    this.createdAt,
    this.updatedAt,
    this.updatedBy,
  });

  final String uid;
  final String email;
  final String roleId;
  final AdminAccessStatus status;
  final String? displayName;
  final String? photoUrl;
  final String? organizationId;
  final String? organizationName;
  final Map<String, bool> permissionOverrides;
  final String? statusReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;

  bool get isActive => status.grantsAccess;

  AdminRole? get knownRole => AdminRole.tryParse(roleId);

  bool get isSuperAdmin => knownRole == AdminRole.superAdmin;

  bool get hasOrganization =>
      organizationId != null && organizationId!.trim().isNotEmpty;

  String get effectiveName {
    final name = displayName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    if (email.contains('@')) return email.split('@').first;
    return uid;
  }

  String get initials {
    final source = effectiveName;
    final parts = source
        .split(RegExp(r'[\s._-]+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((e) => e[0].toUpperCase()).join();
  }

  static DateTime? _date(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  factory AdminAccount.fromMap(String uid, Map<String, dynamic> map) {
    final roleId =
        (map['roleId'] as String?) ??
        (map['platformRole'] as String?) ??
        (map['role'] as String?) ??
        '';
    final overrides = <String, bool>{};
    final raw = map['permissionOverrides'];
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is bool) overrides[key.toString()] = value;
      });
    }
    final isActive = map['isActive'] as bool? ?? true;
    final org = (map['organizationId'] as String?)?.trim();
    return AdminAccount(
      uid: uid,
      email: (map['email'] as String?) ?? '',
      roleId: roleId,
      status: AdminAccessStatus.resolve(
        raw: map['accessStatus'] as String?,
        isActive: isActive,
      ),
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      organizationId: (org == null || org.isEmpty) ? null : org,
      organizationName: map['organizationName'] as String?,
      permissionOverrides: overrides,
      statusReason: map['statusReason'] as String?,
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    uid,
    email,
    roleId,
    status,
    displayName,
    organizationId,
    organizationName,
    permissionOverrides,
    updatedAt,
  ];
}

/// A person who can be granted admin access (resolved by email or UID).
class AdminCandidate extends Equatable {
  const AdminCandidate({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.existing,
    this.source = 'users',
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;

  /// Present when `admin_users/{uid}` already exists.
  final AdminAccount? existing;

  /// `admin_users`, `users` (mobile profile), or `uid` (typed UID only).
  final String source;

  @override
  List<Object?> get props => [uid, email, source, existing];
}

/// Pure guard rules for admin access changes (unit-testable, no Firebase).
abstract final class AdminAccessPolicy {
  /// Returns an error message when [actorUid] may not change [target], else
  /// null. [activeSuperAdminCount] counts *currently active* super admins.
  static String? checkChange({
    required String actorUid,
    required bool actorIsSuperAdmin,
    required AdminAccount target,
    required String nextRoleId,
    required AdminAccessStatus nextStatus,
    required int activeSuperAdminCount,
  }) {
    if (!actorIsSuperAdmin) {
      return 'Only a Super Admin can change administrator access.';
    }
    final changesRoleOrStatus =
        nextRoleId != target.roleId || nextStatus != target.status;
    if (target.uid == actorUid && changesRoleOrStatus) {
      return 'You cannot change your own role or status. '
          'Ask another Super Admin.';
    }
    final losesSuperAdmin =
        target.isSuperAdmin &&
        target.isActive &&
        (AdminRole.tryParse(nextRoleId) != AdminRole.superAdmin ||
            !nextStatus.grantsAccess);
    if (losesSuperAdmin && activeSuperAdminCount <= 1) {
      return 'At least one active Super Admin must remain.';
    }
    return null;
  }

  /// Validation for granting access to someone new.
  static String? checkGrant({
    required String actorUid,
    required bool actorIsSuperAdmin,
    required AdminCandidate candidate,
  }) {
    if (!actorIsSuperAdmin) {
      return 'Only a Super Admin can grant administrator access.';
    }
    if (candidate.uid == actorUid) {
      return 'You already have Super Admin access.';
    }
    return null;
  }
}
