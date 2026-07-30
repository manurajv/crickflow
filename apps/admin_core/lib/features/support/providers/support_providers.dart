import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_permission.dart';
import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/support_repository.dart';
import '../models/managed_support.dart';
import '../models/support_enums.dart';
import '../models/support_filters.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository();
});

class SupportHubState {
  const SupportHubState({
    this.section = SupportHubSection.dashboard,
    this.tickets = const [],
    this.kbArticles = const [],
    this.faqs = const [],
    this.announcements = const [],
    this.messages = const [],
    this.summary = const SupportSummaryStats(),
    this.reports = const SupportReportSnapshot(),
    this.filters = SupportListFilters.empty,
    this.sort = const SupportSort(),
    this.pageSize = 25,
    this.hasMore = false,
    this.cursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedId,
    this.composerOpen = false,
  });

  final SupportHubSection section;
  final List<ManagedSupportTicket> tickets;
  final List<SupportKbArticle> kbArticles;
  final List<SupportFaqItem> faqs;
  final List<SupportAnnouncement> announcements;
  final List<SupportMessage> messages;
  final SupportSummaryStats summary;
  final SupportReportSnapshot reports;
  final SupportListFilters filters;
  final SupportSort sort;
  final int pageSize;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? selectedId;
  final bool composerOpen;

  ManagedSupportTicket? get selected {
    if (selectedId == null) return null;
    for (final t in tickets) {
      if (t.id == selectedId) return t;
    }
    return null;
  }

  SupportHubState copyWith({
    SupportHubSection? section,
    List<ManagedSupportTicket>? tickets,
    List<SupportKbArticle>? kbArticles,
    List<SupportFaqItem>? faqs,
    List<SupportAnnouncement>? announcements,
    List<SupportMessage>? messages,
    SupportSummaryStats? summary,
    SupportReportSnapshot? reports,
    SupportListFilters? filters,
    SupportSort? sort,
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
    return SupportHubState(
      section: section ?? this.section,
      tickets: tickets ?? this.tickets,
      kbArticles: kbArticles ?? this.kbArticles,
      faqs: faqs ?? this.faqs,
      announcements: announcements ?? this.announcements,
      messages: messages ?? this.messages,
      summary: summary ?? this.summary,
      reports: reports ?? this.reports,
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
    );
  }
}

class SupportHubController extends StateNotifier<SupportHubState> {
  SupportHubController(this._ref) : super(const SupportHubState()) {
    Future(() {
      if (mounted) ensureBootstrapped();
    });
  }

  final Ref _ref;
  bool _bootstrapped = false;

  SupportRepository get _repo => _ref.read(supportRepositoryProvider);
  AdminAppType get _appType => _ref.read(adminAppTypeProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;

  bool get _agentAssignedOnly {
    final actor = _actor;
    if (actor == null) return false;
    if (_appType == AdminAppType.superAdmin) return false;
    final perms = _ref.read(adminSessionProvider).permissions;
    if (perms.contains(AdminPermission.canAccessGlobalData)) return false;
    // Support agents without broader access only see assigned tickets.
    return actor.roleId == 'support';
  }

  Future<void> ensureBootstrapped() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await refresh();
  }

  Future<void> refresh({bool force = false}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
    );
    try {
      await _loadSection(reset: true);
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setSection(SupportHubSection section) async {
    state = state.copyWith(
      section: section,
      clearSelection: true,
      clearCursor: true,
      messages: const [],
      composerOpen: false,
    );
    await refresh();
  }

  Future<void> applyFilters(SupportListFilters filters) async {
    state = state.copyWith(filters: filters, clearCursor: true);
    await refresh();
  }

  void setQuery(String query) {
    state = state.copyWith(filters: state.filters.copyWith(query: query));
  }

  Future<void> setSort(SupportSortField field) async {
    state = state.copyWith(sort: state.sort.toggle(field), clearCursor: true);
    await refresh();
  }

  Future<void> selectTicket(ManagedSupportTicket? ticket) async {
    if (ticket == null) {
      state = state.copyWith(clearSelection: true, messages: const []);
      return;
    }
    state = state.copyWith(selectedId: ticket.id, isLoading: true);
    try {
      final messages = await _repo.fetchMessages(ticket.id);
      if (!mounted) return;
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      await _loadSection(reset: false);
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> _loadSection({required bool reset}) async {
    final section = state.section;
    final summary = await _repo.fetchSummary(
      appType: _appType,
      actor: _actor,
    );

    switch (section) {
      case SupportHubSection.knowledgeBase:
        final kb = await _repo.fetchKbArticles();
        state = state.copyWith(kbArticles: kb, summary: summary);
        return;
      case SupportHubSection.faq:
        final faqs = await _repo.fetchFaqs();
        state = state.copyWith(faqs: faqs, summary: summary);
        return;
      case SupportHubSection.announcements:
        final items = await _repo.fetchAnnouncements();
        state = state.copyWith(announcements: items, summary: summary);
        return;
      case SupportHubSection.csat:
      case SupportHubSection.dashboard:
        state = state.copyWith(summary: summary);
        // also load recent tickets for dashboard table
        break;
      case SupportHubSection.reports:
        final reports = await _repo.fetchReports(
          appType: _appType,
          actor: _actor,
        );
        state = state.copyWith(summary: summary, reports: reports);
        return;
      default:
        break;
    }

    final kinds = _kindsForSection(section);
    final filters = kinds.isEmpty
        ? state.filters
        : state.filters.copyWith(
            kinds: state.filters.kinds.isEmpty ? kinds : state.filters.kinds,
          );

    final page = await _repo.fetchTicketsPage(
      appType: _appType,
      actor: _actor,
      filters: filters,
      sort: state.sort,
      startAfter: reset ? null : state.cursor,
      limit: state.pageSize,
      agentAssignedOnly: _agentAssignedOnly,
    );

    state = state.copyWith(
      tickets: reset ? page.items : [...state.tickets, ...page.items],
      hasMore: page.hasMore,
      cursor: page.lastDoc,
      summary: summary,
      clearCursor: page.lastDoc == null,
    );
  }

  Set<SupportTicketKind> _kindsForSection(SupportHubSection section) {
    return switch (section) {
      SupportHubSection.bugReports => {SupportTicketKind.bug},
      SupportHubSection.featureRequests => {SupportTicketKind.feature},
      SupportHubSection.feedback => {SupportTicketKind.feedback},
      SupportHubSection.contactRequests => {SupportTicketKind.contact},
      _ => {},
    };
  }

  void openComposer([bool open = true]) {
    state = state.copyWith(composerOpen: open);
  }

  Future<ManagedSupportTicket?> createTicket({
    required String subject,
    required String description,
    SupportTicketKind kind = SupportTicketKind.support,
    SupportTicketCategory category = SupportTicketCategory.support,
    SupportTicketPriority priority = SupportTicketPriority.medium,
    String stepsToReproduce = '',
    String logs = '',
    int? rating,
  }) async {
    final actor = _actor;
    if (actor == null) return null;
    final ticket = await _repo.createTicket(
      actor: actor,
      subject: subject,
      description: description,
      kind: kind,
      category: category,
      priority: priority,
      stepsToReproduce: stepsToReproduce,
      logs: logs,
      rating: rating,
    );
    state = state.copyWith(composerOpen: false);
    await refresh();
    await selectTicket(ticket);
    return ticket;
  }

  Future<void> assignSelected({
    required String uid,
    required String email,
    required String name,
    bool transfer = false,
    bool escalate = false,
  }) async {
    final ticket = state.selected;
    final actor = _actor;
    if (ticket == null || actor == null) return;
    final id = ticket.id;
    await _repo.assignTicket(
      ticket: ticket,
      actor: actor,
      assigneeUid: uid,
      assigneeEmail: email,
      assigneeName: name,
      transfer: transfer,
      escalate: escalate,
    );
    await refresh();
    ManagedSupportTicket? updated;
    for (final t in state.tickets) {
      if (t.id == id) {
        updated = t;
        break;
      }
    }
    await selectTicket(updated ?? ticket);
  }

  Future<void> setSelectedStatus(
    SupportTicketStatus status, {
    String? reason,
  }) async {
    final ticket = state.selected;
    final actor = _actor;
    if (ticket == null || actor == null) return;
    await _repo.setStatus(
      ticket: ticket,
      actor: actor,
      status: status,
      reason: reason,
    );
    await refresh();
  }

  Future<void> setFeatureStatus(FeatureRequestStatus status) async {
    final ticket = state.selected;
    final actor = _actor;
    if (ticket == null || actor == null) return;
    await _repo.setFeatureStatus(
      ticket: ticket,
      actor: actor,
      status: status,
    );
    await refresh();
  }

  Future<void> postReply(
    String body, {
    bool internal = false,
  }) async {
    final ticket = state.selected;
    final actor = _actor;
    if (ticket == null || actor == null || body.trim().isEmpty) return;
    await _repo.postMessage(
      ticket: ticket,
      actor: actor,
      body: body,
      visibility: internal
          ? SupportMessageVisibility.internal
          : SupportMessageVisibility.public,
    );
    final messages = await _repo.fetchMessages(ticket.id);
    if (!mounted) return;
    state = state.copyWith(messages: messages);
    await refresh();
  }

  Future<void> saveKb(SupportKbArticle article) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.saveKbArticle(actor: actor, article: article);
    await refresh();
  }

  Future<void> saveFaq(SupportFaqItem item) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.saveFaq(actor: actor, item: item);
    await refresh();
  }

  Future<void> saveAnnouncement(SupportAnnouncement item) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.saveAnnouncement(actor: actor, item: item);
    await refresh();
  }

  String exportCsv() => _repo.buildCsvExport(state.tickets);
}

final supportHubControllerProvider =
    StateNotifierProvider.autoDispose<SupportHubController, SupportHubState>(
        (ref) {
  return SupportHubController(ref);
});

/// Live conversation stream for the selected ticket (only when needed).
final supportMessagesStreamProvider =
    StreamProvider.autoDispose.family<List<SupportMessage>, String>((ref, id) {
  return ref.watch(supportRepositoryProvider).watchMessages(id);
});
