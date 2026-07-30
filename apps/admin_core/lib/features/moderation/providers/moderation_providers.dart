import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../../users/models/admin_audit_log.dart';
import '../data/moderation_repository.dart';
import '../models/managed_moderation.dart';
import '../models/moderation_enums.dart';
import '../models/moderation_filters.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepository();
});

class ModerationHubState {
  const ModerationHubState({
    required this.surface,
    this.section = ModerationHubSection.overview,
    this.posts = const [],
    this.reports = const [],
    this.chats = const [],
    this.trending = const [],
    this.filters = ModerationListFilters.empty,
    this.sort = const ModerationSort(),
    this.summary = const ModerationSummaryStats(),
    this.pageSize = 25,
    this.hasMore = false,
    this.cursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedPostId,
    this.selectedSource,
  });

  final ModerationSurface surface;
  final ModerationHubSection section;
  final List<ManagedModerationPost> posts;
  final List<ManagedContentReport> reports;
  final List<ManagedChatThread> chats;
  final List<ManagedModerationPost> trending;
  final ModerationListFilters filters;
  final ModerationSort sort;
  final ModerationSummaryStats summary;
  final int pageSize;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? selectedPostId;
  final ModerationSource? selectedSource;

  ModerationHubState copyWith({
    ModerationHubSection? section,
    List<ManagedModerationPost>? posts,
    List<ManagedContentReport>? reports,
    List<ManagedChatThread>? chats,
    List<ManagedModerationPost>? trending,
    ModerationListFilters? filters,
    ModerationSort? sort,
    ModerationSummaryStats? summary,
    int? pageSize,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
    bool clearCursor = false,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    String? selectedPostId,
    bool clearSelection = false,
    ModerationSource? selectedSource,
  }) {
    return ModerationHubState(
      surface: surface,
      section: section ?? this.section,
      posts: posts ?? this.posts,
      reports: reports ?? this.reports,
      chats: chats ?? this.chats,
      trending: trending ?? this.trending,
      filters: filters ?? this.filters,
      sort: sort ?? this.sort,
      summary: summary ?? this.summary,
      pageSize: pageSize ?? this.pageSize,
      hasMore: hasMore ?? this.hasMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      selectedPostId:
          clearSelection ? null : (selectedPostId ?? this.selectedPostId),
      selectedSource:
          clearSelection ? null : (selectedSource ?? this.selectedSource),
    );
  }
}

class ModerationHubController extends StateNotifier<ModerationHubState> {
  ModerationHubController(this._ref, ModerationSurface surface)
      : super(
          ModerationHubState(
            surface: surface,
            section: surface.defaultSection,
            isLoading: true,
          ),
        ) {
    Future(() {
      if (mounted) refresh();
    });
  }

  final Ref _ref;
  ModerationRepository get _repo => _ref.read(moderationRepositoryProvider);
  AdminAppType get _appType => _ref.read(adminAppTypeProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;

  List<ManagedContentReport> _filterReports(List<ManagedContentReport> reports) {
    final source = state.surface.reportSourceFilter;
    if (source == null) return reports;
    return reports.where((r) => r.source == source).toList();
  }

  bool get _queueUsesDiscover => state.surface == ModerationSurface.discover;

  Future<void> setSection(ModerationHubSection section) async {
    if (!state.surface.sections.contains(section)) return;
    state = state.copyWith(
      section: section,
      clearSelection: true,
      clearCursor: true,
      posts: const [],
      reports: const [],
      chats: const [],
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
        case ModerationHubSection.overview:
          final trending = await _repo.fetchTrending();
          final reports = _filterReports(
            await _repo.fetchReports(usersOnly: false),
          );
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            trending: trending,
            reports: reports
                .where((r) => r.status == ManagedReportStatus.pending)
                .take(10)
                .toList(),
            isLoading: false,
          );
        case ModerationHubSection.community:
        case ModerationHubSection.tournamentPosts:
        case ModerationHubSection.media:
          final filters = state.section == ModerationHubSection.tournamentPosts
              ? state.filters.copyWith(tournamentOnly: true)
              : state.filters;
          final page = await _repo.fetchCommunityPage(
            appType: _appType,
            actor: _actor,
            filters: filters,
            sort: state.sort,
            limit: state.pageSize,
          );
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            posts: page.posts,
            hasMore: page.hasMore,
            cursor: page.cursor,
            isLoading: false,
          );
        case ModerationHubSection.queue:
          final queueFilters = state.filters.copyWith(
            statuses: {
              ManagedPostAdminStatus.pending,
              ManagedPostAdminStatus.reported,
              ManagedPostAdminStatus.hidden,
            },
            includeRemoved: true,
          );
          final page = _queueUsesDiscover
              ? await _repo.fetchDiscoverPage(
                  appType: _appType,
                  actor: _actor,
                  filters: queueFilters,
                  sort: state.sort,
                  limit: state.pageSize,
                )
              : await _repo.fetchCommunityPage(
                  appType: _appType,
                  actor: _actor,
                  filters: queueFilters,
                  sort: state.sort,
                  limit: state.pageSize,
                );
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            posts: page.posts,
            hasMore: page.hasMore,
            cursor: page.cursor,
            isLoading: false,
          );
        case ModerationHubSection.discover:
          final page = await _repo.fetchDiscoverPage(
            appType: _appType,
            actor: _actor,
            filters: state.filters,
            sort: state.sort,
            limit: state.pageSize,
          );
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            posts: page.posts,
            hasMore: page.hasMore,
            cursor: page.cursor,
            isLoading: false,
          );
        case ModerationHubSection.reports:
          final reports = _filterReports(
            await _repo.fetchReports(usersOnly: false),
          );
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            reports: reports,
            isLoading: false,
          );
        case ModerationHubSection.reportedUsers:
          final reports = await _repo.fetchReports(usersOnly: true);
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            reports: reports,
            isLoading: false,
          );
        case ModerationHubSection.chats:
          final chats = await _repo.fetchChatMetadata();
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            chats: chats,
            isLoading: false,
          );
        case ModerationHubSection.trending:
          final trending = await _repo.fetchTrending();
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            trending: trending,
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
    final section = state.section;
    final canPage = section == ModerationHubSection.community ||
        section == ModerationHubSection.discover ||
        section == ModerationHubSection.tournamentPosts ||
        section == ModerationHubSection.media ||
        section == ModerationHubSection.queue;
    if (!canPage) return;

    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final useDiscover = section == ModerationHubSection.discover ||
          (section == ModerationHubSection.queue && _queueUsesDiscover);
      final filters = section == ModerationHubSection.tournamentPosts
          ? state.filters.copyWith(tournamentOnly: true)
          : section == ModerationHubSection.queue
              ? state.filters.copyWith(
                  statuses: {
                    ManagedPostAdminStatus.pending,
                    ManagedPostAdminStatus.reported,
                    ManagedPostAdminStatus.hidden,
                  },
                  includeRemoved: true,
                )
              : state.filters;
      final page = useDiscover
          ? await _repo.fetchDiscoverPage(
              appType: _appType,
              actor: _actor,
              filters: filters,
              sort: state.sort,
              startAfter: state.cursor,
              limit: state.pageSize,
            )
          : await _repo.fetchCommunityPage(
              appType: _appType,
              actor: _actor,
              filters: filters,
              sort: state.sort,
              startAfter: state.cursor,
              limit: state.pageSize,
            );
      if (!mounted) return;
      state = state.copyWith(
        posts: [...state.posts, ...page.posts],
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

  Future<void> setSort(ModerationSortField field) async {
    state = state.copyWith(sort: state.sort.toggle(field));
    await refresh();
  }

  Future<void> applyFilters(ModerationListFilters filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  void selectPost(ManagedModerationPost? post) {
    if (post == null) {
      state = state.copyWith(clearSelection: true);
    } else {
      state = state.copyWith(
        selectedPostId: post.id,
        selectedSource: post.source,
      );
    }
  }

  Future<void> hideCommunity(ManagedModerationPost p, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setCommunityStatus(
      target: p,
      status: ManagedPostAdminStatus.hidden,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> removeCommunity(ManagedModerationPost p, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setCommunityStatus(
      target: p,
      status: ManagedPostAdminStatus.removed,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> restoreCommunity(ManagedModerationPost p, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setCommunityStatus(
      target: p,
      status: ManagedPostAdminStatus.published,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> featureCommunity(ManagedModerationPost p, bool featured,
      {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setCommunityFeatured(
      target: p,
      featured: featured,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> removeDiscover(ManagedModerationPost p, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setDiscoverStatus(
      target: p,
      status: 'removed',
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> restoreDiscover(ManagedModerationPost p, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setDiscoverStatus(
      target: p,
      status: 'active',
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> featureDiscover(ManagedModerationPost p, bool featured,
      {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setDiscoverFeatured(
      target: p,
      featured: featured,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> resolveReport(
    ManagedContentReport report,
    ManagedReportStatus status, {
    String? resolution,
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.resolveReport(
      report: report,
      status: status,
      actor: actor,
      resolution: resolution,
      reason: reason,
    );
    await refresh();
  }
}

final moderationHubControllerProvider = StateNotifierProvider.autoDispose
    .family<ModerationHubController, ModerationHubState, ModerationSurface>(
        (ref, surface) {
  return ModerationHubController(ref, surface);
});

final selectedModerationPostProvider = StreamProvider.autoDispose
    .family<ManagedModerationPost?, ModerationSurface>((ref, surface) {
  final state = ref.watch(moderationHubControllerProvider(surface));
  final id = state.selectedPostId;
  final source = state.selectedSource;
  if (id == null || source == null) return Stream.value(null);
  final repo = ref.watch(moderationRepositoryProvider);
  return source == ModerationSource.discover
      ? repo.watchDiscoverPost(id)
      : repo.watchCommunityPost(id);
});

final moderationAuditProvider = FutureProvider.autoDispose
    .family<List<AdminAuditLogEntry>, ModerationSurface>((ref, surface) async {
  final post = await ref.watch(selectedModerationPostProvider(surface).future);
  if (post == null) {
    return ref.watch(moderationRepositoryProvider).fetchAudit();
  }
  return ref.watch(moderationRepositoryProvider).fetchAudit(targetId: post.id);
});
