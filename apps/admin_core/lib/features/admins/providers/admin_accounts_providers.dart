import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/role_definition.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/admin_accounts_repository.dart';
import '../models/admin_account.dart';

final adminAccountsRepositoryProvider = Provider<AdminAccountsRepository>(
  (ref) => AdminAccountsRepository(),
);

/// All `admin_users` profiles (Super Admin panel only).
final adminAccountsProvider = FutureProvider.autoDispose<List<AdminAccount>>((
  ref,
) async {
  final list = await ref.watch(adminAccountsRepositoryProvider).listAll();
  final sorted = [...list]
    ..sort((a, b) {
      final byStatus = a.status.index.compareTo(b.status.index);
      if (byStatus != 0) return byStatus;
      return a.effectiveName.toLowerCase().compareTo(
        b.effectiveName.toLowerCase(),
      );
    });
  return sorted;
});

/// Roles a Super Admin can assign (Firestore `admin_roles` + built-ins).
final adminRoleOptionsProvider =
    FutureProvider.autoDispose<List<RoleDefinition>>((ref) {
      return ref.watch(adminRoleServiceProvider).listAll();
    });

final adminAccessControllerProvider = Provider<AdminAccessController>(
  (ref) => AdminAccessController(ref),
);

/// Roles offered in Admins & Access: every non-archived role that can enter
/// the Super Admin panel. Roles without a panel (e.g. the retired `admin`
/// organization role) stay listed only when [currentRoleId] already uses one,
/// so a legacy record can still be moved to a platform role. Organization and
/// series administration lives in the mobile app.
List<RoleDefinition> assignableAdminRoles(
  List<RoleDefinition> roles, {
  String? currentRoleId,
}) {
  return [
    for (final r in roles)
      if ((!r.archived && r.allowedPanel == AdminAppType.superAdmin) ||
          r.id == currentRoleId)
        r,
  ];
}

/// Orchestrates guarded admin access changes and refreshes the list.
class AdminAccessController {
  AdminAccessController(this._ref);

  final Ref _ref;

  AdminAccountsRepository get _repo =>
      _ref.read(adminAccountsRepositoryProvider);

  AdminSession get _session => _ref.read(adminSessionProvider);

  bool get _actorIsSuperAdmin =>
      _session.isAuthorized &&
      _session.adminUser?.isSuperAdmin == true &&
      _ref.read(adminAppTypeProvider) == AdminAppType.superAdmin;

  Future<int> _activeSuperAdminCount() async {
    final list = await _repo.listAll();
    return list.where((a) => a.isSuperAdmin && a.isActive).length;
  }

  Future<AdminCandidate?> lookup(String uidOrEmail) =>
      _repo.resolveCandidate(uidOrEmail);

  /// Grants access to a new person, or updates an existing admin profile.
  Future<void> saveAccess({
    required AdminCandidate candidate,
    required RoleDefinition role,
    required Map<String, bool> permissionOverrides,
    String? displayName,
    String? reason,
  }) async {
    final actor = _session.adminUser;
    if (actor == null) throw StateError('Not signed in as an administrator.');
    final existing = candidate.existing;

    final error = existing == null
        ? AdminAccessPolicy.checkGrant(
            actorUid: actor.uid,
            actorIsSuperAdmin: _actorIsSuperAdmin,
            candidate: candidate,
          )
        : AdminAccessPolicy.checkChange(
            actorUid: actor.uid,
            actorIsSuperAdmin: _actorIsSuperAdmin,
            target: existing,
            nextRoleId: role.id,
            nextStatus: existing.status,
            activeSuperAdminCount: await _activeSuperAdminCount(),
          );
    if (error != null) throw StateError(error);

    await _repo.saveAccess(
      uid: candidate.uid,
      email: candidate.email,
      displayName: displayName ?? candidate.displayName,
      photoUrl: candidate.photoUrl,
      roleId: role.id,
      permissionOverrides: permissionOverrides,
      actor: actor,
      isNew: existing == null,
      reason: reason,
    );
    _ref.invalidate(adminAccountsProvider);
  }

  /// Suspend, revoke, or reactivate an existing admin.
  Future<void> setStatus(
    AdminAccount target,
    AdminAccessStatus status, {
    String? reason,
  }) async {
    final actor = _session.adminUser;
    if (actor == null) throw StateError('Not signed in as an administrator.');
    final error = AdminAccessPolicy.checkChange(
      actorUid: actor.uid,
      actorIsSuperAdmin: _actorIsSuperAdmin,
      target: target,
      nextRoleId: target.roleId,
      nextStatus: status,
      activeSuperAdminCount: await _activeSuperAdminCount(),
    );
    if (error != null) throw StateError(error);
    await _repo.setStatus(
      target: target,
      status: status,
      actor: actor,
      reason: reason,
    );
    _ref.invalidate(adminAccountsProvider);
  }
}
