import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_user.dart';
import '../../../models/role_definition.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/security_repository.dart';
import '../models/managed_security.dart';
import '../models/security_enums.dart';
import '../models/security_filters.dart';

final securityRepositoryProvider = Provider<SecurityRepository>((ref) {
  return SecurityRepository();
});

class SecurityHubState {
  const SecurityHubState({
    this.section = SocHubSection.dashboard,
    this.summary = const SecuritySummary(),
    this.roles = const [],
    this.sessions = const [],
    this.devices = const [],
    this.alerts = const [],
    this.threats = const [],
    this.blocks = const [],
    this.ipRules = const [],
    this.accessGrants = const [],
    this.backups = const [],
    this.restorePoints = const [],
    this.policies = const SecurityPolicies(),
    this.api = const ApiSecuritySnapshot(),
    this.dr = const DisasterRecoveryPlan(),
    this.compliance = const ComplianceSnapshot(),
    this.filters = SecurityFilters.empty,
    this.isLoading = false,
    this.error,
    this.selectedRoleId,
  });

  final SocHubSection section;
  final SecuritySummary summary;
  final List<SocRoleView> roles;
  final List<ManagedSecuritySession> sessions;
  final List<ManagedSecurityDevice> devices;
  final List<ManagedSecurityAlert> alerts;
  final List<ManagedThreatRecommendation> threats;
  final List<ManagedBlockEntry> blocks;
  final List<ManagedIpRule> ipRules;
  final List<ManagedAccessGrant> accessGrants;
  final List<ManagedBackupRecord> backups;
  final List<ManagedRestorePoint> restorePoints;
  final SecurityPolicies policies;
  final ApiSecuritySnapshot api;
  final DisasterRecoveryPlan dr;
  final ComplianceSnapshot compliance;
  final SecurityFilters filters;
  final bool isLoading;
  final String? error;
  final String? selectedRoleId;

  SocRoleView? get selectedRole {
    if (selectedRoleId == null) return null;
    for (final r in roles) {
      if (r.id == selectedRoleId) return r;
    }
    return null;
  }

  SecurityHubState copyWith({
    SocHubSection? section,
    SecuritySummary? summary,
    List<SocRoleView>? roles,
    List<ManagedSecuritySession>? sessions,
    List<ManagedSecurityDevice>? devices,
    List<ManagedSecurityAlert>? alerts,
    List<ManagedThreatRecommendation>? threats,
    List<ManagedBlockEntry>? blocks,
    List<ManagedIpRule>? ipRules,
    List<ManagedAccessGrant>? accessGrants,
    List<ManagedBackupRecord>? backups,
    List<ManagedRestorePoint>? restorePoints,
    SecurityPolicies? policies,
    ApiSecuritySnapshot? api,
    DisasterRecoveryPlan? dr,
    ComplianceSnapshot? compliance,
    SecurityFilters? filters,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? selectedRoleId,
    bool clearSelectedRole = false,
  }) {
    return SecurityHubState(
      section: section ?? this.section,
      summary: summary ?? this.summary,
      roles: roles ?? this.roles,
      sessions: sessions ?? this.sessions,
      devices: devices ?? this.devices,
      alerts: alerts ?? this.alerts,
      threats: threats ?? this.threats,
      blocks: blocks ?? this.blocks,
      ipRules: ipRules ?? this.ipRules,
      accessGrants: accessGrants ?? this.accessGrants,
      backups: backups ?? this.backups,
      restorePoints: restorePoints ?? this.restorePoints,
      policies: policies ?? this.policies,
      api: api ?? this.api,
      dr: dr ?? this.dr,
      compliance: compliance ?? this.compliance,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedRoleId:
          clearSelectedRole ? null : (selectedRoleId ?? this.selectedRoleId),
    );
  }
}

class SecurityHubController extends StateNotifier<SecurityHubState> {
  SecurityHubController(this._ref) : super(const SecurityHubState()) {
    Future(() {
      if (mounted) ensureBootstrapped();
    });
  }

  final Ref _ref;
  bool _bootstrapped = false;

  SecurityRepository get _repo => _ref.read(securityRepositoryProvider);
  AdminAppType get _appType => _ref.read(adminAppTypeProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;
  bool get isSuperAdmin => _appType == AdminAppType.superAdmin;

  Future<void> ensureBootstrapped() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await refresh();
  }

  Future<void> refresh({bool force = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _load();
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setSection(SocHubSection section) async {
    if (!isSuperAdmin && section.isPlatformOnly) {
      state = state.copyWith(section: SocHubSection.dashboard);
      await refresh();
      return;
    }
    state = state.copyWith(section: section);
    await refresh();
  }

  Future<void> applyFilters(SecurityFilters filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  void setQuery(String query) {
    state = state.copyWith(filters: state.filters.copyWith(query: query));
  }

  void selectRole(String? id) {
    state = state.copyWith(
      selectedRoleId: id,
      clearSelectedRole: id == null,
    );
  }

  Future<void> _load() async {
    final actor = _actor;
    final summary = await _repo.fetchSummary(
      appType: _appType,
      actor: actor,
    );
    var section = state.section;
    if (!isSuperAdmin && section.isPlatformOnly) {
      section = SocHubSection.dashboard;
      state = state.copyWith(section: section);
    }

    switch (section) {
      case SocHubSection.roleManagement:
      case SocHubSection.permissionManagement:
        if (!isSuperAdmin) {
          state = state.copyWith(summary: summary, roles: const []);
          return;
        }
        final roles = await _repo.fetchRoles();
        state = state.copyWith(roles: roles, summary: summary);
        return;
      case SocHubSection.loginSessions:
        final sessions = await _repo.fetchSessionsFromAudit(
          appType: _appType,
          actor: actor,
        );
        state = state.copyWith(sessions: sessions, summary: summary);
        return;
      case SocHubSection.activeDevices:
        final devices = await _repo.fetchDevices(
          appType: _appType,
          actor: actor,
        );
        state = state.copyWith(devices: devices, summary: summary);
        return;
      case SocHubSection.securityAlerts:
        final alerts = await _repo.fetchAlerts(
          appType: _appType,
          actor: actor,
          filters: state.filters,
        );
        state = state.copyWith(alerts: alerts, summary: summary);
        return;
      case SocHubSection.threatDetection:
        state = state.copyWith(
          threats: _repo.threatRecommendations(),
          summary: summary,
        );
        return;
      case SocHubSection.blockLists:
        final blocks = await _repo.fetchBlocks(
          appType: _appType,
          actor: actor,
        );
        state = state.copyWith(blocks: blocks, summary: summary);
        return;
      case SocHubSection.ipManagement:
        final ips = await _repo.fetchIpRules();
        state = state.copyWith(ipRules: ips, summary: summary);
        return;
      case SocHubSection.accessControl:
        final grants = await _repo.fetchAccessGrants(
          appType: _appType,
          actor: actor,
        );
        state = state.copyWith(accessGrants: grants, summary: summary);
        return;
      case SocHubSection.backupCenter:
        final backups = await _repo.fetchBackups();
        state = state.copyWith(backups: backups, summary: summary);
        return;
      case SocHubSection.restoreCenter:
        final points = await _repo.fetchRestorePoints();
        state = state.copyWith(restorePoints: points, summary: summary);
        return;
      case SocHubSection.disasterRecovery:
        final backups = await _repo.fetchBackups();
        String? last;
        for (final b in backups) {
          if (b.status == SocBackupStatus.completed) {
            last = b.kind.label;
            break;
          }
        }
        state = state.copyWith(
          backups: backups,
          dr: _repo.disasterPlan(lastBackupLabel: last),
          summary: summary,
        );
        return;
      case SocHubSection.securityPolicies:
        final policies = await _repo.fetchPolicies();
        state = state.copyWith(policies: policies, summary: summary);
        return;
      case SocHubSection.apiSecurity:
        state = state.copyWith(
          api: _repo.apiSnapshot(failures: summary.failedLoginsToday),
          summary: summary,
        );
        return;
      case SocHubSection.compliance:
        state = state.copyWith(
          compliance: _repo.complianceSnapshot(),
          summary: summary,
        );
        return;
      case SocHubSection.dashboard:
        final alerts = await _repo.fetchAlerts(
          appType: _appType,
          actor: actor,
          limit: 20,
        );
        final sessions = await _repo.fetchSessionsFromAudit(
          appType: _appType,
          actor: actor,
          limit: 20,
        );
        state = state.copyWith(
          summary: summary,
          alerts: alerts,
          sessions: sessions,
          threats: _repo.threatRecommendations(),
        );
        return;
    }
  }

  Future<void> saveRole(RoleDefinition role) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) {
      state = state.copyWith(error: 'Only Super Admin can manage roles');
      return;
    }
    await _repo.saveRole(actor: actor, role: role);
    await refresh();
  }

  Future<void> createRole({
    required String id,
    required String label,
    String? description,
  }) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) {
      state = state.copyWith(error: 'Only Super Admin can create roles');
      return;
    }
    await _repo.createRole(
      actor: actor,
      id: id,
      label: label,
      description: description,
      panel: AdminAppType.organizationAdmin,
    );
    await refresh();
  }

  Future<void> duplicateRole(SocRoleView role, String newId) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    await _repo.duplicateRole(
      actor: actor,
      source: role.definition,
      newId: newId,
    );
    await refresh();
  }

  Future<void> renameRole(String roleId, String label) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    await _repo.renameRole(actor: actor, roleId: roleId, label: label);
    await refresh();
  }

  Future<void> archiveRole(SocRoleView role) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    await _repo.archiveRole(actor: actor, roleId: role.id);
    await refresh();
  }

  Future<void> deleteRole(SocRoleView role) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    await _repo.deleteRole(actor: actor, role: role.definition);
    await refresh();
  }

  Future<void> updatePermissions(
    SocRoleView role,
    Map<String, bool> permissions,
  ) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    await _repo.updateRolePermissions(
      actor: actor,
      role: role.definition,
      permissions: permissions,
    );
    await refresh();
  }

  Future<void> terminateSession(ManagedSecuritySession session) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.terminateSession(actor: actor, session: session);
    await refresh();
  }

  Future<void> terminateAllFor(ManagedSecuritySession session) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.terminateAllSessions(
      actor: actor,
      targetUid: session.uid,
      targetEmail: session.email,
    );
    await refresh();
  }

  Future<void> updateAlert(
    ManagedSecurityAlert alert,
    SocAlertStatus status,
  ) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.updateAlertStatus(
      actor: actor,
      alert: alert,
      status: status,
    );
    await refresh();
  }

  Future<void> addBlock(ManagedBlockEntry entry) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.addBlock(
      actor: actor,
      entry: ManagedBlockEntry(
        id: '',
        kind: entry.kind,
        value: entry.value,
        reason: entry.reason,
        duration: entry.duration,
        expiresAt: entry.expiresAt,
        organizationId: entry.organizationId ?? actor.organizationId,
      ),
    );
    await refresh();
  }

  Future<void> unblock(ManagedBlockEntry entry) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setBlockActive(actor: actor, entry: entry, active: false);
    await refresh();
  }

  Future<void> addIpRule(ManagedIpRule rule) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) {
      state = state.copyWith(error: 'Only Super Admin can manage IP rules');
      return;
    }
    await _repo.addIpRule(actor: actor, rule: rule);
    await refresh();
  }

  Future<void> saveAccessGrant(ManagedAccessGrant grant) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.saveAccessGrant(
      actor: actor,
      grant: ManagedAccessGrant(
        id: '',
        kind: grant.kind,
        subjectEmail: grant.subjectEmail,
        subjectUid: grant.subjectUid,
        module: grant.module,
        organizationId: grant.organizationId ?? actor.organizationId,
        expiresAt: grant.expiresAt,
        note: grant.note,
      ),
    );
    await refresh();
  }

  Future<void> scheduleBackup(SocBackupKind kind) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    await _repo.scheduleBackup(actor: actor, kind: kind);
    await refresh();
  }

  Future<void> savePolicies(SecurityPolicies policies) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) {
      state = state.copyWith(error: 'Only Super Admin can edit policies');
      return;
    }
    await _repo.savePolicies(actor: actor, policies: policies);
    await refresh();
  }
}

final securityHubControllerProvider = StateNotifierProvider.autoDispose<
    SecurityHubController, SecurityHubState>((ref) {
  return SecurityHubController(ref);
});
