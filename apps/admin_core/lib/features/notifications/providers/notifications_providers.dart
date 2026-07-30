import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../../users/models/admin_audit_log.dart';
import '../data/notifications_repository.dart';
import '../models/managed_notification.dart';
import '../models/notification_enums.dart';
import '../models/notification_filters.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository();
});

class NotificationsHubState {
  const NotificationsHubState({
    this.section = NotificationHubSection.dashboard,
    this.campaigns = const [],
    this.announcements = const [],
    this.templates = const [],
    this.segments = const [],
    this.autoNotifications = const [],
    this.filters = NotificationListFilters.empty,
    this.sort = const NotificationSort(),
    this.summary = const NotificationSummaryStats(),
    this.pageSize = 25,
    this.hasMore = false,
    this.cursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedId,
    this.composerOpen = false,
  });

  final NotificationHubSection section;
  final List<ManagedNotificationCampaign> campaigns;
  final List<ManagedAnnouncement> announcements;
  final List<ManagedNotificationTemplate> templates;
  final List<ManagedNotificationSegment> segments;
  final List<ManagedAutoNotification> autoNotifications;
  final NotificationListFilters filters;
  final NotificationSort sort;
  final NotificationSummaryStats summary;
  final int pageSize;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? selectedId;
  final bool composerOpen;

  NotificationsHubState copyWith({
    NotificationHubSection? section,
    List<ManagedNotificationCampaign>? campaigns,
    List<ManagedAnnouncement>? announcements,
    List<ManagedNotificationTemplate>? templates,
    List<ManagedNotificationSegment>? segments,
    List<ManagedAutoNotification>? autoNotifications,
    NotificationListFilters? filters,
    NotificationSort? sort,
    NotificationSummaryStats? summary,
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
    return NotificationsHubState(
      section: section ?? this.section,
      campaigns: campaigns ?? this.campaigns,
      announcements: announcements ?? this.announcements,
      templates: templates ?? this.templates,
      segments: segments ?? this.segments,
      autoNotifications: autoNotifications ?? this.autoNotifications,
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

class NotificationsHubController extends StateNotifier<NotificationsHubState> {
  NotificationsHubController(this._ref)
      : super(const NotificationsHubState(isLoading: true)) {
    Future(() {
      if (mounted) refresh();
    });
  }

  final Ref _ref;
  NotificationsRepository get _repo =>
      _ref.read(notificationsRepositoryProvider);
  AdminAppType get _appType => _ref.read(adminAppTypeProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;

  Future<void> setSection(NotificationHubSection section) async {
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
        case NotificationHubSection.dashboard:
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
        case NotificationHubSection.notifications:
        case NotificationHubSection.history:
        case NotificationHubSection.deliveryReports:
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
        case NotificationHubSection.campaigns:
          final page = await _repo.fetchCampaignsPage(
            appType: _appType,
            actor: _actor,
            filters: state.filters,
            sort: state.sort,
            limit: state.pageSize,
            campaignsOnly: true,
          );
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            campaigns: page.items,
            hasMore: page.hasMore,
            cursor: page.cursor,
            isLoading: false,
          );
        case NotificationHubSection.scheduled:
          final page = await _repo.fetchCampaignsPage(
            appType: _appType,
            actor: _actor,
            filters: state.filters.copyWith(scheduledOnly: true),
            sort: state.sort,
            limit: state.pageSize,
            scheduledOnly: true,
          );
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            campaigns: page.items,
            hasMore: page.hasMore,
            cursor: page.cursor,
            isLoading: false,
          );
        case NotificationHubSection.announcements:
          final announcements = await _repo.fetchAnnouncements();
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            announcements: announcements,
            isLoading: false,
          );
        case NotificationHubSection.templates:
          final templates = await _repo.fetchTemplates(
            appType: _appType,
            actor: _actor,
          );
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            templates: templates,
            isLoading: false,
          );
        case NotificationHubSection.segments:
          final segments = await _repo.fetchSegments(
            appType: _appType,
            actor: _actor,
          );
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            segments: segments,
            isLoading: false,
          );
        case NotificationHubSection.autoNotifications:
          final auto = await _repo.fetchAutoNotifications();
          if (!mounted) return;
          state = state.copyWith(
            summary: summary,
            autoNotifications: auto,
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
    if (section != NotificationHubSection.notifications &&
        section != NotificationHubSection.campaigns &&
        section != NotificationHubSection.scheduled &&
        section != NotificationHubSection.history &&
        section != NotificationHubSection.deliveryReports) {
      return;
    }
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _repo.fetchCampaignsPage(
        appType: _appType,
        actor: _actor,
        filters: state.filters,
        sort: state.sort,
        startAfter: state.cursor,
        limit: state.pageSize,
        campaignsOnly: section == NotificationHubSection.campaigns,
        scheduledOnly: section == NotificationHubSection.scheduled,
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

  Future<void> setSort(NotificationSortField field) async {
    state = state.copyWith(sort: state.sort.toggle(field));
    await refresh();
  }

  Future<void> applyFilters(NotificationListFilters filters) async {
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

  Future<String?> saveDraft(ManagedNotificationCampaign draft,
      {String? reason}) async {
    final actor = _actor;
    if (actor == null) return null;
    final id = await _repo.createCampaign(
      draft: draft.copyWith(status: ManagedNotificationStatus.draft),
      actor: actor,
      reason: reason,
    );
    await refresh();
    return id;
  }

  Future<void> updateDraft(ManagedNotificationCampaign campaign,
      {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.updateCampaign(
      campaign: campaign,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> sendNow(ManagedNotificationCampaign campaign,
      {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    var c = campaign;
    if (c.id.isEmpty) {
      final id = await _repo.createCampaign(draft: c, actor: actor);
      c = c.copyWith(id: id);
    }
    await _repo.sendOrQueue(
      campaign: c,
      actor: actor,
      reason: reason,
    );
    state = state.copyWith(composerOpen: false);
    await refresh();
  }

  Future<void> schedule(
    ManagedNotificationCampaign campaign, {
    required DateTime at,
    ManagedRecurrence recurrence = ManagedRecurrence.none,
    String timezone = 'UTC',
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    var c = campaign;
    if (c.id.isEmpty) {
      final id = await _repo.createCampaign(draft: c, actor: actor);
      c = c.copyWith(id: id);
    }
    await _repo.scheduleCampaign(
      campaign: c,
      scheduledAt: at,
      actor: actor,
      recurrence: recurrence,
      timezone: timezone,
      reason: reason,
    );
    state = state.copyWith(composerOpen: false);
    await refresh();
  }

  Future<void> cancel(ManagedNotificationCampaign c, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.cancelSchedule(campaign: c, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> archive(ManagedNotificationCampaign c, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.archiveCampaign(campaign: c, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> duplicate(ManagedNotificationCampaign c,
      {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.duplicateCampaign(source: c, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> deleteDraft(ManagedNotificationCampaign c,
      {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.deleteDraft(campaign: c, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> saveAnnouncement(ManagedAnnouncement a,
      {required bool create, String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.upsertAnnouncement(
      announcement: a,
      actor: actor,
      create: create,
      reason: reason,
    );
    await refresh();
  }

  Future<void> deleteAnnouncement(ManagedAnnouncement a,
      {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.deleteAnnouncement(
      announcement: a,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> saveTemplate(ManagedNotificationTemplate t,
      {required bool create, String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.upsertTemplate(
      template: t,
      actor: actor,
      create: create,
      reason: reason,
    );
    await refresh();
  }

  Future<void> deleteTemplate(ManagedNotificationTemplate t,
      {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.deleteTemplate(template: t, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> saveSegment(ManagedNotificationSegment s,
      {required bool create, String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.upsertSegment(
      segment: s,
      actor: actor,
      create: create,
      reason: reason,
    );
    await refresh();
  }

  Future<void> deleteSegment(ManagedNotificationSegment s,
      {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.deleteSegment(segment: s, actor: actor, reason: reason);
    await refresh();
  }
}

final notificationsHubControllerProvider = StateNotifierProvider.autoDispose<
    NotificationsHubController, NotificationsHubState>((ref) {
  return NotificationsHubController(ref);
});

final selectedNotificationCampaignProvider =
    FutureProvider.autoDispose<ManagedNotificationCampaign?>((ref) async {
  final id = ref.watch(notificationsHubControllerProvider).selectedId;
  if (id == null) return null;
  return ref.watch(notificationsRepositoryProvider).fetchCampaign(id);
});

final notificationAuditProvider =
    FutureProvider.autoDispose<List<AdminAuditLogEntry>>((ref) async {
  final selected = await ref.watch(selectedNotificationCampaignProvider.future);
  return ref
      .watch(notificationsRepositoryProvider)
      .fetchAudit(targetId: selected?.id);
});
