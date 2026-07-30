import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../../users/models/admin_audit_log.dart';
import '../data/organizations_repository.dart';
import '../models/managed_organization.dart';
import '../models/organization_enums.dart';
import '../models/organization_filters.dart';

export '../models/organization_enums.dart';

final organizationsRepositoryProvider = Provider<OrganizationsRepository>((ref) {
  return OrganizationsRepository();
});

// ─── State ────────────────────────────────────────────────────────────────────

class OrganizationsListState {
  const OrganizationsListState({
    this.organizations = const [],
    this.filters = OrganizationListFilters.empty,
    this.sort = const OrganizationSort(),
    this.pageSize = 25,
    this.hasMore = false,
    this.cursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedId,
    this.composerOpen = false,
    this.editingId,
    this.summary = const OrganizationSummaryStats(),
    this.activeTab = OrgDetailTab.overview,
  });

  final List<ManagedOrganization> organizations;
  final OrganizationListFilters filters;
  final OrganizationSort sort;
  final int pageSize;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? selectedId;
  final bool composerOpen;
  final String? editingId;
  final OrganizationSummaryStats summary;
  final OrgDetailTab activeTab;

  OrganizationsListState copyWith({
    List<ManagedOrganization>? organizations,
    OrganizationListFilters? filters,
    OrganizationSort? sort,
    int? pageSize,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
    bool clearCursor = false,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    String? selectedId,
    bool clearSelection = false,
    bool? composerOpen,
    String? editingId,
    bool clearEditing = false,
    OrganizationSummaryStats? summary,
    OrgDetailTab? activeTab,
  }) {
    return OrganizationsListState(
      organizations: organizations ?? this.organizations,
      filters: filters ?? this.filters,
      sort: sort ?? this.sort,
      pageSize: pageSize ?? this.pageSize,
      hasMore: hasMore ?? this.hasMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
      composerOpen: composerOpen ?? this.composerOpen,
      editingId: clearEditing ? null : (editingId ?? this.editingId),
      summary: summary ?? this.summary,
      activeTab: activeTab ?? this.activeTab,
    );
  }
}

// ─── Controller ───────────────────────────────────────────────────────────────

class OrganizationsListController
    extends StateNotifier<OrganizationsListState> {
  OrganizationsListController(this._ref)
      : super(const OrganizationsListState(isLoading: true)) {
    Future(() {
      if (mounted) refresh();
    });
  }

  final Ref _ref;

  OrganizationsRepository get _repo =>
      _ref.read(organizationsRepositoryProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;

  // ─── List operations ────────────────────────────────────────────────────

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
      organizations: const [],
    );
    try {
      final summary = await _repo.fetchSummary();
      final page = await _repo.fetchPage(
        filters: state.filters,
        sort: state.sort,
        limit: state.pageSize,
      );
      if (!mounted) return;
      state = state.copyWith(
        organizations: page.organizations,
        hasMore: page.hasMore,
        cursor: page.cursor,
        isLoading: false,
        summary: summary,
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
        sort: state.sort,
        startAfter: state.cursor,
        limit: state.pageSize,
      );
      if (!mounted) return;
      state = state.copyWith(
        organizations: [...state.organizations, ...page.organizations],
        hasMore: page.hasMore,
        cursor: page.cursor,
        isLoadingMore: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  void setQuery(String query) {
    state = state.copyWith(filters: state.filters.copyWith(query: query));
  }

  Future<void> applyFilters(OrganizationListFilters filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  Future<void> setSort(OrganizationSortField field) async {
    state = state.copyWith(sort: state.sort.toggle(field));
    await refresh();
  }

  // ─── UI navigation ──────────────────────────────────────────────────────

  void selectOrganization(String? id) {
    if (id == null) {
      state = state.copyWith(
        clearSelection: true,
        composerOpen: false,
        activeTab: OrgDetailTab.overview,
      );
    } else {
      state = state.copyWith(
        selectedId: id,
        composerOpen: false,
        clearEditing: true,
        activeTab: OrgDetailTab.overview,
      );
    }
  }

  void setActiveTab(OrgDetailTab tab) {
    state = state.copyWith(activeTab: tab);
  }

  void openCreateComposer() {
    state = state.copyWith(
      composerOpen: true,
      clearEditing: true,
      clearSelection: true,
    );
  }

  void openEditComposer(String id) {
    state = state.copyWith(
      composerOpen: true,
      editingId: id,
      selectedId: id,
    );
  }

  void closeComposer() {
    state = state.copyWith(composerOpen: false, clearEditing: true);
  }

  // ─── CRUD ────────────────────────────────────────────────────────────────

  Future<void> create(ManagedOrganization draft) async {
    final actor = _actor;
    if (actor == null) return;
    final created = await _repo.create(draft: draft, actor: actor);
    await refresh();
    selectOrganization(created.id);
  }

  Future<void> update(
    ManagedOrganization target,
    ManagedOrganization draft,
  ) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.update(target: target, actor: actor, draft: draft);
    closeComposer();
    await refresh();
    selectOrganization(target.id);
  }

  Future<void> setStatus(
    ManagedOrganization org,
    ManagedOrganizationStatus status, {
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setStatus(
      target: org,
      status: status,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> archive(ManagedOrganization org, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.archive(target: org, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> unarchive(ManagedOrganization org, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.unarchive(target: org, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> softDelete(ManagedOrganization org, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.softDelete(target: org, actor: actor, reason: reason);
    selectOrganization(null);
    await refresh();
  }

  Future<void> restore(ManagedOrganization org, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.restore(target: org, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> setFeatured(
    ManagedOrganization org, {
    required bool featured,
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setFeatured(
      target: org,
      featured: featured,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  // ─── Admin management ────────────────────────────────────────────────────

  Future<void> linkOrgAdmin(
    ManagedOrganization org,
    String uidOrEmail, {
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.linkOrgAdmin(
      target: org,
      actor: actor,
      uidOrEmail: uidOrEmail,
      reason: reason,
    );
    await refresh();
  }

  Future<void> unlinkOrgAdmin(
    ManagedOrganization org, {
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.unlinkOrgAdmin(target: org, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> transferOwnership(
    ManagedOrganization org,
    String newOwnerUidOrEmail, {
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.transferOwnership(
      target: org,
      actor: actor,
      newOwnerUidOrEmail: newOwnerUidOrEmail,
      reason: reason,
    );
    await refresh();
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final organizationsListControllerProvider = StateNotifierProvider.autoDispose<
    OrganizationsListController, OrganizationsListState>((ref) {
  return OrganizationsListController(ref);
});

final selectedManagedOrganizationProvider =
    FutureProvider.autoDispose<ManagedOrganization?>((ref) async {
  final id = ref.watch(
    organizationsListControllerProvider.select((s) => s.selectedId),
  );
  if (id == null) return null;
  return ref.watch(organizationsRepositoryProvider).fetchById(id);
});

final organizationRelatedCountsProvider =
    FutureProvider.autoDispose.family<OrganizationRelatedCounts, String>(
        (ref, orgId) {
  return ref.watch(organizationsRepositoryProvider).fetchRelatedCounts(orgId);
});

final organizationAuditProvider =
    FutureProvider.autoDispose.family<List<AdminAuditLogEntry>, String>(
        (ref, orgId) {
  return ref
      .watch(organizationsRepositoryProvider)
      .fetchAuditForOrg(orgId, limit: 50);
});
