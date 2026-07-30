import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../../users/models/admin_audit_log.dart';
import '../data/ads_repository.dart';
import '../models/ads_enums.dart';
import '../models/ads_filters.dart';
import '../models/managed_ads.dart';

final adsRepositoryProvider = Provider<AdsRepository>((ref) {
  return AdsRepository();
});

class AdsHubState {
  const AdsHubState({
    this.section = AdsHubSection.dashboard,
    this.campaigns = const [],
    this.advertisers = const [],
    this.sponsored = const [],
    this.admobConfig,
    this.filters = AdsListFilters.empty,
    this.sort = const AdsSort(),
    this.summary = const AdsSummaryStats(),
    this.pageSize = 25,
    this.hasMore = false,
    this.cursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedId,
    this.composerOpen = false,
  });

  final AdsHubSection section;
  final List<ManagedAdCampaign> campaigns;
  final List<ManagedAdvertiser> advertisers;
  final List<ManagedSponsoredContent> sponsored;
  final ManagedAdmobConfig? admobConfig;
  final AdsListFilters filters;
  final AdsSort sort;
  final AdsSummaryStats summary;
  final int pageSize;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? selectedId;
  final bool composerOpen;

  AdsHubState copyWith({
    AdsHubSection? section,
    List<ManagedAdCampaign>? campaigns,
    List<ManagedAdvertiser>? advertisers,
    List<ManagedSponsoredContent>? sponsored,
    ManagedAdmobConfig? admobConfig,
    AdsListFilters? filters,
    AdsSort? sort,
    AdsSummaryStats? summary,
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
  }) {
    return AdsHubState(
      section: section ?? this.section,
      campaigns: campaigns ?? this.campaigns,
      advertisers: advertisers ?? this.advertisers,
      sponsored: sponsored ?? this.sponsored,
      admobConfig: admobConfig ?? this.admobConfig,
      filters: filters ?? this.filters,
      sort: sort ?? this.sort,
      summary: summary ?? this.summary,
      pageSize: pageSize ?? this.pageSize,
      hasMore: hasMore ?? this.hasMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
      composerOpen: composerOpen ?? this.composerOpen,
    );
  }
}

class AdsHubController extends StateNotifier<AdsHubState> {
  AdsHubController(this._ref) : super(const AdsHubState(isLoading: true));

  final Ref _ref;
  AdsRepository get _repo => _ref.read(adsRepositoryProvider);
  AdminAppType get _appType => _ref.read(adminAppTypeProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;
  bool _bootstrapped = false;

  /// Call once from the screen after the first frame (avoids Riverpod
  /// ConcurrentModificationError when refreshing during provider creation).
  Future<void> ensureBootstrapped() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await refresh();
  }

  Future<void> setSection(AdsHubSection section) async {
    state = state.copyWith(
      section: section,
      clearSelection: true,
      clearCursor: true,
      composerOpen: false,
      campaigns: const [],
    );
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
    );
    try {
      final summary = await _repo.fetchSummary(
        appType: _appType,
        actor: _actor,
      );
      switch (state.section) {
        case AdsHubSection.dashboard:
          final page = await _repo.fetchCampaignsPage(
            appType: _appType,
            actor: _actor,
            filters: state.filters,
            sort: state.sort,
            limit: 10,
          );
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            campaigns: page.items,
            isLoading: false,
          );
        case AdsHubSection.customAds:
        case AdsHubSection.campaigns:
        case AdsHubSection.history:
        case AdsHubSection.placements:
        case AdsHubSection.revenue:
          final page = await _repo.fetchCampaignsPage(
            appType: _appType,
            actor: _actor,
            filters: state.filters,
            sort: state.sort,
            limit: state.pageSize,
          );
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            campaigns: page.items,
            hasMore: page.hasMore,
            cursor: page.cursor,
            isLoading: false,
          );
        case AdsHubSection.approvalQueue:
          final page = await _repo.fetchCampaignsPage(
            appType: _appType,
            actor: _actor,
            filters: state.filters,
            sort: state.sort,
            limit: state.pageSize,
            pendingOnly: true,
          );
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            campaigns: page.items,
            hasMore: page.hasMore,
            cursor: page.cursor,
            isLoading: false,
          );
        case AdsHubSection.admobConfig:
          final config = await _repo.fetchAdmobConfig();
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            admobConfig: config,
            isLoading: false,
          );
        case AdsHubSection.advertisers:
          final advertisers = await _repo.fetchAdvertisers(
            appType: _appType,
            actor: _actor,
          );
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            advertisers: advertisers,
            isLoading: false,
          );
        case AdsHubSection.sponsored:
          final sponsored = await _repo.fetchSponsored();
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            sponsored: sponsored,
            isLoading: false,
          );
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _repo.fetchCampaignsPage(
        appType: _appType,
        actor: _actor,
        filters: state.filters,
        sort: state.sort,
        startAfter: state.cursor,
        limit: state.pageSize,
        pendingOnly: state.section == AdsHubSection.approvalQueue,
      );
      if (!mounted) return;
      state = state.copyWith(
        campaigns: [...state.campaigns, ...page.items],
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

  Future<void> setSort(AdsSortField field) async {
    state = state.copyWith(sort: state.sort.toggle(field));
    await refresh();
  }

  Future<void> applyFilters(AdsListFilters filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  void selectCampaign(String? id) {
    state = state.copyWith(
      selectedId: id,
      clearSelection: id == null,
      composerOpen: false,
    );
  }

  void openComposer({bool open = true}) {
    state = state.copyWith(composerOpen: open, clearSelection: open);
  }

  Future<String?> saveDraft(ManagedAdCampaign draft, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return null;
    final id = await _repo.createCampaign(
      draft: draft.copyWith(status: ManagedAdStatus.draft),
      actor: actor,
      reason: reason,
    );
    await refresh();
    return id;
  }

  Future<void> updateDraft(ManagedAdCampaign c, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.updateCampaign(campaign: c, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> submitForApproval(ManagedAdCampaign c, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    var campaign = c;
    if (campaign.id.isEmpty) {
      final id = await _repo.createCampaign(draft: campaign, actor: actor);
      campaign = campaign.copyWith(id: id);
    }
    await _repo.setStatus(
      campaign: campaign,
      status: ManagedAdStatus.pendingApproval,
      actor: actor,
      reason: reason,
    );
    state = state.copyWith(composerOpen: false);
    await refresh();
  }

  Future<void> setStatus(
    ManagedAdCampaign c,
    ManagedAdStatus status, {
    String? reason,
    String? rejectionReason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setStatus(
      campaign: c,
      status: status,
      actor: actor,
      reason: reason,
      rejectionReason: rejectionReason,
    );
    await refresh();
  }

  Future<void> duplicate(ManagedAdCampaign c, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.duplicateCampaign(source: c, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> delete(ManagedAdCampaign c, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.deleteCampaign(campaign: c, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> setFeatured(ManagedAdCampaign c, bool featured,
      {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setFeatured(
      campaign: c,
      featured: featured,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> saveAdmobConfig(ManagedAdmobConfig config,
      {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.saveAdmobConfig(config: config, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> saveAdvertiser(ManagedAdvertiser a,
      {required bool create, String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.upsertAdvertiser(
      advertiser: a,
      actor: actor,
      create: create,
      reason: reason,
    );
    await refresh();
  }

  Future<void> deleteAdvertiser(ManagedAdvertiser a, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.deleteAdvertiser(advertiser: a, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> saveSponsored(ManagedSponsoredContent s,
      {required bool create, String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.upsertSponsored(
      item: s,
      actor: actor,
      create: create,
      reason: reason,
    );
    await refresh();
  }

  Future<void> deleteSponsored(ManagedSponsoredContent s,
      {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.deleteSponsored(item: s, actor: actor, reason: reason);
    await refresh();
  }
}

final adsHubControllerProvider =
    StateNotifierProvider.autoDispose<AdsHubController, AdsHubState>((ref) {
  return AdsHubController(ref);
});

final selectedAdCampaignProvider =
    FutureProvider.autoDispose<ManagedAdCampaign?>((ref) async {
  final id = ref.watch(adsHubControllerProvider).selectedId;
  if (id == null) return null;
  return ref.watch(adsRepositoryProvider).fetchCampaign(id);
});

final adsAuditProvider =
    FutureProvider.autoDispose<List<AdminAuditLogEntry>>((ref) async {
  final selected = await ref.watch(selectedAdCampaignProvider.future);
  return ref.watch(adsRepositoryProvider).fetchAudit(targetId: selected?.id);
});
