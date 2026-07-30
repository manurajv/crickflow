import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_empty_state.dart';
import '../../shell/providers/shell_providers.dart';
import '../models/managed_moderation.dart';
import '../models/moderation_enums.dart';
import '../providers/moderation_providers.dart';
import 'widgets/moderation_chats_table.dart';
import 'widgets/moderation_detail_panel.dart';
import 'widgets/moderation_discover_table.dart';
import 'widgets/moderation_filter_drawer.dart';
import 'widgets/moderation_posts_table.dart';
import 'widgets/moderation_reports_table.dart';
import 'widgets/moderation_summary_cards.dart';
import 'widgets/moderation_toolbar.dart';

class ModerationScreen extends ConsumerStatefulWidget {
  const ModerationScreen({
    super.key,
    required this.surface,
    this.permission,
    this.permissions,
  });

  final ModerationSurface surface;

  /// Single permission gate (Community / Discover routes).
  final AdminPermission? permission;

  /// Any-of gate (shared Moderation queue).
  final List<AdminPermission>? permissions;

  @override
  ConsumerState<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends ConsumerState<ModerationScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  ModerationSurface get _surface => widget.surface;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateBreadcrumb(_surface.defaultSection);
    });
  }

  void _updateBreadcrumb(ModerationHubSection section) {
    ref.read(breadcrumbProvider.notifier).state = [
      _surface.breadcrumbRoot,
      section.label,
    ];
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    ref.read(moderationHubControllerProvider(_surface).notifier).setQuery(value);
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(moderationHubControllerProvider(_surface).notifier).refresh();
    });
  }

  ManagedModerationPost? _postFromReport(ManagedContentReport report) {
    if (report.postId.isEmpty) return null;
    final state = ref.read(moderationHubControllerProvider(_surface));
    for (final p in [...state.posts, ...state.trending]) {
      if (p.id == report.postId) return p;
    }
    return ManagedModerationPost(
      id: report.postId,
      source: report.source == ModerationSource.discover
          ? ModerationSource.discover
          : ModerationSource.community,
      authorId: report.authorId ?? '',
      authorName: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(moderationHubControllerProvider(_surface));
    final controller =
        ref.read(moderationHubControllerProvider(_surface).notifier);
    final showPanel = state.selectedPostId != null;

    final body = Stack(
      children: [
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                showPanel ? 480 : 20,
                32,
              ),
              children: [
                Text(
                  _surface.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _surface.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ModerationSummaryCards(
                  summary: state.summary,
                  surface: _surface,
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final section in _surface.sections)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(section.label),
                            selected: state.section == section,
                            onSelected: (_) {
                              controller.setSection(section);
                              _updateBreadcrumb(section);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ModerationToolbar(
                  controller: _searchController,
                  onQueryChanged: _onQueryChanged,
                  onSearchSubmitted: controller.refresh,
                  filterActive: state.filters.hasActiveFilters,
                  refreshing: state.isLoading,
                  hintText: switch (_surface) {
                    ModerationSurface.community =>
                      'Search post ID, author, hashtags, tournament…',
                    ModerationSurface.discover =>
                      'Search opportunity, author, location, category…',
                    ModerationSurface.queue =>
                      'Search reports, users, chats…',
                  },
                  onFilter: () async {
                    final next = await showModerationFilterDrawer(
                      context: context,
                      initial: state.filters.copyWith(
                        query: _searchController.text,
                      ),
                      showSourceFilters: _surface == ModerationSurface.queue,
                    );
                    if (next != null) {
                      _searchController.text = next.query;
                      await controller.applyFilters(next);
                    }
                  },
                  onRefresh: controller.refresh,
                  onExport: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Export (CSV / Excel / PDF) coming soon',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(child: Text(state.error!)),
                            CfButton(
                              label: 'Retry',
                              onPressed: controller.refresh,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                _buildSectionContent(state, controller),
              ],
            ),
          ),
        ),
        if (showPanel)
          Align(
            alignment: Alignment.centerRight,
            child: ModerationDetailPanel(
              surface: _surface,
              onClose: () => controller.selectPost(null),
            ),
          ),
      ],
    );

    if (widget.permissions != null && widget.permissions!.isNotEmpty) {
      return PermissionGateAny(
        permissions: widget.permissions!,
        child: body,
      );
    }
    final single = widget.permission;
    if (single == null) {
      return const CfEmptyState(
        icon: Icons.lock_outline,
        title: 'Permission required',
        message: 'You do not have access to this section.',
      );
    }
    return PermissionGate(
      permission: single,
      child: body,
    );
  }

  Widget _buildSectionContent(
    ModerationHubState state,
    ModerationHubController controller,
  ) {
    switch (state.section) {
      case ModerationHubSection.overview:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pending reports',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            ModerationPendingReportsList(
              reports: state.reports,
              onResolve: (r, {reason}) => controller.resolveReport(
                r,
                ManagedReportStatus.resolved,
                reason: reason,
              ),
              onDismiss: (r, {reason}) => controller.resolveReport(
                r,
                ManagedReportStatus.dismissed,
                reason: reason,
              ),
              onOpenTarget: (r) {
                final post = _postFromReport(r);
                if (post != null) controller.selectPost(post);
              },
            ),
            const SizedBox(height: 16),
            ModerationTrendingList(
              posts: state.trending,
              selectedId: state.selectedPostId,
              title: 'Trending posts',
              onSelect: controller.selectPost,
            ),
          ],
        );
      case ModerationHubSection.discover:
        return ModerationDiscoverTable(
          posts: state.posts,
          sort: state.sort,
          isLoading: state.isLoading,
          hasMore: state.hasMore,
          isLoadingMore: state.isLoadingMore,
          selectedId: state.selectedPostId,
          onSort: controller.setSort,
          onSelect: controller.selectPost,
          onLoadMore: controller.loadMore,
          onRemove: (p, {reason}) =>
              controller.removeDiscover(p, reason: reason),
          onRestore: (p, {reason}) =>
              controller.restoreDiscover(p, reason: reason),
          onFeature: (p, featured, {reason}) =>
              controller.featureDiscover(p, featured, reason: reason),
        );
      case ModerationHubSection.reports:
        return ModerationReportsTable(
          reports: state.reports,
          isLoading: state.isLoading,
          emptyTitle: switch (_surface) {
            ModerationSurface.community => 'No community reports',
            ModerationSurface.discover => 'No discover reports',
            ModerationSurface.queue => 'No reported content',
          },
          emptyMessage: 'Reports that need review will appear here.',
          onResolve: (r, {reason}) => controller.resolveReport(
            r,
            ManagedReportStatus.resolved,
            reason: reason,
          ),
          onDismiss: (r, {reason}) => controller.resolveReport(
            r,
            ManagedReportStatus.dismissed,
            reason: reason,
          ),
          onOpenTarget: (r) {
            final post = _postFromReport(r);
            if (post != null) controller.selectPost(post);
          },
        );
      case ModerationHubSection.reportedUsers:
        return ModerationReportsTable(
          reports: state.reports,
          isLoading: state.isLoading,
          emptyTitle: 'No reported users',
          emptyMessage: 'User reports will appear here.',
          onResolve: (r, {reason}) => controller.resolveReport(
            r,
            ManagedReportStatus.resolved,
            reason: reason,
          ),
          onDismiss: (r, {reason}) => controller.resolveReport(
            r,
            ManagedReportStatus.dismissed,
            reason: reason,
          ),
        );
      case ModerationHubSection.chats:
        return ModerationChatsTable(
          chats: state.chats,
          isLoading: state.isLoading,
        );
      case ModerationHubSection.trending:
        return ModerationTrendingList(
          posts: state.trending,
          selectedId: state.selectedPostId,
          title: 'Trending posts',
          onSelect: controller.selectPost,
        );
      case ModerationHubSection.community:
      case ModerationHubSection.tournamentPosts:
      case ModerationHubSection.media:
      case ModerationHubSection.queue:
        final discoverQueue =
            state.section == ModerationHubSection.queue &&
                _surface == ModerationSurface.discover;
        if (discoverQueue) {
          return ModerationDiscoverTable(
            posts: state.posts,
            sort: state.sort,
            isLoading: state.isLoading,
            hasMore: state.hasMore,
            isLoadingMore: state.isLoadingMore,
            selectedId: state.selectedPostId,
            onSort: controller.setSort,
            onSelect: controller.selectPost,
            onLoadMore: controller.loadMore,
            onRemove: (p, {reason}) =>
                controller.removeDiscover(p, reason: reason),
            onRestore: (p, {reason}) =>
                controller.restoreDiscover(p, reason: reason),
            onFeature: (p, featured, {reason}) =>
                controller.featureDiscover(p, featured, reason: reason),
          );
        }
        return ModerationPostsTable(
          posts: state.posts,
          sort: state.sort,
          isLoading: state.isLoading,
          hasMore: state.hasMore,
          isLoadingMore: state.isLoadingMore,
          selectedId: state.selectedPostId,
          onSort: controller.setSort,
          onSelect: controller.selectPost,
          onLoadMore: controller.loadMore,
          onHide: (p, {reason}) => controller.hideCommunity(p, reason: reason),
          onRemove: (p, {reason}) =>
              controller.removeCommunity(p, reason: reason),
          onRestore: (p, {reason}) =>
              controller.restoreCommunity(p, reason: reason),
          onFeature: (p, featured, {reason}) =>
              controller.featureCommunity(p, featured, reason: reason),
          emptyTitle: switch (state.section) {
            ModerationHubSection.tournamentPosts => 'No tournament posts',
            ModerationHubSection.media => 'No media posts',
            ModerationHubSection.queue => 'Moderation queue empty',
            _ => 'No community posts found',
          },
          emptyMessage: switch (state.section) {
            ModerationHubSection.queue =>
              'No posts pending review right now.',
            ModerationHubSection.media =>
              'Try adjusting filters to find media posts.',
            _ => 'Try adjusting search or filters.',
          },
        );
    }
  }
}
