import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/audit_logger.dart';
import '../data/audit_repository.dart';
import '../models/audit_enums.dart';
import '../models/audit_filters.dart';
import '../models/audit_log_view.dart';

export '../models/audit_enums.dart';

final auditLoggerProvider = Provider<AuditLogger>((ref) => AuditLogger());

final auditRepositoryProvider =
    Provider<AuditRepository>((ref) => AuditRepository());

class AuditHubState {
  const AuditHubState({
    this.section = AuditHubSection.dashboard,
    this.snapshot = const AuditHubSnapshot(),
    this.logs = const [],
    this.filters = AuditListFilters.empty,
    this.hasMore = false,
    this.cursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedId,
    this.bootstrapped = false,
  });

  final AuditHubSection section;
  final AuditHubSnapshot snapshot;
  final List<AuditLogView> logs;
  final AuditListFilters filters;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? selectedId;
  final bool bootstrapped;

  AuditHubState copyWith({
    AuditHubSection? section,
    AuditHubSnapshot? snapshot,
    List<AuditLogView>? logs,
    AuditListFilters? filters,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
    bool clearCursor = false,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    String? selectedId,
    bool clearSelection = false,
    bool? bootstrapped,
  }) {
    return AuditHubState(
      section: section ?? this.section,
      snapshot: snapshot ?? this.snapshot,
      logs: logs ?? this.logs,
      filters: filters ?? this.filters,
      hasMore: hasMore ?? this.hasMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
      bootstrapped: bootstrapped ?? this.bootstrapped,
    );
  }
}

class AuditHubController extends StateNotifier<AuditHubState> {
  AuditHubController(this._ref) : super(const AuditHubState());

  final Ref _ref;

  AuditRepository get _repo => _ref.read(auditRepositoryProvider);

  String? get _orgScope {
    final appType = _ref.read(adminAppTypeProvider);
    if (appType == AdminAppType.superAdmin) return null;
    return _ref.read(adminSessionProvider).adminUser?.organizationId;
  }

  Future<void> ensureBootstrapped() async {
    if (state.bootstrapped) return;
    await refresh();
    if (mounted) state = state.copyWith(bootstrapped: true);
  }

  void setSection(AuditHubSection section) {
    state = state.copyWith(section: section, clearSelection: true);
  }

  void selectLog(String? id) {
    if (id == null) {
      state = state.copyWith(clearSelection: true);
    } else {
      state = state.copyWith(selectedId: id);
    }
  }

  void setQuery(String query) {
    state = state.copyWith(filters: state.filters.copyWith(query: query));
  }

  Future<void> applyFilters(AuditListFilters filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
      logs: const [],
    );
    try {
      final org = _orgScope;
      final snap = await _repo.fetchHubSnapshot(organizationId: org);
      final page = await _repo.fetchPage(
        filters: state.filters,
        organizationId: org,
        limit: 40,
      );
      if (!mounted) return;
      state = state.copyWith(
        snapshot: snap,
        logs: page.logs,
        hasMore: page.hasMore,
        cursor: page.cursor,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _repo.fetchPage(
        filters: state.filters,
        organizationId: _orgScope,
        startAfter: state.cursor,
        limit: 40,
      );
      if (!mounted) return;
      state = state.copyWith(
        logs: [...state.logs, ...page.logs],
        hasMore: page.hasMore,
        cursor: page.cursor,
        isLoadingMore: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  List<AuditLogView> logsForSection() {
    final all = state.logs;
    return switch (state.section) {
      AuditHubSection.loginHistory =>
        all.where((l) => l.isLoginEvent).toList(),
      AuditHubSection.securityEvents =>
        all.where((l) => l.isSecurityEvent).toList(),
      AuditHubSection.permissionChanges =>
        all.where((l) => l.isPermissionChange).toList(),
      AuditHubSection.dataChanges =>
        all.where((l) => l.isDataChange).toList(),
      AuditHubSection.systemEvents =>
        all.where((l) => l.isSystemEvent).toList(),
      _ => all,
    };
  }

  String exportCsv() {
    final logs = logsForSection();
    if (logs.isEmpty) return _repo.buildCsv(state.snapshot.recent);
    return _repo.buildCsv(logs);
  }

  String exportJson() {
    final logs = logsForSection();
    if (logs.isEmpty) return _repo.buildJsonExport(state.snapshot.recent);
    return _repo.buildJsonExport(logs);
  }
}

final auditHubControllerProvider =
    StateNotifierProvider.autoDispose<AuditHubController, AuditHubState>((ref) {
  return AuditHubController(ref);
});

final auditTimelineProvider =
    StreamProvider.autoDispose<List<AuditLogView>>((ref) {
  final appType = ref.watch(adminAppTypeProvider);
  final orgId = appType == AdminAppType.superAdmin
      ? null
      : ref.watch(adminSessionProvider).adminUser?.organizationId;
  return ref.watch(auditRepositoryProvider).watchTimeline(
        organizationId: orgId,
      );
});

final selectedAuditLogProvider = Provider.autoDispose<AuditLogView?>((ref) {
  final state = ref.watch(auditHubControllerProvider);
  final id = state.selectedId;
  if (id == null) return null;
  for (final l in state.logs) {
    if (l.id == id) return l;
  }
  for (final l in state.snapshot.recent) {
    if (l.id == id) return l;
  }
  return null;
});
